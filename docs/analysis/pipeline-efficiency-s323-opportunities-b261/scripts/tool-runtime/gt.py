import json,re,collections,sys
sys.path.insert(0,'/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/h10')
from lead import run,P,T
rows=run(P+'53b4296a-8c03-4e97-8dc8-43106688cb6e.jsonl',T('2026-11-18T12:45:29Z'),T('2026-11-19T03:09:29Z'))
c=collections.Counter(); t=collections.defaultdict(float); ex={}
for f,th,tl,n,i,e in rows:
    if f!='Bash:gate-transition': continue
    cmd=i['command']
    m=re.search(r'gate-transition\.sh\s+(?:(--\S+)\s+)?(\S+)\s*(\S*)',cmd)
    if not m: k='unparsed'
    else: k=(m.group(1) or '')+' '+(m.group(3) if re.match(r'[123]$|open|close|check|plan|record',m.group(3) or '') else '')
    k=re.sub(r'\s+',' ',k).strip() or 'other'
    c[k]+=1; t[k]+=tl; ex.setdefault(k,re.sub(r'\s+',' ',cmd)[:170])
for k,v in c.most_common(10): print(v,f"{t[k]/v:.1f}s avg {t[k]/60:.1f}min total |",k,'|',ex[k])
print('total gate-transition lead tool min',sum(t.values())/60,'calls',sum(c.values()))
