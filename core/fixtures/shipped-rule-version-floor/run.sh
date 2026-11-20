#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
#      ai-dlc registration in settings.json, and the consumer's own entries intact.
#   I  a shipping fixture carrying a SUBDIRECTORY installs whole (BL-892): install exits 0,
#      the nested executable lands executable OVER a stale 0644 copy, the nested data file
#      lands non-executable, and uninstall removes them. Driven in a copy of the distribution
#      whose only fixture is lib/ plus a seeded sub/, so arm I's verdict rests on that seed
#      alone and not on the shape of every other fixture the sandbox carries (BL-871 measured
#      that shape deciding the main install).
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

# IN PROCESS (BL-878). Every drive of the three subjects calls its entry function through lib/inproc.sh's
# inproc_run, in a subshell made to look like a fresh `bash <subject>`. No inproc_load: one pass sources the path it
# names, so a pass is logged under its own subject, a copy under $TMP/nested-* included (suffix-matched). No call
# sits under if, !, && or ||: install.sh's and uninstall.sh's own `set -e` would be suspended there, and the
# in-process answer would stop being the program's. The program runs only in the cli cells (cells.decl).
# Each subject must carry both halves of the wrap: its `<p>_main() {` line and the column-0 source guard. Sourcing
# a subject with neither would run its body in the subshell on inproc_run's arguments; one half alone is a
# respelled subject this fixture cannot drive.
for _s in "$INSTALL:ai_dlc_install_main" "$UNINSTALL:ai_dlc_uninstall_main" "$HOOK:arf_main"; do
  _f="${_s%:*}"; _m="${_s##*:}"
  grep -qx "$_m() {" "$_f"; _gm=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$_f"; _gg=$?
  if [ "$_gm" -gt 1 ] || [ "$_gg" -gt 1 ]; then echo "FIXTURE ERROR: cannot read $_f" >&2; exit 2; fi
  if [ "$_gm" -ne 0 ] || [ "$_gg" -ne 0 ]; then
    echo "FAIL  $_f is not loadable: \`$_m() {\` line $([ "$_gm" -eq 0 ] && echo present || echo MISSING), column-0 source guard $([ "$_gg" -eq 0 ] && echo present || echo MISSING)" >&2
    exit 1
  fi
