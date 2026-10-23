#!/bin/bash
#
# AI/DLC Hook Registration Validator — a shipped hook nothing registers is INERT,
# and inert reads exactly like working.
#
# THE HOLE. A consumer receives a new hook through `ai-dlc-update`, not through
# `install.sh`. The pull delivers two halves and only one of them is mechanical:
#
#   the FILE          `apply.sh` writes `.claude/hooks/ai-dlc-<x>.sh` as a pure
#                     apply, in the driver, with a manifest row.
#   the REGISTRATION  `reconcile/settings-merge.sh` rewrites `.claude/settings.json`.
#                     It is a script for exactly the right reason — its own header
#                     says "prose that an agent retypes as jq drifts" — but nothing
#                     CALLS it. Its two invocation sites are both prose, in
#                     `ai-dlc-update/SKILL.md`. `apply.sh` names it zero times.
#
# So the half that is enforced puts the file on disk and the half that is prose wires
# it up, and a session that skips the prose step ships a hook that sits there, looks
# installed, and never fires. `settings-merge.sh` is correct; its INVOCATION is the
# residual.
#
# THIS IS NOT HYPOTHETICAL AND IT HAS ALREADY FIRED. Measured read-only against the
# reference consumer (`/Users/n8/git/graph`) at the time this was written: 15 ai-dlc
# hook files present under `.claude/hooks/`, 14 registered in `.claude/settings.json`,
# 0 in `.claude/settings.local.json` — and the one left over is
# `ai-dlc-rules-floor.sh`, which `templates/settings.json.template` registers and
# `install.sh` calls "the SINGLE detector, running every session". It has been on that
# consumer's disk, unregistered, since the release that added it. Nothing anywhere
# reported an absence, because there is nothing that reads this join.
#
# WHY THIS SHAPE AND NOT A FIX TO THE CALL PATH. Making `apply.sh` invoke
# `settings-merge.sh` would close the one path that was measured and leave the class
# open: a hand-edited settings.json, a merge that failed mid-write, a consumer restored
# from a partial backup, a future delivery path nobody has written yet. This asserts the
# PROPERTY — every hook that is here is wired — so it catches the inert state whatever
# produced it, including the states that already exist on disk today. It is also the
# only form that can be pointed at a consumer that is broken RIGHT NOW, with no pull.
#
# BOTH SIDES ARE DERIVED AND NEITHER IS HAND-LISTED.
#   present     glob `<root>/.claude/hooks/ai-dlc-*.sh` — install.sh copies that
#               directory wholesale from `core/hooks/`, so the glob is the shipped set.
#   registered  every `command` string anywhere under `.hooks` in `.claude/settings.json`
#               (and `settings.local.json`, which Claude Code merges) that matches the
#               ai-dlc ownership pattern.
#
# THE OWNERSHIP PATTERN IS READ OUT OF `settings-merge.sh`, NOT RESTATED HERE. That
# pattern is the definition of "an ai-dlc-owned hook block" — it is what the merge
# strips and re-appends — and a second copy of it here would be a join whose two sides
# can drift into agreement about the wrong set. The regex is extracted from the jq
# source, unescaped, and then PROVED against a positive and a negative probe before it
# is used: an extractor that silently returns garbage would make every consumer read
# clean, which is this repo's named defect class arriving through the instrument.
#
# TWO LAYOUTS. `settings-merge.sh` lives at `core/skills/ai-dlc-update/reconcile/` in
# the distribution and `.claude/skills/ai-dlc-update/reconcile/` on a consumer.  Both
# are named explicitly and BOTH are rooted at `--root`; neither is found by walking up
# from this script's own location, which the install mapping breaks (invariant I33).
#
# USAGE
#   scripts/ai-dlc/validate-hook-registration.sh [--root PATH] [--quiet]
#
#   --root PATH  the project tree to judge. Defaults to the canonical AI_DLC_ROOT
#                resolution below — operator override, then the tree this script is
#                INSTALLED in, then CLAUDE_PROJECT_DIR, then the cwd's tree — so a
#                consumer's own copy judges that consumer whatever repo the session
#                started in. Callers inside the reconcile engine pass the consumer
#                path explicitly and that always wins.
#
# EXIT
#   0  every present ai-dlc hook is registered and every registration names a hook that
#      is there — or there is no tree to judge, which is stated in words rather than
#      passed in silence
#   1  at least one present hook is UNREGISTERED, or a registration is DANGLING
#   2  usage, unreadable settings, or the ownership pattern could not be bound. Each of
#      those makes the comparison vacuous, and a vacuous comparison reports exactly what
#      a clean one reports, so this fails closed rather than printing a pass it did not
#      earn.

