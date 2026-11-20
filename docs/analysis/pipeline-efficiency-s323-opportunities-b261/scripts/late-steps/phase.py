import sys, json, collections, re
sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late')
from lib import *
FAM = re.compile(r"(?:pytest|npm (?:run )?\w+|npx \w+|[\w.-]+\.sh|git (?:push|fetch|merge|pull|rebase|commit|log|diff|status|worktree|show|add|checkout|branch)|gh \w+ ?\w*|python3? -m \w+|python3? \S+|sleep|until|while|docker \w+|curl|jq|grep|cat|ls|head|tail|sed|awk|wc|echo|find|cd|test|mkdir)")
def fam(cmd):
    cmd = cmd.strip()
    m = FAM.findall(cmd)
    k = m[0] if m else (cmd.split()[0] if cmd.split() else '?')
    return re.sub(r'^.*/', '', k)[:40]

def run(sess, phases):
    cs = calls(lead_path(sess))
    cs.sort(key=lambda d: d['t0'])
    for name, a, b in phases:
        ta, tb = T(a), T(b)
        sel = [d for d in cs if ta <= d['t0'] < tb]
        print(f"\n=== {sess[:8]} {name} {a}..{b}  wall {(tb-ta)/3600:.2f}h  calls {len(sel)}  errs {sum(d['err'] for d in sel)}")
        tool = collections.defaultdict(lambda: [0, 0.0])
        bf = collections.defaultdict(lambda: [0, 0.0])
        for d in sel:
            lat = d['t1'] - d['t0']
            tool[d['name']][0] += 1; tool[d['name']][1] += lat
            if d['name'] == 'Bash':
                k = fam(d['inp'].get('command', ''))
                bf[k][0] += 1; bf[k][1] += lat
        print(' tools:', ', '.join(f"{k} {v[0]}/{v[1]:.0f}s" for k, v in sorted(tool.items(), key=lambda x: -x[1][1])[:14]))
        print(' bash fam:', ', '.join(f"{k} {v[0]}/{v[1]:.0f}s" for k, v in sorted(bf.items(), key=lambda x: -x[1][1])[:22]))
    return cs

if __name__ == '__main__':
    run('64926214', [('sprint-review', '2026-11-19T12:48:45Z', '2026-11-19T20:17:03Z'),
                     ('deploy-validate', '2026-11-19T20:17:03Z', '2026-11-20T01:36:11Z'),
                     ('retro', '2026-11-20T01:36:11Z', '2026-11-20T04:17:36Z')])
    run('53b4296a', [('sprint-review', '2026-11-19T02:53:10Z', '2026-11-19T07:45:51Z')])