done
unset _s _f _m _gm _gg
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

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
  # install.sh refuses before writing anything when its function file is not beside it.
  cp "$INSTALL" "$UNINSTALL" "$ROOT/scripts/install-scaffold-ignore.sh" "$d/scripts/"
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
# writes anything.
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
  inproc_run "$inst" ai_dlc_install_main "$t" > "$log" 2>&1; [ "$?" -eq 0 ] || echo I-rc
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
  inproc_run "$inst" ai_dlc_install_main "$t" > "$log" 2>&1; [ "$?" -eq 0 ] || echo I-dotonly-rc
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
  inproc_run "$inst" ai_dlc_install_main "$t" > "$log" 2>&1; [ "$?" -ne 0 ] || echo I-nogit-rc
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
    inproc_run "$d/scripts/uninstall.sh" ai_dlc_uninstall_main "$t" --force > "$TMP/uninstall-i.log" 2>&1
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
  CLAUDE_CONFIG_DIR="$TMP/cfg-none" CLAUDE_PROJECT_DIR="$d" AI_AGENT="$agent" PATH="$empty:/usr/bin:/bin" \
    inproc_run "$HOOK" arf_main </dev/null 2>&1
}
# hook_cm <project-dir> <config-dir> <SessionStart source>: the context-mode presence check, driven with the
# real SessionStart input shape and a fixture-made config dir so no verdict reads this machine's ~/.claude.
hook_cm() {
  local d="$1" cfg="$2" src="$3" empty; empty="$(mktemp -d "$TMP/nobin.XXXXXX")"
  CLAUDE_CONFIG_DIR="$cfg" CLAUDE_PROJECT_DIR="$d" AI_AGENT=claude-code_2-1-226_agent PATH="$empty:/usr/bin:/bin" \
    inproc_run "$HOOK" arf_main <<<"{\"hook_event_name\":\"SessionStart\",\"source\":\"$src\"}" 2>&1
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

# --- the cli cells (cells.decl): each subject run as a PROGRAM once per distinct CLI outcome --------------------
# Each cell starts the subject as FXCELL=<id> bash <subject> and makes the in-process call on the same input, in the
# same world rebuilt at the same path, and holds the two to one answer: stdout, stderr, exit code, and the target's
# file list. The hook mints a fresh provenance nonce per run, so its 16-hex nonce is the one field normalised. A cell
# that matches but lands on the wrong outcome FAILs as well. cli-install-ok is arm F's install and cli-uninstall-ok
# is arm G's uninstall: their in-process twins build the trees F, G and H read, so neither adds a run of its own.
EQ="$TMP/eq"; mkdir -p "$EQ" || exit 2
eq_world() { rm -rf "$1"; mkdir -p "$1/_bmad"; ( cd "$1" && git init -q . ); }
eq_nobmad() { rm -rf "$1"; mkdir -p "$1"; }
eq_tree() { ( cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort ); }
eq_norm() { sed 's/nonce=[0-9a-f]\{16\}/nonce=N/g' "$1"; }
eq_same() { # <id> -> 0 when the program's and the in-process answer agree on every recorded channel
  local id="$1" x
  for x in out err rc tree; do
    [ -f "$EQ/$id.cl.$x" ] || [ -f "$EQ/$id.ip.$x" ] || continue
    [ "$(eq_norm "$EQ/$id.cl.$x")" = "$(eq_norm "$EQ/$id.ip.$x")" ] || { echo "$x"; return 1; }
  done
  return 0
}
eq_rc() { cat "$EQ/$1.cl.rc"; }
# eq_run <id> <world-builder> <target> <subject> <main> <args...>: <target> is rebuilt by <world-builder> before
# each side; stdin is $EQ_IN (default /dev/null). The in-process side runs second, so its tree is the one left.
eq_run() {
  local id="$1" mk="$2" t="$3" s="$4" m="$5"; shift 5
  "$mk" "$t"
  FXCELL="$id" bash "$s" "$@" < "${EQ_IN:-/dev/null}" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  [ -d "$t" ] && eq_tree "$t" > "$EQ/$id.cl.tree"
  "$mk" "$t"
  inproc_run "$s" "$m" "$@" < "${EQ_IN:-/dev/null}" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  [ -d "$t" ] && eq_tree "$t" > "$EQ/$id.ip.tree"
  return 0
}
eq_verdict() { # <id> <want rc> <positive line regex, on stdout> <what>
  local id="$1" want="$2" re="$3" what="$4" d
  d="$(eq_same "$id")"; local same=$?
  if [ "$same" -eq 0 ] && [ "$(eq_rc "$id")" = "$want" ] && grep -Eq "$re" "$EQ/$id.cl.out"; then
    note "ok    $id: the program $what exactly as the in-process call does (stdout, stderr, exit $want, file list)"
  else
    note "FAIL  $id: the program and the in-process call differ ($d) or the outcome is not exit $want with /$re/ (program exit $(eq_rc "$id"))"; rc=1
  fi
}

# --- F: install.sh ships the file, with no version gate ---------------------
t="$TMP/tgt-f"
oldbin="$(mktemp -d "$TMP/old.XXXXXX")"
printf '#!/bin/bash\necho "1.9.0 (Claude Code)"\n' > "$oldbin/claude"; chmod +x "$oldbin/claude"
PATH="$oldbin:$PATH" eq_run cli-install-ok eq_world "$t" "$INSTALL" ai_dlc_install_main "$t"
eq_verdict cli-install-ok 0 '^Installation complete!$' "installs into a fresh target"
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
cp -Rp "$t" "$TMP/tgt-g" || exit 2
eq_gworld() { rm -rf "$1"; cp -Rp "$TMP/tgt-g" "$1"; }
printf 'y\n' > "$EQ/yes"
EQ_IN="$EQ/yes" eq_run cli-uninstall-ok eq_gworld "$t" "$UNINSTALL" ai_dlc_uninstall_main "$t"
eq_verdict cli-uninstall-ok 0 '^To also remove BMAD Method' "uninstalls an installed target, answering y"
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
# driver added to core later is covered the moment it ships. Each property is its own arm.
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
inproc_run "$INSTALL" ai_dlc_install_main "$hs" > "$TMP/install-h.log" 2>&1
[ "$?" -eq 0 ] || { echo "run.sh: install into the seeded world failed" >&2; exit 2; }
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

inproc_run "$UNINSTALL" ai_dlc_uninstall_main "$hs" --force > "$TMP/uninstall-h.log" 2>&1
grep -q 'aiDlcRoles.dev' "$TMP/uninstall-h.log" && grep -q 'aiDlcRoles.qa' "$TMP/uninstall-h.log" \
  && grep -q 'Consumer-tuned AI/DLC configuration left in place' "$TMP/uninstall-h.log" \
  || { note "FAIL  H7 the closing listing does not name the tuned roles left in place"; rc=1; }
grep -q '\.claude/schemas/audit-anchors\.json' "$TMP/uninstall-h.log" \
  || { note "FAIL  H9 the closing listing does not name the edited schema left in place"; rc=1; }
h_seed="$(h_check "$hs" seeded)"
if [ -z "$h_seed" ]; then note "ok    H seeded install -> uninstall removed every AI/DLC file and registration, kept every consumer-authored one"
else note "FAIL  H seeded-world arms failed: $(echo $h_seed)"; rc=1; fi

# --- the remaining cli cells (cells.decl): the two refusals and the hook's two outputs ---------------------------
eq_hook_world() { rm -rf "$1"; mkdir -p "$1/.claude/rules"; [ "$EQ_HOOK_RULE" = 1 ] && printf 'x\n' > "$1/.claude/rules/$RULE"; return 0; }
eq_run cli-install-refuse eq_nobmad "$EQ/t" "$INSTALL" ai_dlc_install_main "$EQ/t"
eq_verdict cli-install-refuse 1 '^Warning: BMAD Method not detected' "refuses a target with no _bmad/"
eq_run cli-uninstall-refuse eq_world "$EQ/t" "$UNINSTALL" ai_dlc_uninstall_main "$EQ/t" --force
eq_verdict cli-uninstall-refuse 1 '^AI/DLC does not appear to be installed' "refuses a target with nothing installed"
EQ_HOOK_RULE=0 CLAUDE_PROJECT_DIR="$EQ/t" AI_AGENT=claude-code_1-9-0_agent PATH="$TMP/nobin-eq:/usr/bin:/bin" \
  eq_run cli-hook-silent eq_hook_world "$EQ/t" "$HOOK" arf_main
if eq_same cli-hook-silent >/dev/null && [ "$(eq_rc cli-hook-silent)" = 0 ] && [ ! -s "$EQ/cli-hook-silent.cl.out" ] \
   && [ ! -s "$EQ/cli-hook-silent.cl.err" ]; then
  note "ok    cli-hook-silent: the program is silent with no rule file exactly as the in-process call is (exit 0)"
else note "FAIL  cli-hook-silent: the program and the in-process call differ, or the hook spoke with no rule file"; rc=1; fi
EQ_HOOK_RULE=1 CLAUDE_PROJECT_DIR="$EQ/t" AI_AGENT=claude-code_1-9-0_agent PATH="$TMP/nobin-eq:/usr/bin:/bin" \
  eq_run cli-hook-loud eq_hook_world "$EQ/t" "$HOOK" arf_main
eq_verdict cli-hook-loud 0 'FLOOR NOT MET' "reports a rule file below the floor"
if [ "$(eq_rc cli-install-ok)" != "$(eq_rc cli-install-refuse)" ] && [ "$(eq_rc cli-uninstall-ok)" != "$(eq_rc cli-uninstall-refuse)" ] \
   && ! cmp -s "$EQ/cli-hook-silent.cl.out" "$EQ/cli-hook-loud.cl.out"; then
  note "ok    cli cells discriminate: install and uninstall each exit 0 and 1, and the hook's two outputs differ"
else note "FAIL  cli cells do not discriminate: a subject's two cells gave one answer"; rc=1; fi

# --- J: context-mode user-scope presence (BL-1188): WARN on startup only, fail-open everywhere else ---
cmid='context-mode@context-mode'
mkcfg() { # mkcfg <name> <json or empty for no file>
  local c="$TMP/cfg-$1"; mkdir -p "$c/plugins"; [ -z "$2" ] || printf '%s\n' "$2" > "$c/plugins/installed_plugins.json"; printf '%s' "$c"; }
c_user="$(mkcfg user "{\"version\":2,\"plugins\":{\"$cmid\":[{\"scope\":\"user\",\"version\":\"1\"}]}}")"
c_proj="$(mkcfg proj "{\"version\":2,\"plugins\":{\"$cmid\":[{\"scope\":\"project\",\"projectPath\":\"/x\",\"version\":\"1\"}]}}")"
c_bad="$(mkcfg bad 'not json')"
c_unk="$(mkcfg unk "{\"version\":9,\"plugins\":{}}")"
c_miss="$(mkcfg miss '')"
pj="$(proj)"                       # no rule file: the warning must not depend on one
pr="$(proj)"; printf 'x\n' > "$pr/.claude/rules/$RULE"
po="$(proj)"; printf '{"enabledPlugins":{"%s":false}}\n' "$cmid" > "$po/.claude/settings.json"
cm_warn() { # label expected(1|0) <hook_cm args>
  local lab="$1" want="$2"; shift 2; local o got=0; o="$(hook_cm "$@")"
  case "$o" in *'no user-scope install'*) got=1;; esac
  if [ "$got" = "$want" ]; then note "ok    J $lab -- warn=$got"
  else note "FAIL  J $lab -- expected warn=$want, got $got: ${o:0:100}"; rc=1; fi
}
cm_warn "project-only record on startup, no rule file" 1 "$pj" "$c_proj" startup
cm_warn "project-only record on startup, rule file shipped" 1 "$pr" "$c_proj" startup
cm_warn "user record on startup" 0 "$pj" "$c_user" startup
cm_warn "project-only record on compact" 0 "$pj" "$c_proj" compact
cm_warn "project-only record on resume" 0 "$pr" "$c_proj" resume
cm_warn "explicit project false" 0 "$po" "$c_proj" startup
cm_warn "missing file" 0 "$pj" "$c_miss" startup
cm_warn "unparseable file" 0 "$pj" "$c_bad" startup
cm_warn "unknown schema version" 0 "$pj" "$c_unk" startup
o="$(hook_cm "$pr" "$c_proj" startup)"
if grep -c additionalContext <<<"$o" | grep -qx 1 && jq -e '.systemMessage and .hookSpecificOutput.additionalContext' >/dev/null 2>&1 <<<"$o"; then
  note "ok    J the warning rides the existing JSON object as systemMessage beside the one additionalContext"
else note "FAIL  J warning is not one valid object with systemMessage and one additionalContext"; rc=1; fi

# --- I --------------------------------------------------------------------------------------
arm_i

[ "$rc" -eq 0 ] && note "PASS  shipped-rule-version-floor -- detector correct on both sides of the boundary, no copy-time gate, uninstall scoped by prefix"
exit "$rc"