set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from two layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer
# and no fixed hop count fits both.
#
# THE PRECEDENCE IS LOAD-BEARING IN THIS SCRIPT IN PARTICULAR. `CLAUDE_PROJECT_DIR`
# names whichever repository the SESSION started in, and the entire subject of this
# check is "the tree whose hooks are inert". Reading that variable before this
# script's own install path would judge the developer's repo, find its hooks wired,
# and report the consumer clean — the exact defect the check exists to catch,
# arriving through the instrument. The earlier `git rev-parse --show-toplevel`
# default had the same shape one step removed: it answered about the cwd's repo, so
# a copy installed in a consumer and run from anywhere else judged the wrong tree.
#
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
#
# The terminal guard SUBSTITUTES an unresolvable path rather than `exit`ing. An
# explicit `--root` is parsed below and names a tree that need not be related to
# this script's install location at all, so dying here would break the one calling
# convention the reconcile engine uses. The `[ -d "$ROOT" ]` guard below is what
# fails closed, after the override has had its say.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
HR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HR_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$HR_ROOT" ] || HR_ROOT="$(ai_dlc_resolve_root "$HR_SCRIPT_DIR" || true)"
[ -n "$HR_ROOT" ] || HR_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$HR_ROOT" ] || HR_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
HR_ROOT="${HR_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------

ROOT=""
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 || exit 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '/^# USAGE/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: $(basename "$0") [--root PATH] [--quiet]" >&2; exit 2 ;;
  esac
done

ROOT_SRC="--root"
if [ -z "$ROOT" ]; then
  ROOT="$HR_ROOT"
  ROOT_SRC="the resolved project root"
fi
[ -d "$ROOT" ] || {
  echo "hook-registration: $ROOT_SRC '$ROOT' is not a directory." >&2
  echo "  Set AI_DLC_PROJECT_ROOT, or pass --root PATH naming the tree to judge." >&2
  exit 2
}

# `-I` (isolated): no PYTHON* environment, no user site, no cwd on sys.path. The body below is
# fixed text, so nothing in the judged tree or the caller's environment may change what runs.
python3 -I - "$ROOT" "$QUIET" "$HR_SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" <<'PY'
import os, sys

