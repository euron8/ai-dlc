# m2_pass_join.py -- BL-911 / BL-1175 item 5: per planning series, adversary spawns per pass joined to the pass's changed-part
# count plus the parts cited by the predecessor's CRITICAL and MAJOR findings plus the cross shard (the bound).
# usage: python3 -I m2_pass_join.py <dir of graph pass files saved from the s323 close> <seats_adversary output>
# The pass files are `git -C graph show <close sha>:_bmad-output/planning-artifacts/s323/<series>-adversarial-p<N>.md`, read only.
# For each pass, from its own provenance block: SHARDS = keys of shard_tool_use_ids (cross included); PARTS = part_sha labels
# (subject/document mode) or the artifact_sha `name@sha` entries (files mode, no part_sha). OWED (derived-set rule, BL-911 Progress):
# a part whose digest is not equal to the same label's digest in the predecessor (or the label is new), union the shard ordinals the
# predecessor's CRITICAL and MAJOR findings cite (`sections:` after a `### F-n — MAJOR —` heading; files mode: the `## Shard: story NN`
# block the finding sits in). BOUND = |owed| + 1 (the cross shard). A part whose digest repeats within the predecessor is not UNIQUELY
# unchanged and is owed.
import os, re, sys
D, SEATS = sys.argv[1:3]
SERIES = [("requirements", "requirements"), ("architecture", "ARCHITECTURE-SPINE"), ("carry-over-evaluation", "coe"),
          ("stories-test-strategy", "stories"), ("stories-test-strategy (test-strategy file)", "test-strategy")]
def prov(path):
    t = open(path).read(); p = t[t.rindex("\nskill: ") :]
    g = lambda k: (re.search(r"(?m)^%s: (.*)$" % k, p) or [None, ""])[1].strip()
    shards = [x.split("=")[0] for x in g("shard_tool_use_ids").split()]
    ps = dict(x.split("=") for x in g("part_sha").split()) if g("part_sha") else {}
    asha = {x.rsplit("@", 1)[0]: x.rsplit("@", 1)[1] for x in g("artifact_sha").split() if "@" in x}
    return dict(t=t, shards=shards, ps=ps, asha=asha, derived=g("shard_set_derived_from"), run=g("part_run"), verdict=g("verdict"))
def cited(t, files_mode):
    out = set(); cur = None; want = False
    for line in t.splitlines():
        m = re.match(r"## Shard: (?:story|section) (\S+)", line)
        if m: cur = m.group(1)
        m = re.match(r"### F-\S+ — (CRITICAL|MAJOR) —", line)
        if m:
            want = True
            if files_mode and cur: out.add(cur)
            continue
        if re.match(r"### ", line): want = False
        m = re.match(r"sections: (.*)$", line)
        if m and want and not files_mode:
            for s in re.split(r"[,\s]+", m.group(1).strip()):
                if s: out.add(s)
            want = False
    return out
seat = {}
for line in open(SEATS):
    m = re.match(r"(s323) (\S+): (.*)$", line.rstrip("\n"))
    if m and not m.group(2).startswith("gate-validation"):
        seat[m.group(2).rstrip(":")] = dict((a, int(b)) for a, b in re.findall(r"adversary:(\S+) n(\d+)", m.group(3)))
    m = re.match(r"(s323) (gate-validation\[\S+\]): (.*)$", line.rstrip("\n"))
    if m: seat[m.group(2)] = dict((a, int(b)) for a, b in re.findall(r"adversary:(\S+) n(\d+)", m.group(3)))
print("series | pass | files-mode | parts | shards dispatched (cross incl.) | changed vs predecessor | cited by predecessor CRIT/MAJOR | owed | bound = owed + 1 | shard_set_derived_from | verdict")
for lab, stem in SERIES:
    n = 1; prev = None
    while os.path.exists(os.path.join(D, "%s-adversarial-p%d.md" % (stem, n))):
        c = prov(os.path.join(D, "%s-adversarial-p%d.md" % (stem, n)))
        files = not c["ps"]
        parts = c["asha"] if files else c["ps"]
        if prev is None:
            print("%s | p%d | %s | %d | %d | - | - | - | - | - | %s" % (lab, n, "yes" if files else "no", len(parts), len(c["shards"]), c["verdict"]))
        else:
            pp = prev["asha"] if files else prev["ps"]
            vals = list(pp.values())
            keys = list(parts.keys())
            changed = [k for k in keys if k not in pp or pp[k] != parts[k] or vals.count(pp[k]) > 1]
            # ordinal of a part: part_sha label; files mode: 1-based position in the (name-sorted) artifact_sha list
            ordn = (lambda k: "%02d" % (keys.index(k) + 1)) if files else (lambda k: k)
            ch = {ordn(k) for k in changed}
            ci = {("%02d" % int(x)) if files else x for x in cited(prev["t"], files)}
            ci = {x for x in ci if x in {ordn(k) for k in keys}}
            owed = ch | ci
            print("%s | p%d | %s | %d | %d | %d | %d | %d | %d | %s | %s" % (lab, n, "yes" if files else "no", len(parts), len(c["shards"]), len(ch), len(ci - ch), len(owed), len(owed) + 1, c["derived"] or "-", c["verdict"]))
            # shard list actually dispatched vs owed
            disp = {s for s in c["shards"] if s != "cross"}
            print("    dispatched part shards %s | owed %s | dispatched minus owed %s | owed minus dispatched %s" % (sorted(disp), sorted(owed), sorted(disp - owed), sorted(owed - disp)))
        prev = c; n += 1
print()
print("adversary spawns per pass label in the transcripts (m2_seats_adversary.txt, s323 lines):")
for k, v in seat.items(): print("  %s: %s" % (k, v))
