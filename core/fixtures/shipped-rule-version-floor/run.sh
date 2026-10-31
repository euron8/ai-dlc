#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Exercise the `.claude/rules/` version floor -- the DETECTOR, not a copy-time gate.
#
# `.claude/rules/` did not exist before Claude Code 2.0.64. Below that floor an installed
# rule file is INERT while everything in the tree reports success: the audit scans it and
# passes, `.ai-dlc-version` says the tree is current, and Rule 23's Carrier names it. A
# check that cannot fire reading exactly like one that passed.
#
# THE FLOOR IS NOT ENFORCED AT COPY TIME, AND THE FIRST VERSION OF THIS FIXTURE TESTED THE
# WRONG THING. It asserted that `install.sh` SKIPS the copy below the floor. That gate was
# real and passed its own arms -- and it protected nothing, because `install.sh` is only
# the path a NEW consumer takes. Measured on a copy of the reference consumer: the real
# pull (`apply.sh`, 0.347.0 -> 0.349.0, shimmed 1.9.0) reported
# `RESOLVED pure-apply rules/ai-dlc-resident-discipline.md`, wrote the file and re-stamped
# the tree as current. A third path -- install current, then DOWNGRADE -- no copy-time gate
# can see at all.
#
# So both copy paths ship the file unconditionally and ONE hook detects the floor every
# session, whatever path the file arrived by. These arms test that hook, plus the property
# that makes it the only thing standing between a consumer and a silent inert carrier.
#
#   A  no rule file present            -> silent (nothing to be inert)
#   B  file + version below floor      -> LOUD, names the file and the floor
#   C  file + version at floor (2.0.64)-> silent  (boundary, inclusive)
#   D  file + one below (2.0.63)       -> LOUD    (boundary, exclusive)
#   E  version unresolvable            -> reports UNRESOLVED, never silence
#   F  install.sh ships the file with NO version gate, on any version
#   G  uninstall.sh removes ai-dlc-*.md by prefix and KEEPS a consumer's own rule
#   H  a full install -> uninstall round trip, in a fresh world and in one seeded with a
#      consumer-authored hook, schema, agent, rule and settings.json, leaves only what the
#      consumer wrote: no ai-dlc hook, schema, driver, rule, stamp or generated agent, no
#      ai-dlc registration in settings.json, and the consumer's own entries intact. A
#      committed mutant drops the hook loop and must fail H1 alone.
#   I  a shipping fixture carrying a SUBDIRECTORY installs whole (BL-892): install exits 0,
#      the nested executable lands executable OVER a stale 0644 copy, the nested data file
#      lands non-executable, and uninstall removes them. Driven in a copy of the distribution
#      whose only fixture is lib/ plus a seeded sub/, so arm I's verdict rests on that seed
#      alone and not on the shape of every other fixture the sandbox carries (BL-871 measured
#      that shape deciding the main install). A committed mutant restores the flat
#      `cp <fixture>/*` and must fail I.
#      `run.sh --nested-only` runs arm I alone; it is BL-892's receipt.
#
# WHY E IS NOT PARANOIA. An unresolvable version is the same epistemic state as one below
# the floor. A detector that treats "I could not tell" as "fine" is the defect it exists
# to report, one level up.
#
# WHY F ASSERTS AN ABSENCE OF A GATE. The gate was removed deliberately; without this arm
# a future edit could reintroduce it, and the tree would again be protected on one path
# and not the other -- which reads as protection and is not.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve the distribution root by walking UP for a marker from this fixture's OWN
# location, never by counting `..` hops -- a fixed hop count is what I33/I33b forbid.
ROOT="$DIR"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
INSTALL="$ROOT/scripts/install.sh"
UNINSTALL="$ROOT/scripts/uninstall.sh"
HOOK="$ROOT/core/hooks/ai-dlc-rules-floor.sh"
[ -f "$HOOK" ] || HOOK="$ROOT/.claude/hooks/ai-dlc-rules-floor.sh"
RULE="ai-dlc-resident-discipline.md"

