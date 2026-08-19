# BL-056 receipt. Keyed on BEHAVIOUR: it executes the workflow's own run: bodies and the
# shipping validator. No arm greps the template for a flag, a path form, or a message --
# every one of those is renameable and a comment satisfies a grep.
# Exit 0 = fixed. Any other code names the arm that refused.
import os, re, sys, json, fnmatch, tempfile, shutil, subprocess


# RESOLVE THE ROOT BY WALKING UP FOR A MARKER, NEVER BY TRUSTING THE ARGUMENT AND NEVER BY
# COUNTING `..` HOPS. A checker that counts hops answers differently from the repo root, from a
# subdirectory, and from a sandbox that copied it -- and the sandbox answer is the silent one.
# The argument is a STARTING POINT, not the answer; `backlog-reverify.sh` evals this from the
# repo root, a fixture may drive it from anywhere, and both must agree.
def _resolve_root(start):
    d = os.path.realpath(start or os.getcwd())
    while True:
        if os.path.exists(os.path.join(d, "VERSION")):
            return d
        p = os.path.dirname(d)
        if p == d:
            return None
        d = p


root = _resolve_root(sys.argv[1] if len(sys.argv) > 1 else None)
if root is None:
    # No marker anywhere above the start. Report NOT-FIXED rather than a verdict: a checker that
    # cannot find its corpus has established nothing, and a clean run here would be a false close.
    sys.stderr.write("verify-bl056: could not resolve the project root (no VERSION marker above "
                     "the start path). Refusing to report a verdict.\n")
    sys.exit(3)

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT, so both subjects may legitimately be absent in a
# consumer tree that has not yet pulled the code this guards. The discovery arms below exit
# non-zero in that case, which reverify reads as STILL-LIVE -- the safe direction. This must
# never report 0 for a tree it did not examine.
DEVNULL = subprocess.DEVNULL
RETRO = "docs/retro/s303/retro.md"

def run(cmd, cwd=None, env=None):
    return subprocess.call(cmd, cwd=cwd, env=env, stdout=DEVNULL, stderr=DEVNULL)

# --- discover BOTH subjects by content, so a rename of either does not strand the receipt ---
SD = os.path.join(root, "core/scripts")
vc = []
if os.path.isdir(SD):
    for f in sorted(os.listdir(SD)):
        if f.endswith(".sh"):
            t = open(os.path.join(SD, f), errors="replace").read()
            if "--require-skill" in t and "RETRO_PATH_RE" in t:
                vc.append(f)
if len(vc) != 1:
    sys.exit(1)
VB = vc[0]
V = os.path.join(SD, VB)
TD = os.path.join(root, "core/ci-templates")
yc = []
if os.path.isdir(TD):
    for f in sorted(os.listdir(TD)):
        if f.endswith((".yml", ".yaml")):
            t = open(os.path.join(TD, f), errors="replace").read()
            if VB in t and "pull_request:" in t and "paths:" in t:
                yc.append(f)
if len(yc) != 1:
    sys.exit(2)
Y = os.path.join(TD, yc[0])
src = open(Y, errors="replace").read()
SCH = os.path.join(root, "core/schemas/provenance-block.json")
if not os.path.exists(SCH):
    sys.exit(3)

# --- the discriminating artifact, built from the schema, never restated ---
S = json.load(open(SCH))
e = S["envelope"]
L = [e["open"], "skill: " + S["stray_scan"]["party_mode_skills"][0],
     "invoked_at: 2026-07-28T09:00:00Z", "tool_use_id: toolu_abc123def456",
     "mode: subagent", "lead_role: sm",
     "findings_critical: 0", "findings_major: 0", "findings_minor: 0", e["close"], ""]
DISCRIM = "\n".join(L)          # a REAL party-mode block, missing only transcript_path

def body(chunk):
    m = re.search(r"\n +run: \|\n(.*)", chunk, re.S)
    if not m:
        return None
    ind, out = None, []
    for ln in m.group(1).split("\n"):
        if not ln.strip():
            out.append("")
            continue
        cur = len(ln) - len(ln.lstrip())
        if ind is None:
            ind = cur
        if cur < ind:
            break
        out.append(ln[ind:])
    return "\n".join(out)

steps = re.split(r"\n(?=      - name: )", src)
W = tempfile.mkdtemp()
G = tempfile.mkdtemp()

def fail(n):
    shutil.rmtree(W, ignore_errors=True)
    shutil.rmtree(G, ignore_errors=True)
    sys.exit(n)

