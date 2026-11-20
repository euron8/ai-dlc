
import json,re,sys
D=json.load(open('/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/advisor-r-value/dossiers.json'))
def show(i,adv=650):
    d=D[i]
    print('### %d %s#%d adv_ln%d %s s=%.0f %s'%(i,d['sess'][:4],d['n'],d['adv_ln'],d['cts'][5:16],d['secs'] or -1,'' if d['before_first_ok'] else 'LATE'))
    pre=d['pre']
    says=[l for l in pre if l.startswith('SAY')]
    for l in says[-1:]: print(' ',l[:260])
    th=[l for l in pre if l.startswith('THINK')]
    for l in th[-1:]: print(' ',l[:520])
    print(' PRE tools(%d):'%len(pre),' | '.join(l[:55] for l in pre if not l.startswith('SAY'))[-220:])
    a=re.sub(r'advisor-mcp consulted \(model fable, session transcript\) \| ','',d['advice'] or '')
    print(' ADV:',a[:adv].replace('\n',' '))
    print(' POST:')
    for l in d['post'][:10]: print('  ',l[:105])