# --- THE READ RECORDER (HOOKREG_READS_OUT) -------------------------------------------------
#
# The reconcile engine runs this validator over a consumer and caches the verdict keyed on
# what the run READ. A key built from a hand-written copy of this body's reads goes stale the
# day a read is added here, and a stale key is a stale PASS. So the run records its OWN reads,
# in the SAME run that produces its output, from one place installed before any other import:
#
#   audit hook   `open` -> r, `os.scandir`/`os.listdir` -> w, every process-spawning event
#                -> `!`. These fire inside the interpreter before the call is attempted,
#                so an open or listing of an ABSENT path is recorded too, and no later edit
#                to the body can route around them.
#   wrappers     os.stat / os.lstat / os.access / os.readlink -> t. The audit hook does NOT
#                fire for a stat (measured: a stat of an absent file raises no event), and
#                os.path.isfile/isdir/exists/lexists/islink and glob all look these names
#                up on `os` at call time, so wrapping the attribute covers every caller.
#
# LIMIT: a reference to a stat function taken BEFORE this block runs, or a stat made from
# C without passing through `os`, is invisible. Neither exists in this body, and this block
# precedes every other import so none can be taken. DirEntry methods (`is_file` on a scandir
# entry) stat inside C; they are covered by the `w` of the listing that produced the entry.
#
# FORMAT: line 1 is the sentinel `hookreg-reads 1`; each later line is `<kind>\t<path>` with
# the path relative to --root (`.` for --root itself). Only paths under --root are written;
# `!` carries path `-`. Duplicates are dropped, first-seen order kept.
#
# The variable is NOT AI_DLC_-prefixed on purpose: fixtures scrub that prefix, and the engine
# keys AI_DLC_* names. Unset, nothing is installed. Set or unset, stdout, stderr and the exit
# code are byte-identical: every recorder failure is swallowed, because an exception raised
# inside an audit hook aborts the audited operation.
if os.environ.get("HOOKREG_READS_OUT", ""):
    def _hr_install(out_path, root_arg):
        import atexit
        cwd = os.getcwd()
        base = os.path.normpath(os.path.join(cwd, root_arg))
        rows, keys, live = [], set(), [True]

        def note(kind, p):
            if not live[0]:
                return
            try:
                if kind == "!":
                    rel = "-"
                else:
                    if p is None or isinstance(p, int):
                        return
                    a = os.path.normpath(os.path.join(cwd, os.fsdecode(p)))
                    if a == base:
                        rel = "."
                    elif a.startswith(base.rstrip(os.sep) + os.sep):
                        rel = a[len(base.rstrip(os.sep)) + 1:]
                    else:
                        return
                k = (kind, rel)
                if k not in keys:
                    keys.add(k)
                    rows.append(k)
            except Exception:
                pass

        spawn = {"subprocess.Popen", "os.system", "os.exec", "os.posix_spawn", "os.spawn",
                 "os.fork", "os.forkpty", "os.startfile", "pty.spawn"}

        def hook(event, args):
            try:
                if event == "open":
                    note("r", args[0] if args else None)
                elif event in ("os.scandir", "os.listdir"):
                    note("w", args[0] if args else ".")
                elif event in spawn:
                    note("!", None)
            except Exception:
                pass

        def wrap(name):
            orig = getattr(os, name)
            def w(path, *a, **k):
                note("t", path)
                return orig(path, *a, **k)
            setattr(os, name, w)

        def flush():
            live[0] = False
            try:
                with open(out_path, "w", encoding="utf-8") as fh:
                    fh.write("hookreg-reads 1\n")
                    for kind, rel in rows:
                        fh.write("%s\t%s\n" % (kind, rel))
            except Exception:
                pass
        # addaudithook FIRST: on a python3 without it (3.7 and older) it raises, and nothing
        # after it runs, so no stat wrapper is live and no flush is registered. No list is
        # written, and the engine records `!` rather than accepting a partial list.
        sys.addaudithook(hook)
        for _n in ("stat", "lstat", "access", "readlink"):
            wrap(_n)
        atexit.register(flush)
    try:
        _hr_install(os.environ["HOOKREG_READS_OUT"], sys.argv[1])
    except Exception:
        pass
# --- end recorder ---------------------------------------------------------------------------

import glob, json, re

root, quiet, self_path = sys.argv[1], sys.argv[2] == "1", sys.argv[3]

def say(*a):
    if not quiet:
        print(*a)

def fail_closed(msg):
    print("hook-registration: FAIL-CLOSED — " + msg, file=sys.stderr)
    sys.exit(2)

settings = os.path.join(root, ".claude", "settings.json")
local    = os.path.join(root, ".claude", "settings.local.json")
hookdir  = os.path.join(root, ".claude", "hooks")

# --- the tree may legitimately not be an ai-dlc consumer. Say so; never pass silently.
if not os.path.isfile(settings):
    say("hook-registration: SKIP — EXAMINED NOTHING — no .claude/settings.json under %s." % root)
    say("  Nothing to judge: this is not an installed ai-dlc consumer tree.")
    sys.exit(0)

