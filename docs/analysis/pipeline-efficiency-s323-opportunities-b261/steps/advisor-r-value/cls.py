
import json,os
P='/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value/cls.json'
def rec(rows):
    d=json.load(open(P)) if os.path.exists(P) else {}
    for r in rows: d[str(r[0])]=dict(cls=r[1],err=r[2],ev=r[3])
    json.dump(d,open(P,'w'))
    print('recorded',len(d))
