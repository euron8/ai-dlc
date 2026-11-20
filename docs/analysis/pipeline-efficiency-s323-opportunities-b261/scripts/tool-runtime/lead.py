import json,re,collections,sys
from datetime import datetime
def T(s): return datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
P='/Users/n8/.claude/projects/-Users-n8-git-graph/'
def fam(n,i):
    if n!='Bash': return n.replace('mcp__plugin_context-mode_context-mode__','ctx_')
    c=i.get('command','')
    pats=[('gate-transition',r'gate-transition'),('merge-review-shards',r'merge-review-shards'),('snapshot-update',r'snapshot-update|rotate-snapshot'),
      ('validate-*',r'validate-|check-owed|audit-'),('git merge/rebase/cherry',r'\bgit\b[^|;&]*\b(merge|rebase|cherry-pick)\b'),('git push',r'\bgit\b[^|;&]*\bpush\b'),
      ('git commit/add',r'\bgit\b[^|;&]*\b(commit|add)\b'),('git worktree',r'\bgit\b[^|;&]*\bworktree\b'),('git other',r'\bgit\b'),
      ('wait-for-deliverable',r'wait-for-deliverable'),('sleep',r'\bsleep\b'),('pytest/tests',r'pytest|vitest|ci-local'),
      ('gate-slice/plan/ledger',r'gate-slice|gate-checkpoint|sprint-status|spawn-ledger|partition-'),('read/grep',r'\b(cat|sed|head|tail|grep|ls|wc|awk|jq|find)\b')]
    for k,p in pats:
        if re.search(p,c): return 'Bash:'+k
    return 'Bash:other'
def run(path,t_a,t_b):
    prev=None; uses={}; rows=[]
    for l in open(path):
        try: r=json.loads(l)
        except Exception: continue
        ts=r.get('timestamp')
        if not ts: continue
        t=T(ts)
        c=(r.get('message') or {}).get('content')
        if isinstance(c,list):
            for b in c:
                if b.get('type')=='tool_use': uses[b['id']]=(t,b['name'],b['input'],t-(prev if prev else t))
                elif b.get('type')=='tool_result' and b.get('tool_use_id') in uses:
                    t0,n,i,think=uses.pop(b['tool_use_id'])
                    if t_a<=t0<=t_b: rows.append((fam(n,i),think,t-t0,n,i,bool(b.get('is_error'))))
        prev=t
    return rows
if __name__=='__main__':
    ses=[('53b4296a-8c03-4e97-8dc8-43106688cb6e',T('2026-11-18T12:45:29Z'),T('2026-11-19T03:09:29Z'))]
    rows=[]
    for s,a,b in ses: rows+=run(P+s+'.jsonl',a,b)
    print('lead tool calls in window',len(rows))
    agg=collections.defaultdict(lambda:[0,0.0,0.0])
    for f,th,tl,n,i,e in rows:
        # cap think at 300 to mirror 'active'
        a=agg[f]; a[0]+=1; a[1]+=min(th,300); a[2]+=min(tl,300)
    tot=sum(v[1]+v[2] for v in agg.values())
    print('active-equivalent h',tot/3600)
    for k,v in sorted(agg.items(),key=lambda kv:-(kv[1][1]+kv[1][2]))[:22]:
        print(f"{k:28s} n={v[0]:5d} model {v[1]/3600:5.2f}h tool {v[2]/3600:5.2f}h per-call {(v[1]+v[2])/v[0]:5.1f}s")