# --- bind the ownership pattern to settings-merge.sh, the program that DEFINES it -----
#
# Distribution layout first, consumer layout second; both rooted at --root.
merge_candidates = [
    os.path.join(root, "core", "skills", "ai-dlc-update", "reconcile", "settings-merge.sh"),
    os.path.join(root, ".claude", "skills", "ai-dlc-update", "reconcile", "settings-merge.sh"),
]
merge = next((p for p in merge_candidates if os.path.isfile(p)), None)
if merge is None:
    fail_closed(
        "settings-merge.sh is at neither %s nor %s. That script is where the "
        "ai-dlc-owned-hook pattern is defined; without it this check would have to "
        "restate the pattern, and a restated pattern can agree about the wrong set."
        % tuple(merge_candidates))

try:
    src = open(merge, encoding="utf-8", errors="replace").read()
except OSError as e:
    fail_closed("could not read %s (%s)." % (merge, e))

# `($c | test("/\\.claude/hooks/ai-dlc-[^/]+\\.sh"))` — a jq string literal, so `\\`
# in the source is one backslash in the compiled regex.
m = re.search(r'\$c\s*\|\s*test\("((?:[^"\\]|\\.)*ai-dlc(?:[^"\\]|\\.)*)"\)', src)
if not m:
    fail_closed(
        "could not extract the ai-dlc hook-command pattern from %s. Its is_ai_dlc_block "
        "test is the definition of an owned block; an unreadable one makes every "
        "consumer read clean." % merge)
pattern = m.group(1).replace("\\\\", "\\")

try:
    rx = re.compile(pattern)
except re.error as e:
    fail_closed("the pattern extracted from %s does not compile (%s): %r" % (merge, e, pattern))

# --- PROVE THE INSTRUMENT BEFORE USING IT --------------------------------------------
#
# A pattern that matches nothing, and a pattern that matches everything, both produce a
# clean report over a broken tree. Neither probe is a hook that exists.
POS = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/ai-dlc-selftest-probe.sh'
NEG = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/some-other-tool.sh'
if not rx.search(POS):
    fail_closed("the pattern from %s (%r) does not match a canonical ai-dlc hook command. "
                "It would report every consumer's hooks unregistered." % (merge, pattern))
if rx.search(NEG):
    fail_closed("the pattern from %s (%r) also matches a NON-ai-dlc hook command. "
                "It would count a third-party block as our registration." % (merge, pattern))

# --- side A: what is on disk ----------------------------------------------------------
#
# A SOURCED LIBRARY IS NOT A HOOK, AND THE EXEMPTION IS DERIVED FROM THE OTHER SIDE OF THE JOIN
# RATHER THAN NAMED. `.claude/hooks/` holds one file no event invokes: the emitting hooks
# `.`-source it as a sibling for the context-provenance marker. Registering it would wire a
# consumer's settings to a command that reads no stdin and decides nothing.
#
# MEASURED ON A REHEARSAL, WHICH IS THE ONLY REASON THIS WAS CAUGHT BEFORE A CONSUMER SAW IT.
# Without this, a pull carrying the library emits `WORKLIST settings-merge ... hook(s) present
# and UNREGISTERED` naming it, and the row's remedy is to register it — so the pull would hand
# every consumer an instruction to do the wrong thing, in a row whose whole purpose is to be
# obeyed. A green run here and a green run there are not the same claim, and this is the shape
# that difference takes.
#
# KEYED ON "SOME SIBLING SOURCES IT", NEVER ON A NAME. A hand-written skip list exempts a file
# by name, so deleting the last `source` of a library would leave the exemption behind and this
# check would then permit a genuinely unregistered hook. Derived, a library nothing sources is
# scored as an unregistered hook again on the commit that orphans it. I13 in the distribution's
# validate-enforcement-map.sh and the hook-registration-join fixture derive the same set the
# same way; this copy is the one a CONSUMER runs.
sourced = set()
for p in glob.glob(os.path.join(hookdir, "*.sh")):
    try:
        for line in open(p, encoding="utf-8", errors="replace"):
            if "BASH_SOURCE" in line:
                sourced.update(re.findall(r"/([a-z0-9.-]+\.sh)", line))
    except OSError:
        pass

