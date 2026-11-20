#!/usr/bin/env python3
"""Classify the s323 lead's calls (lead_calls.jsonl) by ACTIVITY and compute think/tool time per class.
Usage: python3 -I classify.py [lead_calls.jsonl] -> prints table; importable: classify(row)->class.
think = ts_call - latest result ts seen before it (model generation + harness), tool = rts - ts.
A gap > 300 s before a call is booked to 'WAIT>300s' (lead idle, awaiting a notification), not to the call.
"""
import json, re, sys, collections
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/implementation-build/'

def classify(r):
    n, i = r['name'], r['inp']
    if n == 'Agent':
        m = re.search(r'subagent_type', i)
        return 'dispatch:agent'
    if n == 'mcp__advisor__consult': return 'advisor'
    if n == 'SendMessage': return 'sendmessage'
    if n == 'TaskStop': return 'taskstop'
    if n in ('ListAgents', 'ToolSearch', 'AskUserQuestion'): return 'misc:' + n
    if n.startswith('mcp__plugin_context-mode'): return 'ctx-tool'
    if n in ('Edit', 'Write'):
        if 'wave-dag' in i: return 'plan:wave-dag'
        if 'gate-log' in i: return 'record:gate-log'
        if 'pipeline-snapshot' in i: return 'record:snapshot'
        if '/stories/' in i or 'story-' in i: return 'record:story-file'
        return 'edit-other'
    if n == 'Read':
        if re.search(r'\.claude/(skills|team-roles|rules)|postcompact|rule-bodies|SKILL\.md', i): return 'read:engine-text'
        if 'pipeline-snapshot' in i: return 'read:snapshot'
        if 'gate-log' in i: return 'read:gate-log'
        if re.search(r'planning-artifacts|stories|story-', i): return 'read:stories'
        if re.search(r'docs/reviews|dev-report|qa|review', i): return 'read:gate-outputs'
        if re.search(r'\.(py|sh|ts|tsx|yaml|yml|md)$', i): return 'read:other-files'
        return 'read:other'
    if n == 'Bash':
        if 'wait-for-deliverable' in i: return 'wait-beat'
        if re.search(r'gate-transition\.sh|validate-handoff-evidence|partition-review-diff|merge-review-shards\.sh (?!--record)|gate-checkpoint|validate-', i) and 'record-dispatch' not in i: return 'gate-scripts'
        if 'record-dispatch' in i or 'worktree add' in i: return 'build:worktree-setup'
        if re.search(r'git (-C \S+ )?merge|worktree remove|git branch -d|git -C \S+ rebase|git rebase|cherry-pick', i): return 'build:merge-cleanup'
        if 'snapshot-update' in i: return 'record:snapshot'
        if 'gate-log' in i: return 'record:gate-log'
        if re.search(r'pytest|npm (run )?test|vitest|jest|\.venv', i): return 'build:run-tests'
        if re.search(r'\bgit (-C \S+ )?(log|diff|status|show|rev-parse|ls-tree|cat-file|branch|fetch|for-each-ref|ls-files|rev-list|merge-base|add|commit|checkout|reset|worktree)', i): return 'git:read-or-commit'
        if re.search(r'^command:(ls|cat|sed|grep|head|tail|wc|find|stat|test|echo|printenv|date|rg|awk)\b', i): return 'shell:inspect'
        return 'bash:other'
    return 'other:' + n

def load():
    return [json.loads(l) for l in open(D + 'lead_calls.jsonl')]

def timeline(rows):
    calls = [r for r in rows if 'name' in r and 'rts' in r]
    calls.sort(key=lambda r: r['ts'])
    from datetime import datetime
    def t(s): return datetime.strptime(s[:23], '%Y-%m-%dT%H:%M:%S.%f').timestamp()
    last_res = None
    out = []
    # latest result time seen so far, evaluated at each call's own timestamp: need results sorted by rts
    res_sorted = sorted(t(r['rts']) for r in calls)
    import bisect
    for r in calls:
        ts, rts = t(r['ts']), t(r['rts'])
        k = bisect.bisect_left(res_sorted, ts)  # results strictly before ts
        prev = res_sorted[k - 1] if k else ts
        r['think'] = max(0.0, ts - prev)
        r['tool'] = max(0.0, rts - ts)
        r['cls'] = classify(r)
        r['t0'] = ts
        out.append(r)
    return out

if __name__ == '__main__':
    rows = load()
    cs = timeline(rows)
    agg = collections.defaultdict(lambda: [0, 0.0, 0.0, 0, 0.0, 0])  # n, think, tool, err, wait, nwait
    for r in cs:
        a = agg[r['cls']]
        a[0] += 1
        if r['think'] > 300:
            a[4] += r['think']; a[5] += 1
        else:
            a[1] += r['think']
        a[2] += r['tool'] if not r.get('bg') else 0
        a[3] += 1 if r.get('err') else 0
    tot = [0, 0, 0, 0, 0, 0]
    print('class'.ljust(26), 'n   err  think_min  tool_min  wait>300s_min(n)')
    for k, v in sorted(agg.items(), key=lambda kv: -(kv[1][1] + kv[1][2])):
        print(k.ljust(26), str(v[0]).rjust(4), str(v[3]).rjust(4), str(round(v[1] / 60, 1)).rjust(9), str(round(v[2] / 60, 1)).rjust(9), str(round(v[4] / 60, 1)).rjust(8), '(%d)' % v[5])
        for i in range(6): tot[i] += v[i]
    print('TOTAL'.ljust(26), tot[0], tot[3], round(tot[1] / 60, 1), round(tot[2] / 60, 1), round(tot[4] / 60, 1), tot[5])