def w(base, p, c):
    fp = os.path.join(base, p)
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    open(fp, "w").write(c)
    return fp

# --- ARM T: the workflow's own trigger must cover the migrated retro path ---
m = re.search(r"\n    paths:\n((?:      - .*\n)+)", src)
if not m:
    fail(10)
pats = [l.strip()[2:].strip().strip(chr(34)).strip(chr(39))
        for l in m.group(1).rstrip("\n").split("\n")]
if not any(fnmatch.fnmatch(RETRO, p) for p in pats):
    fail(11)

# --- ARM F: changed-set filter AND sprint extraction, executed against a REAL git repo ---
sp = [c for c in steps if body(c) and "git diff --name-only" in body(c)]
if len(sp) != 1:
    fail(12)
if run(["git", "init", "-q", "."], cwd=G) != 0:
    fail(13)
run(["git", "config", "user.email", "t@t"], cwd=G)
run(["git", "config", "user.name", "t"], cwd=G)
run(["git", "commit", "-q", "--allow-empty", "-m", "base"], cwd=G)
base = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=G).decode().strip()
w(G, RETRO, "x\n")
run(["git", "add", "-A"], cwd=G)
run(["git", "commit", "-qm", "retro"], cwd=G)
head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=G).decode().strip()
b = body(sp[0])
b = b.replace("${{ github.event.pull_request.base.sha }}", base)
b = b.replace("${{ github.event.pull_request.head.sha }}", head)
if "${{" in b:
    fail(14)
go = os.path.join(G, "gh_out")
open(go, "w").write("")
env = dict(os.environ)
env["GITHUB_OUTPUT"] = go
run(["bash", "-c", b], cwd=G, env=env)
sprint = ""
for ln in open(go, errors="replace"):
    if ln.startswith("sprint="):
        sprint = ln.split("=", 1)[1].strip()
if sprint != "303":
    fail(15)

# --- ARM A: the validator must still discriminate, in BOTH directions ---
w(W, "docs/notes/plain.md", "# n\n")
if run(["bash", V, os.path.join(W, "docs/notes/plain.md")]) != 0:
    fail(16)
w(W, RETRO, DISCRIM)
if run(["bash", V, os.path.join(W, RETRO)]) != 1:
    fail(17)
os.remove(os.path.join(W, RETRO))

# --- ARM V + R: replay every retro invocation the workflow actually EMITS ---
vs = [c for c in steps if body(c) and VB in body(c) and "chmod" in body(c)]
if not vs:
    fail(18)
log = os.path.join(W, "argv.log")
open(log, "w").write("")
rec = w(W, "scripts/ai-dlc/" + VB,
        "#!/bin/sh\nprintf \"%s\\t\" \"$@\" >> \"$ARGV_LOG\"\nprintf \"\\n\" >> \"$ARGV_LOG\"\nexit 0\n")
os.chmod(rec, 0o755)
env2 = dict(os.environ)
env2["ARGV_LOG"] = log
for c in vs:
    bb = body(c).replace("${{ steps.sprint.outputs.sprint }}", sprint)
    if "${{" in bb:
        fail(19)
    run(["bash", "-c", bb], cwd=W, env=env2)
seen = 0
for ln in open(log, errors="replace"):
    args = [a for a in ln.rstrip("\n").split("\t") if a != ""]
    if not any("docs/retro/" in a for a in args):
        continue
    seen += 1
    made = []
    for a in args:
        if a.startswith("docs/retro/"):
            w(W, a, DISCRIM)
            made.append(os.path.join(W, a))
    if not made:
        fail(20)
    # V: the emitted invocation must REFUSE a retro doc missing transcript_path
    if run(["bash", V] + args, cwd=W) == 0:
        fail(21)
    for p in made:
        os.remove(p)
    # B: a missing artifact is exit 1, never exit 2 -- catches a malformed flag position
    if run(["bash", V] + args, cwd=W) == 2:
        fail(22)
    # R: the requirement must NOT depend on the path classifier. Same invocation, same
    # blockless doc, at a path the retro regex does not recognise: still must refuse.
    alt = ["docs/notes/plain2.md" if a.startswith("docs/retro/") else a for a in args]
    w(W, "docs/notes/plain2.md", "# n\n")
    if run(["bash", V] + alt, cwd=W) == 0:
        fail(23)
    os.remove(os.path.join(W, "docs/notes/plain2.md"))
if seen == 0:
    fail(24)
shutil.rmtree(W, ignore_errors=True)
shutil.rmtree(G, ignore_errors=True)
sys.exit(0)
