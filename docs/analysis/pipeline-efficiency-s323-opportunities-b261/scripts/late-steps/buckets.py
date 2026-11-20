import sys, re; sys.path.insert(0, '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late')
from lib import *

def body(cmd):
    cmd = cmd.strip()
    cmd = re.sub(r'^cd\s+\S+\s*(?:&&|;|\n)\s*', '', cmd)
    return cmd

def bucket(d):
    n = d['name']
    if n != 'Bash':
        return {'Agent': 'dispatch(Agent)', 'SendMessage': 'dispatch(Agent)', 'Read': 'read', 'Edit': 'edit/write', 'Write': 'edit/write',
                'mcp__advisor__consult': 'advisor', 'AskUserQuestion': 'operator-ask',
                'mcp__plugin_context-mode_context-mode__ctx_execute': 'ctx_execute', 'mcp__plugin_context-mode_context-mode__ctx_search': 'ctx_search',
                'TaskStop': 'taskstop', 'ToolSearch': 'toolsearch', 'Monitor': 'monitor'}.get(n, n)
    c = body(d['inp'].get('command', ''))
    if re.search(r'snapshot-update\.sh|pipeline-snapshot', c): return 'snapshot-bookkeeping'
    if re.search(r'wait-for-deliverable', c): return 'wait-for-deliverable'
    if re.search(r'gate-(transition|checkpoint)|gate-slice|verdict\.sh|validate-[\w-]+\.sh|run-gate', c): return 'gate/validator scripts'
    if re.search(r'git push', c): return 'git push'
    if re.search(r'git (add|commit)', c): return 'git add/commit'
    if re.search(r'\bgit (log|show|status|diff|branch|fetch|rev|worktree|merge|checkout|cherry|stash|ls)', c): return 'git other'
    if re.search(r'\bgh ', c): return 'gh'
    if re.search(r'\baws |\bcurl ', c): return 'aws/curl (ops)'
    if re.search(r'pytest|test-aws-smoke|npm |ruff|mypy', c): return 'tests/lint'
    if re.search(r'^(cat >>?|python3? - <<|python3? -c|bash /private)', c) or '<<' in c: return 'script/heredoc authoring'
    if re.search(r'^(tail|head|sed -n|cat|grep|ls|wc|awk|jq|cut|date|test|\[|echo|find|stat|diff|cmp)', c): return 'read/inspect shell'
    if re.search(r'^(until|while|for|sleep)', c): return 'poll loop'
    return 'other bash'

def run(sess, windows):
    cs = sorted(calls(lead_path(sess)), key=lambda d: d['t0'])
    res = {}
    for name, a, b in windows:
        ta, tb = T(a), T(b)
        sel = [d for d in cs if ta <= d['t0'] < tb]
        agg = collections.defaultdict(lambda: [0, 0.0, 0.0])
        prev_end = ta
        for d in sel:
            turn = max(0.0, min(d['t0'] - prev_end, 300.0))
            bk = bucket(d)
            agg[bk][0] += 1; agg[bk][1] += d['t1'] - d['t0']; agg[bk][2] += turn
            prev_end = max(prev_end, d['t1'])
        res[name] = agg
        print(f"\n== {name} calls {len(sel)} wall {(tb-ta)/3600:.2f}h   (tool s = result latency; turn s = model/queue time before the call, capped 300 s)")
        for k, v in sorted(agg.items(), key=lambda kv: -(kv[1][1] + kv[1][2])):
            print(f"  {k:26} calls {v[0]:4d}  tool {v[1]/60:6.1f} min  turn {v[2]/60:6.1f} min  -> {v[2]/max(1,v[0]):5.0f} s/turn")
    return res

if __name__ == '__main__':
    run('64926214', [('SR 64926214', '2026-11-19T12:48:45Z', '2026-11-19T20:17:03Z'),
                     ('DV', '2026-11-19T20:17:03Z', '2026-11-20T01:36:11Z'),
                     ('RETRO', '2026-11-20T01:36:11Z', '2026-11-20T04:17:36Z')])
