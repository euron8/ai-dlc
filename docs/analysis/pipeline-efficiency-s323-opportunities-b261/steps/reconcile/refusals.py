"""A1: every tool_result containing 'admission: REFUSED' in files listed in refused_files.txt (grep -rl over the corpus).
Writes refusals.jsonl: one row per result block: file, agent, kind(lead/sub), ts, tool, n_lines, n_pred, cmd, tid, role."""
import json,os,re,collections
R=os.path.dirname(os.path.abspath(__file__))+'/'
M=R+'../../MONO/spawns.jsonl'
role={}
for l in open(M):
    r=json.loads(l); role[r['unit']]=(r['role'],r['sprint'],r['description'])
WS,WE='2026-11-13T08:00:00Z','2026-11-20T04:20:00Z'
out=open(R+'refusals.jsonl','w')
for f in [l.strip() for l in open(R+'refused_files.txt')]:
    kind='sub' if '/subagents/' in f else 'lead'
    ag=os.path.basename(f)[:-6]
    uses={}; lastts='?'
    for l in open(f,errors='replace'):
        if '"tool_use"' in l and 'admission' not in l or True:
            pass
        try: r=json.loads(l)
        except: continue
        lastts=r.get('timestamp') or lastts
        m=r.get('message') if isinstance(r.get('message'),dict) else {}
        c=m.get('content')
        if not isinstance(c,list): continue
        for b in c:
            if not isinstance(b,dict): continue
            if b.get('type')=='tool_use':
                uses[b['id']]=(b.get('name'),str((b.get('input') or {}).get('command') or (b.get('input') or {}))[:300])
            elif b.get('type')=='tool_result':
                t=b.get('content'); t=' '.join(x.get('text','') for x in t if isinstance(x,dict)) if isinstance(t,list) else str(t)
                if 'admission: REFUSED' in t or 'GiB: REFUSED' in t:
                    nm,cmd=uses.get(b['tool_use_id'],('?',''))
                    out.write(json.dumps(dict(f=f,ag=ag,kind=kind,ts=lastts,tool=nm,nl=t.count('admission: REFUSED'),npr=t.count('GiB: REFUSED'),npred=t.count('predicate:'),cmd=cmd,tid=b['tool_use_id'],role=role.get(ag,('?',))[0],err=bool(b.get('is_error')),dlen=len(t)))+'\n')