present = sorted(
    os.path.basename(p)
    for p in glob.glob(os.path.join(hookdir, "ai-dlc-*.sh"))
    if os.path.isfile(p) and os.path.basename(p) not in sourced
)

# --- side B: what settings register ---------------------------------------------------
#
# Walk the `hooks` subtree for every `command` string rather than assuming the exact
# nesting. The shape is Claude Code's, not ours, and a shape change must not silently
# empty this side.
def commands(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "command" and isinstance(v, str):
                out.append(v)
            else:
                commands(v, out)
    elif isinstance(node, list):
        for v in node:
            commands(v, out)

def registered_in(path):
    if not os.path.isfile(path):
        return set(), False
    try:
        doc = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as e:
        fail_closed("%s is unreadable or not valid JSON (%s). Every hook would read as "
                    "unregistered, or none would." % (path, e))
    cmds = []
    commands(doc.get("hooks", {}), cmds)
    names = set()
    for c in cmds:
        for hit in rx.finditer(c):
            names.add(hit.group(0).rsplit("/", 1)[-1])
    return names, True

reg_main, _        = registered_in(settings)
reg_local, has_loc = registered_in(local)
registered = reg_main | reg_local

unregistered = sorted(set(present) - registered)
dangling     = sorted(registered - set(present))
local_only   = sorted(reg_local - reg_main)

say("hook-registration: root %s" % root)
say("  pattern (from %s): %s" % (os.path.relpath(merge, root), pattern))
say("  present under .claude/hooks/: %d   registered in settings: %d (settings.json %d%s)"
    % (len(present), len(registered), len(reg_main),
       ", settings.local.json %d" % len(reg_local) if has_loc else ""))

# A zero over an empty population is not a finding. Say which one this is.
if not present and not registered:
    say("  Neither side has a member: no ai-dlc hook files and no ai-dlc registrations.")
    say("  Nothing to bind — install has not run, or this is not an ai-dlc tree.")
    sys.exit(0)

# --- THE FAILURE MESSAGE IS PART OF THE MECHANISM -------------------------------------
#
# This check runs in the consumer's pre-push hook, so a finding BLOCKS a push. A blocked
# push whose message the reader cannot act on is worse than no check at all: it is the
# shape that gets a guard commented out rather than a hook registered. So the message
# owes three things, and each is DERIVED rather than written down here.
#
#   which hook   the filename, from the glob.
#   what it did  the hook's own first header line, read off the file on disk. The file
#                being there is this check's whole premise, so the sentence is always
#                available, and it cannot go stale the way a table in this script would.
#   the fix      a command with NO placeholders. `templates/settings.json.template` is not
#                installed onto a consumer, so the template has to come from the
#                distribution — and `upstream`/`commit` are in the consumer's own stamp.
#                Reading them turns `git -C <dist> show "${theirs}:..."` into something a
#                reader can paste. When the stamp cannot be read the command is still
#                printed, with the two unresolved values named.
def purpose(name):
    """The hook's own one-line self-description, or a stated absence."""
    try:
        with open(os.path.join(hookdir, name), encoding="utf-8", errors="replace") as fh:
            head = [next(fh, "") for _ in range(10)][1:]
    except OSError:
        return "(purpose unreadable — the file could not be opened)"
    for line in head:
        s = line.strip()
        if s.startswith("#"):
            s = s.lstrip("#").strip()
            if s:
                return s
    return "(no description in its header)"

def stamp_fields():
    for rel in (".claude/.ai-dlc-version", ".ai-dlc-version"):
        p = os.path.join(root, rel)
        if not os.path.isfile(p):
            continue
        try:
            txt = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        up = re.search(r"^upstream:\s*(\S+)", txt, re.M)
        cm = re.search(r"^commit:\s*(\S+)", txt, re.M)
        sha = cm.group(1) if cm else None
        # A DEV INSTALL STAMPS `commit: <sha>-dirty`, AND THAT IS NOT CHECKOUT-ABLE.
        # install.sh derives AI_DLC_COMMIT with `git describe --dirty`, so a consumer
        # installed from an uncommitted distribution tree carries the suffix. Measured:
        # the reference consumer reads a clean `959e778`, a fresh local install reads
        # `d2378b4-dirty`, and pasting the second gives `error: pathspec did not match`
        # as the first line of the remedy. Strip the suffix, then require the remainder
        # to LOOK like a sha — anything else is reported as needing substitution rather
        # than printed as though it would work.
        if sha:
            sha = re.sub(r"-dirty$", "", sha)
            if not re.fullmatch(r"[0-9a-fA-F]{7,40}", sha):
                sha = None
        return (up.group(1) if up else None), sha
    return None, None

def print_fix():
    up, cm = stamp_fields()
    missing = [n for n, v in (("upstream", up), ("commit", cm)) if not v]
    print("  FIX — paste this (it works from any directory, and re-runs this check at the end):")
    print("")
    print('    d="$(mktemp -d)" \\')
    print('      && git clone -q %s "$d" \\' % (up or "<upstream: SUBSTITUTE THE URL>"))
    print('      && git -C "$d" checkout -q %s \\' % (cm or "<commit: SUBSTITUTE THE SHA>"))
    print('      && bash %s \\' % merge)
    print('           --consumer %s \\' % settings)
    print('           --template "$d/templates/settings.json.template" \\')
    print('      && rm -rf "$d" \\')
    # SELF is passed in from bash. `sys.argv[0]` is "-" under a heredoc, and the first
    # draft of this message printed `bash <cwd>/-` as the last line of a command it told
    # the reader to paste — a remedy that cannot run, in the one place this check gets to
    # speak. Measured on the reference consumer's real finding, before shipping.
    print('      && bash %s --root %s' % (self_path, root))
    print("")
    if missing:
        print("  The stamp at .claude/.ai-dlc-version did not yield: %s." % ", ".join(missing))
        print("  Fill the marked value(s) in before pasting — they name the distribution this")
        print("  project was installed from and the revision its settings template belongs to.")
    print("  `settings-merge.sh` is the ONE program that owns this file's ai-dlc blocks; it")
    print("  strips the stale ones, re-appends the template's, and preserves your permissions,")
    print("  env, mcpServers and statusLine untouched. Do not hand-edit the JSON instead —")
    print("  the merge is a contract install and pull both apply, and a hand edit diverges.")
    print("  It never writes env: declare AI_DLC_MODEL_<FAMILY>_WINDOW there yourself if --check asks.")

rc = 0

if unregistered:
    rc = 1
    print("  UNREGISTERED — present on disk, wired to nothing, will never fire:")
    for n in unregistered:
        print("    .claude/hooks/%s" % n)
        print("        %s" % purpose(n))
    print("  Each of those is a file Claude Code has never been told to run. There is no")
    print("  error, no log line and no absence anywhere — an unregistered hook is")
    print("  indistinguishable from one that is working, which is why this check exists.")
    print_fix()
else:
    say("  UNREGISTERED: none (%d present hook(s) checked)" % len(present))

if dangling:
    rc = 1
    print("  DANGLING — registered in settings, no such file under .claude/hooks/:")
    for n in dangling:
        print("    %s" % n)
    print("  Claude Code cannot run these. The registration is stale: the hook was retired")
    print("  upstream and the strip half of the reconcile did not run.")
    if not unregistered:
        print_fix()
else:
    say("  DANGLING: none (%d registration(s) checked)" % len(registered))

if local_only:
    # Not a failure: the hook IS live for whoever holds that file. It is worth naming
    # because settings.local.json is per-machine and usually git-ignored, so the same
    # tree is silently inert for every teammate.
    say("  NOTE — registered only in settings.local.json (per-machine; inert for teammates):")
    for n in local_only:
        say("    %s" % n)

sys.exit(rc)
PY
