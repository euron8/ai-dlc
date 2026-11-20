"""BL-397: planned and done story counts per sprint, by `story-<N>-<M>:` mapping keys, read-only over a graph clone.

Usage: python3 story_count.py <graph-clone> <ref> <sprint>=<path> ...
  e.g. 322=_bmad-output/implementation-artifacts/sprint-status.yaml 321=_bmad-output/implementation-artifacts/s321/sprint-status.yaml

A story is a line `  story-<N>-<M>:` (a mapping key, alone on its line); its status is the first `status:` line
after it and before the next key. "naive" is the count of lines carrying `story-<N>-<M>` anywhere (comments, file
paths, prose), printed beside it as the near-miss: at graph ed61de745 it reads 50 for s321 and 16 for s322, against
25 and 8 keys, so an unanchored count is wrong by a factor of two.
Control: s321 must read 25 keys and 24 done (BL-397 b255), or the script exits 3.
"""
import re, subprocess, sys

G, REF = sys.argv[1], sys.argv[2]
KEY = re.compile(r"^\s+story-(\d+)-(\d+):\s*$")
bad = 0
for arg in sys.argv[3:]:
    n, path = arg.split("=", 1)
    t = subprocess.run(["git", "-C", G, "show", f"{REF}:{path}"], capture_output=True, text=True).stdout
    keys = []; cur = None
    for ln in t.split("\n"):
        m = KEY.match(ln)
        if m: cur = [m.group(0).strip(), None]; keys.append(cur); continue
        s = re.match(r"^\s+status:\s*(\S+)", ln)
        if s and cur and cur[1] is None: cur[1] = s.group(1)
    naive = sum(1 for ln in t.split("\n") if re.search(r"story-\d+-\d+", ln))
    done = sum(1 for k in keys if k[1] == "done")
    print(f"s{n} {REF}:{path}: keys {len(keys)}, done {done}, naive {naive}; not done: {[k for k in keys if k[1] != 'done']}")
    if n == "321" and (len(keys), done) != (25, 24): bad += 1; print("  CONTROL-FAILED: s321 must read 25 keys, 24 done")
sys.exit(3 if bad else 0)