for f in "$INSTALL" "$UNINSTALL" "$HOOK"; do
  [ -f "$f" ] || { echo "run.sh: missing $f" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "run.sh: jq required by install.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED scripts/install.sh"
echo "HERMETIC-CONSUMED scripts/uninstall.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-rules-floor.sh"

# Scrub ambient AI_DLC_* before invoking any hook. A consumer that tunes one of these in
# settings.json would otherwise fail this fixture against a hook behaving correctly, and
# its pre-push gate would then block every push. The fixture must test the CODE, not the
# environment it happens to run in.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# --- I: a shipping fixture's subdirectory installs whole (BL-892) ----------------------------
# nested_dist <dir> -- a copy of the distribution shape install.sh and uninstall.sh read, whose
# ONLY fixture is lib/ (shipping, and named in uninstall.sh's hand list) plus a seeded sub/ with
# one executable and one data file. Every other core subtree is copied whole; core/fixtures/ is
# not, so a shipping fixture whose shape aborts install.sh (BL-871) cannot fail arm I for a
# reason that is not the seeded subdirectory.
nested_dist() {
  local d="$1" s
  mkdir -p "$d/scripts" "$d/core/fixtures"
  cp "$INSTALL" "$UNINSTALL" "$d/scripts/"
  for s in "$ROOT/core/"*/; do
    s="${s%/}"; [ "${s##*/}" = fixtures ] && continue
    cp -R "$s" "$d/core/"
  done
  cp -R "$ROOT/templates" "$ROOT/patterns" "$d/"
  cp -R "$ROOT/core/fixtures/lib" "$d/core/fixtures/"
  mkdir -p "$d/core/fixtures/lib/sub"
  printf '#!/bin/sh\necho nested\n' > "$d/core/fixtures/lib/sub/exec.sh"; chmod 755 "$d/core/fixtures/lib/sub/exec.sh"
  printf 'data\n' > "$d/core/fixtures/lib/sub/data.txt"; chmod 644 "$d/core/fixtures/lib/sub/data.txt"
}
# ARM I ALSO HOLDS, beyond the header: only TRACKED files ship (an ignored and an untracked file
# beside the nested pair must not land), a fixture holding only a top-level dotfile installs with
# rc 0, and a distribution copy that is not its own git work tree makes install REFUSE before it
# writes anything. A second committed mutant restores the directory copy `cp -pR <fixture>/*`
# and must fail the not-landed and dotfile-only sub-arms and nothing else.
# nested_index <dir> -- make the copy a git work tree with everything above in its INDEX (no commit:
# ls-files reads the index, and a commit would need the operator's identity and signing config), then
# seed one IGNORED file (by .git/info/exclude, not a .gitignore, which would itself be a stray dotfile)
# and one UNTRACKED file beside the tracked nested pair. install.sh copies the index's list, so neither
# may land. The seed state is proven before it is used: a zero from the not-landed sub-arms is a
# finding only if the files were on disk and git classified them as seeded.
nested_index() {
  local d="$1" s="$1/core/fixtures/lib/sub"
  git -C "$d" init -q --template= . && git -C "$d" add -A \
    || { echo "run.sh: could not index the nested distribution copy" >&2; exit 2; }
  mkdir -p "$d/.git/info" && printf '__pycache__/\n' > "$d/.git/info/exclude" || exit 2
  mkdir -p "$s/__pycache__"; printf 'pyc\n' > "$s/__pycache__/x.pyc"; printf 'stray\n' > "$s/untracked.txt"
  [ "$(git -C "$d" ls-files -- core/fixtures/lib/sub | tr '\n' ' ')" = "core/fixtures/lib/sub/data.txt core/fixtures/lib/sub/exec.sh " ] \
    && [ "$(git -C "$d" ls-files --others --exclude-standard -- core/fixtures/lib/sub)" = "core/fixtures/lib/sub/untracked.txt" ] \
    && git -C "$d" check-ignore -q core/fixtures/lib/sub/__pycache__/x.pyc \
    && [ -f "$s/__pycache__/x.pyc" ] && [ -f "$s/untracked.txt" ] \
    || { echo "run.sh: the nested copy's seed state is not tracked pair + one untracked + one ignored -- I-stray cannot discriminate" >&2; exit 2; }
}
# nested_target <dir> -- an empty consumer holding a STALE 0644 copy of the nested executable.
# A fresh copy takes the source mode under any cp; only an overwrite separates a copy that
# preserves modes from one that does not, and the top-level `*.sh` chmod cannot reach sub/.
nested_target() {
  local t="$1"
  mkdir -p "$t/_bmad" "$t/tests/fixtures/lib/sub"; ( cd "$t" && git init -q . )
  printf 'stale\n' > "$t/tests/fixtures/lib/sub/exec.sh"; chmod 644 "$t/tests/fixtures/lib/sub/exec.sh"
  [ -x "$t/tests/fixtures/lib/sub/exec.sh" ] \
    && { echo "run.sh: the stale nested copy is executable before install -- I-exec-mode cannot discriminate" >&2; exit 2; }
  return 0
}
# nested_check <install script> <target> <log> -> prints the failed sub-arm ids, nothing when clean
nested_check() {
  local inst="$1" t="$2" log="$3" n="$2/tests/fixtures/lib/sub"
  bash "$inst" "$t" > "$log" 2>&1 || echo I-rc
  grep -q 'echo nested' "$n/exec.sh" 2>/dev/null || echo I-exec-content
  [ -x "$n/exec.sh" ] || echo I-exec-mode
  [ -f "$n/data.txt" ] || echo I-data
  [ -f "$n/data.txt" ] && [ -x "$n/data.txt" ] && echo I-data-mode
  [ -e "$n/__pycache__/x.pyc" ] && echo I-ignored-landed
  [ -e "$n/untracked.txt" ] && echo I-untracked-landed
  return 0
}
# dotonly_check <install script> <log> -> prints the failed sub-arm ids, nothing when clean. The world
# is a git-indexed distribution copy holding a second shipping fixture zz-dotonly/ whose ONLY tracked
# file is a top-level dotfile. A directory glob `<fixture>/*` matches nothing there and its cp exits 1,
# aborting the install under `set -e`. Top-level dotfiles stay out, as the old glob left them, so the
# fixture lands as its directory with the dotfile absent.
dotonly_check() {
  local inst="$1" log="$2" t; t="$(mktemp -d "$TMP/dotonly-tgt.XXXXXX")"; mkdir -p "$t/_bmad"; ( cd "$t" && git init -q . )
  bash "$inst" "$t" > "$log" 2>&1 || echo I-dotonly-rc
  [ -d "$t/tests/fixtures/zz-dotonly" ] || echo I-dotonly-dir
  [ -e "$t/tests/fixtures/zz-dotonly/.keep" ] && echo I-dotonly-dotfile-landed
  return 0
}
# nested_refusal <install script> <non-git dist> -> prints the failed sub-arm ids, nothing when clean.
# A distribution that is not its own git work tree has no index to copy from, so install.sh must
# REFUSE, before writing anything -- never fall back to a directory copy. rc alone would pass for any
# unrelated failure (no _bmad, no jq), so the refusal's own text and an untouched target are asserted.
nested_refusal() {
  local inst="$1" t log="$TMP/install-i-nogit.log"
  t="$(mktemp -d "$TMP/nested-nogit-tgt.XXXXXX")"; mkdir -p "$t/_bmad"; ( cd "$t" && git init -q . )
  if bash "$inst" "$t" > "$log" 2>&1; then echo I-nogit-rc; fi
  grep -q 'is not a git work tree of its own' "$log" || echo I-nogit-msg
  [ -e "$t/.claude" ] && echo I-nogit-wrote
  return 0
}
arm_i() {
  local d t r
  grep -Eq '^for fixture_dir in lib ' "$UNINSTALL" \
    || { echo "run.sh: uninstall.sh's fixture list no longer opens with lib -- I cannot assert removal" >&2; exit 2; }
  d="$TMP/nested-dist"; nested_dist "$d"
  [ -f "$d/core/fixtures/lib/.dist-only" ] && { echo "run.sh: lib/ carries .dist-only -- I has no shipping subject" >&2; exit 2; }
  nested_dist "$TMP/nested-nogit"
  r="$(nested_refusal "$TMP/nested-nogit/scripts/install.sh")"
  [ -n "$r" ] && { note "FAIL  I a distribution copy that is not a git work tree did not make install refuse: $(echo $r)"; rc=1; }
  nested_dist "$TMP/nested-dot"; mkdir -p "$TMP/nested-dot/core/fixtures/zz-dotonly"
  printf 'keep\n' > "$TMP/nested-dot/core/fixtures/zz-dotonly/.keep"
  git -C "$TMP/nested-dot" init -q --template= . && git -C "$TMP/nested-dot" add -A \
    && [ "$(git -C "$TMP/nested-dot" ls-files -- core/fixtures/zz-dotonly)" = "core/fixtures/zz-dotonly/.keep" ] \
    || { echo "run.sh: the dotfile-only world does not track exactly zz-dotonly/.keep -- I-dotonly cannot discriminate" >&2; exit 2; }
  r="$(dotonly_check "$TMP/nested-dot/scripts/install.sh" "$TMP/install-i-dot.log")"
  [ -n "$r" ] && { note "FAIL  I a shipping fixture holding only a dotfile did not install as its directory: $(echo $r) ($(grep -m1 'No such file' "$TMP/install-i-dot.log"))"; rc=1; }
  nested_index "$d"
  t="$(mktemp -d "$TMP/nested-tgt.XXXXXX")"; nested_target "$t"
  r="$(nested_check "$d/scripts/install.sh" "$t" "$TMP/install-i.log")"
  if [ -n "$r" ]; then
    note "FAIL  I a shipping fixture's subdirectory did not install whole: $(echo $r) ($(grep -m1 'is a directory' "$TMP/install-i.log"))"; rc=1
  else
    bash "$d/scripts/uninstall.sh" "$t" --force > "$TMP/uninstall-i.log" 2>&1
    if [ -e "$t/tests/fixtures/lib/sub/exec.sh" ] || [ -e "$t/tests/fixtures/lib/sub/data.txt" ]; then
      note "FAIL  I uninstall left a shipping fixture's nested files behind"; rc=1
    else
      note "ok    I a fixture subdirectory installs its tracked files only, modes kept over a stale copy, a non-git distribution is refused, and uninstall removes it"
    fi
  fi
}
if [ "${1:-}" = "--nested-only" ]; then
  arm_i
  [ "$rc" -eq 0 ] && note "PASS  shipped-rule-version-floor --nested-only"
  exit "$rc"
fi

# Run the hook against a throwaway project dir at a pinned version.
hook_out() { # hook_out <project-dir> <AI_AGENT value or empty>
  local d="$1" agent="${2:-}" empty; empty="$(mktemp -d "$TMP/nobin.XXXXXX")"
  # PATH is stripped to a dir with no `claude` so the AI_AGENT branch is what is under
  # test; otherwise the fallback would silently answer with THIS machine's real version
  # and every arm below would pass for the wrong reason.
  CLAUDE_PROJECT_DIR="$d" AI_AGENT="$agent" PATH="$empty:/usr/bin:/bin" \
    bash "$HOOK" </dev/null 2>&1
}

proj() { local d; d="$(mktemp -d "$TMP/p.XXXXXX")"; mkdir -p "$d/.claude/rules"; printf '%s' "$d"; }

# --- A: nothing shipped -> silent ------------------------------------------
d="$(proj)"
if [ -z "$(hook_out "$d" claude-code_1-9-0_agent)" ]; then
  note "ok    A no rule file -- silent"
else note "FAIL  A the hook spoke with no rule file present"; rc=1; fi

# --- B: below floor -> loud -------------------------------------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
out="$(hook_out "$d" claude-code_1-9-0_agent)"
if grep -q 'FLOOR NOT MET' <<<"$out" && grep -q "$RULE" <<<"$out"; then
  note "ok    B below floor -- loud, and names the file"
else note "FAIL  B below floor did not report: ${out:0:120}"; rc=1; fi
# The message is injected as JSON; malformed JSON is dropped by the harness and the
# warning never reaches anyone, which is indistinguishable from silence.
if ! python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$out" 2>/dev/null; then
  note "FAIL  B emitted invalid JSON; the harness would discard it and the warning would vanish"; rc=1
fi

# --- C/D: the boundary, both sides -----------------------------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
# KEYED ON THE FLOOR FINDING, NOT ON SILENCE. This hook stopped being silent when the floor is
# met: it also carries the fleet's provenance contract, which has to reach the lead on EVERY
# session and not only on the sessions where an unrelated check happens to fire. The property
# arm C owns is that a met floor produces NO FLOOR COMPLAINT, and that is what it now asserts.
# Asserting emptiness would make this arm fail on any future payload the hook legitimately
# carries, which is a check that errors on correct data.
out_c="$(hook_out "$d" claude-code_2-0-64_agent)"
if grep -q 'FLOOR NOT MET' <<<"$out_c" || grep -q 'FLOOR -- UNRESOLVED' <<<"$out_c"; then
  note "FAIL  C 2.0.64 IS the floor and must be accepted"; rc=1
else
  note "ok    C floor exactly (2.0.64) -- no floor complaint"
fi
# The control the emptiness test used to give for free: the hook must still be SAYING something,
# or "no complaint" would be satisfied by a hook that died. And it must still be valid JSON.
if [ -z "$out_c" ]; then
  note "FAIL  C the hook emitted NOTHING at the floor -- the provenance contract has no carrier, and a silent hook satisfies the no-complaint test above for the wrong reason"; rc=1
elif ! python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$out_c" 2>/dev/null; then
  note "FAIL  C emitted invalid JSON at the floor; the harness would discard the whole block"; rc=1
elif ! grep -q 'AI-DLC-HOOK-PROVENANCE' <<<"$out_c"; then
  note "FAIL  C the floor-met emission carries no provenance marker, so this hook is not carrying the contract it is sited to carry"; rc=1
fi
grep -q 'FLOOR NOT MET' <<<"$(hook_out "$d" claude-code_2-0-63_agent)" \
  && note "ok    D one below floor (2.0.63) -- loud" \
  || { note "FAIL  D 2.0.63 is below the floor and must be reported"; rc=1; }

# --- E: unresolvable version -> reports, never silent -----------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
grep -q 'UNRESOLVED' <<<"$(hook_out "$d" "")" \
  && note "ok    E version unresolvable -- reported, not assumed fine" \
  || { note "FAIL  E an unresolvable version was treated as meeting the floor"; rc=1; }

# --- F: install.sh ships the file, with no version gate ---------------------
t="$(mktemp -d "$TMP/tgt.XXXXXX")"; mkdir -p "$t/_bmad"; ( cd "$t" && git init -q . )
oldbin="$(mktemp -d "$TMP/old.XXXXXX")"
printf '#!/bin/sh\necho "1.9.0 (Claude Code)"\n' > "$oldbin/claude"; chmod +x "$oldbin/claude"
PATH="$oldbin:$PATH" bash "$INSTALL" "$t" > "$TMP/install.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "ok    F install ships the rule with no copy-time version gate"
else
  note "FAIL  F install SKIPPED the rule on an old version. A copy-time gate is back, and it"
  note "      protects install.sh only -- apply.sh has no such gate, so the tree is guarded"
  note "      on one path and not the other. The floor belongs in the hook."
  rc=1
fi

# --- G: uninstall by prefix, keeping the consumer's own ---------------------
printf '# a rule this consumer wrote\n' > "$t/.claude/rules/consumer-own.md"
printf 'y\n' | bash "$UNINSTALL" "$t" > "$TMP/uninstall.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "FAIL  G the shipped rule survived uninstall; it would keep loading into every session"
  note "      of a repo that no longer has AI/DLC installed"; rc=1
elif [ ! -f "$t/.claude/rules/consumer-own.md" ]; then
  note "FAIL  G uninstall deleted the consumer's OWN rule file; the ai-dlc- prefix is the boundary"; rc=1
else
  note "ok    G uninstall removed ai-dlc-* and kept the consumer's own rule"
fi

# --- H: a full install -> uninstall round trip leaves ONLY consumer-authored content ------
# The expected-gone set is DERIVED from core/, never listed here, so a hook, schema, rule or
# driver added to core later is covered the moment it ships. Each property is its own arm so
# the mutant below can fail exactly one of them.
EXP_HOOKS=0; for f in "$ROOT/core/hooks/"ai-dlc-*.sh; do [ -f "$f" ] && EXP_HOOKS=$((EXP_HOOKS+1)); done
[ "$EXP_HOOKS" -gt 0 ] || { echo "run.sh: core/hooks/ai-dlc-*.sh matched nothing -- H cannot assert" >&2; exit 2; }

# h_check <tree> <world: fresh|seeded> -> prints one line per failed arm id, nothing when clean
h_check() {
  local t="$1" world="$2" f n
  # H1 no ai-dlc hook file survives
  set -- "$t/.claude/hooks/"ai-dlc-*.sh; [ -f "$1" ] && echo H1
  # H2 settings.json registers no ai-dlc hook; in the seeded world the consumer's own survive
  if [ -f "$t/.claude/settings.json" ]; then
    grep -q 'hooks/ai-dlc-' "$t/.claude/settings.json" && echo H2
  fi
  if [ "$world" = seeded ]; then
    jq -e '(.hooks.SessionStart | map(.hooks[].command) | index("bash .claude/hooks/consumer-own.sh")) != null
           and .hooks.Notification[0].hooks[0].command == "echo consumer-notify"
           and .permissions.allow == ["Bash(ls:*)"] and .env.CONSUMER_VAR == "1"
           and .bashOutputMaxChars == 8000' "$t/.claude/settings.json" >/dev/null 2>&1 || echo H2c
    # H7 tuned AI/DLC configuration is consumer data: the role tuned BEFORE install (dev) and
    # the one tuned AFTER it (qa) both survive, and the closing listing names both.
    jq -e '.aiDlcRoles.dev == {"model":"opus","effort":"medium"}
           and .aiDlcRoles.qa == {"model":"opus","effort":"low"}' \
      "$t/.claude/settings.json" >/dev/null 2>&1 || echo H7
    # H8 untuned AI/DLC configuration goes: no role besides the two tuned ones, no aiDlcModels
    jq -e '(.aiDlcRoles // {} | keys) - ["dev","qa"] == [] and (has("aiDlcModels") | not)' \
      "$t/.claude/settings.json" >/dev/null 2>&1 || echo H8
  else
    # install created the file, so every key in it was install's
    [ -f "$t/.claude/settings.json" ] && echo H2f
  fi
  # H3 every unprefixed core file in a shared directory is gone, plus the version stamp. A file
  # whose bytes differ from core's is H9's subject and is SUPPOSED to survive, so H3 judges only
  # files still byte-identical to core -- the ones uninstall must remove.
  for f in "$ROOT/core/schemas/"*.json "$ROOT/core/session-driver/"*.sh "$ROOT/core/rules/"*.md; do
    [ -f "$f" ] || continue
    n="${f#"$ROOT"/core/}"
    [ -e "$t/.claude/$n" ] && cmp -s "$f" "$t/.claude/$n" && { echo H3; break; }
  done
  [ -e "$t/.claude/.ai-dlc-version" ] && echo H3
  # H4 no generated agent definition survives
  for f in "$t/.claude/agents/"*.md; do
    [ -f "$f" ] && grep -q 'AI/DLC GENERATED' "$f" && { echo H4; break; }
  done
  # H5 consumer-authored files in the shared directories survive (seeded world)
  if [ "$world" = seeded ]; then
    for n in hooks/consumer-own.sh schemas/consumer-own.json agents/mine.md rules/consumer-own.md; do
      [ -f "$t/.claude/$n" ] || { echo H5; break; }
    done
  fi
  # H6 the managed .gitignore block is cut (its markers are read from a schema H3 deletes)
  [ -f "$t/.gitignore" ] && grep -q 'AI/DLC' "$t/.gitignore" && echo H6
  # H9 a file sharing a core file's NAME but not its bytes (edited after install) survives, and
  # the closing listing names it. H3 still sees every byte-identical core file removed.
  if [ "$world" = seeded ]; then
    grep -qx '{"edited":"by the consumer"}' "$t/.claude/schemas/audit-anchors.json" 2>/dev/null || echo H9
  fi
  return 0
}

# Fresh world: G's tree, installed with no settings.json of its own.
h_fresh="$(h_check "$t" fresh)"
if [ -z "$h_fresh" ]; then note "ok    H fresh install -> uninstall left no AI/DLC file and no install-created settings.json"
else note "FAIL  H fresh-world arms failed: $(echo $h_fresh)"; rc=1; fi

# Seeded world: consumer-authored hook, schema, agent, rule and settings BEFORE install.
seed_consumer() {
  local d="$1"
  mkdir -p "$d/_bmad" "$d/.claude/hooks" "$d/.claude/schemas" "$d/.claude/agents" "$d/.claude/rules"
  ( cd "$d" && git init -q . )
  printf '#!/bin/sh\necho mine\n' > "$d/.claude/hooks/consumer-own.sh"
  printf '{"mine":true}\n' > "$d/.claude/schemas/consumer-own.json"
  printf -- '---\nname: mine\n---\nconsumer agent\n' > "$d/.claude/agents/mine.md"
  printf '# a rule this consumer wrote\n' > "$d/.claude/rules/consumer-own.md"
  # bashOutputMaxChars equals the template's value ON PURPOSE: a fix deleting every key that
  # matches the template would delete the consumer's own setting, and this seed catches it.
  # aiDlcRoles.dev is TUNED before install (the template pins dev to sonnet): consumer data.
  printf '%s\n' '{"permissions":{"allow":["Bash(ls:*)"]},"env":{"CONSUMER_VAR":"1"},"bashOutputMaxChars":8000,"aiDlcRoles":{"dev":{"model":"opus","effort":"medium"}},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"bash .claude/hooks/consumer-own.sh"}]}],"Notification":[{"hooks":[{"type":"command","command":"echo consumer-notify"}]}]}}' \
    > "$d/.claude/settings.json"
}
hs="$(mktemp -d "$TMP/seeded.XXXXXX")"; seed_consumer "$hs"
bash "$INSTALL" "$hs" > "$TMP/install-h.log" 2>&1 || { echo "run.sh: install into the seeded world failed" >&2; exit 2; }
n_inst=0; for f in "$hs/.claude/hooks/"ai-dlc-*.sh; do [ -f "$f" ] && n_inst=$((n_inst+1)); done
if [ "$n_inst" -ne "$EXP_HOOKS" ] || ! grep -q 'hooks/ai-dlc-' "$hs/.claude/settings.json"; then
  echo "run.sh: seeded install did not produce $EXP_HOOKS registered hooks (got $n_inst) -- H cannot discriminate" >&2; exit 2
fi
# H3, H4 and H6 assert ABSENCES, so each needs its subject PRESENT before uninstall runs, or an
# install that never wrote it would pass them vacuously.
[ -f "$hs/.claude/schemas/pipeline-state-paths.json" ] && [ -f "$hs/.claude/.ai-dlc-version" ] \
  || { echo "run.sh: seeded install wrote no schemas/version stamp -- H3 cannot discriminate" >&2; exit 2; }
grep -lq 'AI/DLC GENERATED' "$hs"/.claude/agents/*.md 2>/dev/null \
  || { echo "run.sh: seeded install rendered no generated agent -- H4 cannot discriminate" >&2; exit 2; }
grep -qxF -- "$(jq -r .block_begin "$ROOT/core/schemas/pipeline-state-paths.json")" "$hs/.gitignore" 2>/dev/null \
  || { echo "run.sh: seeded install wrote no managed .gitignore block -- H6 cannot discriminate" >&2; exit 2; }
# Tune qa AFTER install, the way an operator edits settings.json in place. No archive records
# it, so only "differs from what install wrote" can keep it.
jq '.aiDlcRoles.qa = {"model":"opus","effort":"low"}' "$hs/.claude/settings.json" > "$TMP/s.json" \
  && mv "$TMP/s.json" "$hs/.claude/settings.json"
# Edit a shipped schema AFTER install: same name as core's, different bytes. H9's subject, and
# a file no uninstall path reads (pipeline-state-paths.json is read for the .gitignore markers).
cmp -s "$ROOT/core/schemas/audit-anchors.json" "$hs/.claude/schemas/audit-anchors.json" \
  || { echo "run.sh: seeded install did not write core's audit-anchors.json -- H9 cannot discriminate" >&2; exit 2; }
printf '%s\n' '{"edited":"by the consumer"}' > "$hs/.claude/schemas/audit-anchors.json"
jq -e '.aiDlcRoles.dev.model == "opus" and .aiDlcRoles.pm.model == "sonnet" and has("aiDlcModels")' \
  "$hs/.claude/settings.json" >/dev/null 2>&1 \
  || { echo "run.sh: seeded install did not keep the tuned dev role beside untuned template roles -- H7/H8 cannot discriminate" >&2; exit 2; }
# Copies of the installed tree for the mutants and their control, before anything uninstalls it.
hc="$TMP/seeded-control"; hm="$TMP/seeded-mutant"; hm2="$TMP/seeded-mutant-roles"
cp -R "$hs" "$hc"; cp -R "$hs" "$hm"; cp -R "$hs" "$hm2"; cp -R "$hs" "$hc.pre"

bash "$UNINSTALL" "$hs" --force > "$TMP/uninstall-h.log" 2>&1
grep -q 'aiDlcRoles.dev' "$TMP/uninstall-h.log" && grep -q 'aiDlcRoles.qa' "$TMP/uninstall-h.log" \
  && grep -q 'Consumer-tuned AI/DLC configuration left in place' "$TMP/uninstall-h.log" \
  || { note "FAIL  H7 the closing listing does not name the tuned roles left in place"; rc=1; }
grep -q '\.claude/schemas/audit-anchors\.json' "$TMP/uninstall-h.log" \
  || { note "FAIL  H9 the closing listing does not name the edited schema left in place"; rc=1; }
h_seed="$(h_check "$hs" seeded)"
if [ -z "$h_seed" ]; then note "ok    H seeded install -> uninstall removed every AI/DLC file and registration, kept every consumer-authored one"
else note "FAIL  H seeded-world arms failed: $(echo $h_seed)"; rc=1; fi

# --- H mutant: drop the hook prefix loop; ONLY H1 may fail --------------------------------
# uninstall.sh resolves core/ and templates/ beside itself, so the mutant runs from a copy of
# the distribution shape it reads, and an UNMUTATED control from the same copy must pass
# clean first -- otherwise a partial copy scores as a kill.
MD="$TMP/mutdist"; mkdir -p "$MD/scripts" "$MD/core/scripts" "$MD/core/skills/ai-dlc-update/reconcile" "$MD/templates"
cp -R "$ROOT/core/rules" "$ROOT/core/schemas" "$ROOT/core/session-driver" "$MD/core/"
cp "$ROOT/core/scripts/render-agent-definitions.sh" "$MD/core/scripts/"
cp "$ROOT/core/skills/ai-dlc-update/reconcile/settings-merge.sh" "$MD/core/skills/ai-dlc-update/reconcile/"
cp "$ROOT/templates/settings.json.template" "$MD/templates/"
cp "$UNINSTALL" "$MD/scripts/uninstall.sh"
bash "$MD/scripts/uninstall.sh" "$hc" --force > "$TMP/uninstall-hc.log" 2>&1
h_ctl="$(h_check "$hc" seeded)"
if [ -n "$h_ctl" ] || ! grep -q 'Un-merged AI/DLC hooks' "$TMP/uninstall-hc.log"; then
  note "FAIL  H mutant control: the unmutated uninstall run from the copied tree failed ($(echo $h_ctl)) -- the mutant verdict below would mean nothing"; rc=1
else
  # The loop's APPEND is neutralised rather than the loop deleted: deleting it leaves an empty
  # `then ... fi`, a syntax error, and a script that never ran fails every arm at once.
  sed 's|^    FILES_TO_REMOVE+=(".claude/hooks/$(basename "$hook_file")")$|    :|' \
    "$UNINSTALL" > "$MD/scripts/uninstall-mut.sh"
  if cmp -s "$UNINSTALL" "$MD/scripts/uninstall-mut.sh"; then
    note "FAIL  H mutant DID NOT APPLY: the hook-loop anchor matched nothing"; rc=1
  else
    bash "$MD/scripts/uninstall-mut.sh" "$hm" --force > "$TMP/uninstall-hm.log" 2>&1
    h_mut="$(h_check "$hm" seeded | sort -u | tr '\n' ' ')"
    if ! grep -q 'Uninstall complete' "$TMP/uninstall-hm.log"; then
      note "FAIL  H mutant did not run to completion, so its verdict says nothing about the hook loop"; rc=1
    elif [ "$h_mut" = "H1 " ]; then note "ok    H mutant without the hook loop fails H1 and only H1"
    else note "FAIL  H mutant without the hook loop scored '$h_mut', expected exactly 'H1'"; rc=1; fi
  fi
  # Second mutant: aiDlcModels/aiDlcRoles removed UNCONDITIONALLY, tuned or not. ONLY H7 may fail.
  sed 's|^            reduce ("aiDlcModels", "aiDlcRoles") as \$ns (\.;$|            del(.aiDlcModels, .aiDlcRoles) \| reduce ("aiDlcModels", "aiDlcRoles") as $ns (.;|' \
    "$UNINSTALL" > "$MD/scripts/uninstall-mut2.sh"
  if cmp -s "$UNINSTALL" "$MD/scripts/uninstall-mut2.sh"; then
    note "FAIL  H mutant 2 DID NOT APPLY: the aiDlc* un-merge anchor matched nothing"; rc=1
  else
    bash "$MD/scripts/uninstall-mut2.sh" "$hm2" --force > "$TMP/uninstall-hm2.log" 2>&1
    h_mut2="$(h_check "$hm2" seeded | sort -u | tr '\n' ' ')"
    if ! grep -q 'Uninstall complete' "$TMP/uninstall-hm2.log"; then
      note "FAIL  H mutant 2 did not run to completion, so its verdict says nothing about the aiDlc* un-merge"; rc=1
    elif [ "$h_mut2" = "H7 " ]; then note "ok    H mutant removing aiDlcModels/aiDlcRoles unconditionally fails H7 and only H7"
    else note "FAIL  H mutant removing aiDlcModels/aiDlcRoles unconditionally scored '$h_mut2', expected exactly 'H7'"; rc=1; fi
  fi
  # Third mutant: remove by NAME alone, as the first cut of BL-002 did. ONLY H9 may fail.
  hm3="$TMP/seeded-mutant-name"; cp -R "$hc.pre" "$hm3" 2>/dev/null || true
  sed 's|^    if cmp -s "$core_file" "$PROJECT_ROOT/.claude/$sub/$name"; then$|    if true; then|' \
    "$UNINSTALL" > "$MD/scripts/uninstall-mut3.sh"
  if cmp -s "$UNINSTALL" "$MD/scripts/uninstall-mut3.sh"; then
    note "FAIL  H mutant 3 DID NOT APPLY: the byte-compare anchor matched nothing"; rc=1
  elif [ ! -d "$hm3" ]; then
    note "FAIL  H mutant 3 has no pre-uninstall copy of the seeded world"; rc=1
  else
    bash "$MD/scripts/uninstall-mut3.sh" "$hm3" --force > "$TMP/uninstall-hm3.log" 2>&1
    h_mut3="$(h_check "$hm3" seeded | sort -u | tr '\n' ' ')"
    if ! grep -q 'Uninstall complete' "$TMP/uninstall-hm3.log"; then
      note "FAIL  H mutant 3 did not run to completion, so its verdict says nothing about the byte compare"; rc=1
    elif [ "$h_mut3" = "H9 " ]; then note "ok    H mutant removing same-named files by name alone fails H9 and only H9"
    else note "FAIL  H mutant removing same-named files by name alone scored '$h_mut3', expected exactly 'H9'"; rc=1; fi
  fi
fi

# --- I, then its mutant: the flat `cp <fixture>/*` restored ---------------------------------
# Anchored on the two stable lines that BRACKET the copy (the per-fixture mkdir and the *.sh
# chmod), never on the copy line itself, so a second correct spelling of the copy still mutates.
arm_i
MI="$TMP/nested-dist/scripts/install-mut.sh"
awk '
  /^    mkdir -p "\$PROJECT_ROOT\/tests\/fixtures\/\$fixture_dir"$/ {
    print; print "    cp \"$SCRIPT_DIR/../core/fixtures/$fixture_dir/\"* \"$PROJECT_ROOT/tests/fixtures/$fixture_dir/\""; skip = 1; next }
  /^    chmod \+x "\$PROJECT_ROOT\/tests\/fixtures\/\$fixture_dir\/"\*\.sh / { skip = 0 }
  !skip { print }
' "$INSTALL" > "$MI"
if cmp -s "$INSTALL" "$MI" || ! grep -q '^    chmod +x "$PROJECT_ROOT/tests/fixtures/$fixture_dir/"\*\.sh ' "$MI"; then
  note "FAIL  I mutant DID NOT APPLY: the mkdir/chmod brackets around the fixture copy matched nothing"; rc=1
else
  tmi="$(mktemp -d "$TMP/nested-mut.XXXXXX")"; nested_target "$tmi"
  r_mut="$(nested_check "$MI" "$tmi" "$TMP/install-imut.log")"
  if [ -z "$r_mut" ]; then note "FAIL  I mutant restoring the flat cp <fixture>/* SURVIVED -- arm I cannot see a non-recursive copy"; rc=1
  else note "ok    I mutant restoring the flat cp <fixture>/* fails I ($(echo $r_mut))"; fi
fi
# Mutant 2: the U8 directory copy `cp -pR <fixture>/*` restored between the same brackets. It
# installs the nested pair whole, so it must fail the not-landed sub-arms and ONLY those.
MI2="$TMP/nested-dist/scripts/install-mut2.sh"
awk '
  /^    mkdir -p "\$PROJECT_ROOT\/tests\/fixtures\/\$fixture_dir"$/ {
    print; print "    cp -pR \"$SCRIPT_DIR/../core/fixtures/$fixture_dir/\"* \"$PROJECT_ROOT/tests/fixtures/$fixture_dir/\""; skip = 1; next }
  /^    chmod \+x "\$PROJECT_ROOT\/tests\/fixtures\/\$fixture_dir\/"\*\.sh / { skip = 0 }
  !skip { print }
' "$INSTALL" > "$MI2"
if cmp -s "$INSTALL" "$MI2" || ! grep -q '^    cp -pR "$SCRIPT_DIR' "$MI2"; then
  note "FAIL  I mutant 2 DID NOT APPLY: the mkdir/chmod brackets around the fixture copy matched nothing"; rc=1
else
  tmi2="$(mktemp -d "$TMP/nested-mut2.XXXXXX")"; nested_target "$tmi2"
  r_mut2="$(nested_check "$MI2" "$tmi2" "$TMP/install-imut2.log" | tr '\n' ' ')"
  if [ "$r_mut2" = "I-ignored-landed I-untracked-landed " ]; then
    note "ok    I mutant 2 restoring the directory copy cp -pR <fixture>/* fails the not-landed sub-arms and only those"
  else note "FAIL  I mutant 2 restoring cp -pR <fixture>/* scored '$r_mut2', expected exactly 'I-ignored-landed I-untracked-landed'"; rc=1; fi
  cp "$MI2" "$TMP/nested-dot/scripts/install-mut2.sh"
  r_mut2d="$(dotonly_check "$TMP/nested-dot/scripts/install-mut2.sh" "$TMP/install-imut2-dot.log" | tr '\n' ' ')"
  if [ "$r_mut2d" = "I-dotonly-rc " ]; then
    note "ok    I mutant 2 restoring cp -pR <fixture>/* aborts the install on a dotfile-only fixture (I-dotonly-rc only)"
  else note "FAIL  I mutant 2 on the dotfile-only world scored '$r_mut2d', expected exactly 'I-dotonly-rc'"; rc=1; fi
fi

[ "$rc" -eq 0 ] && note "PASS  shipped-rule-version-floor -- detector correct on both sides of the boundary, no copy-time gate, uninstall scoped by prefix"
exit "$rc"
