import sys; sys.path.insert(0,'.')
from lib import *
import datetime
for sess,a,b in [('53b4296a','2026-11-19T02:53:10Z','2026-11-19T07:45:51Z'),('64926214','2026-11-19T12:48:45Z','2026-11-20T04:17:36Z')]:
    cs=sorted(calls(lead_path(sess)),key=lambda d:d['t0'])
    for d in cs:
        if not(T(a)<=d['t0']<T(b)): continue
        if d['name'] in('Agent','AskUserQuestion','Skill') :
            i=d['inp']
            print(d['ts'][5:19],d['name'],(i.get('subagent_type') or ''),(i.get('description') or str(i.get('questions'))[:100])[:90],'%.0fs'%(d['t1']-d['t0']),'bg' if i.get('run_in_background') else '')
