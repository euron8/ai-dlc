import re
G='/Users/n8/git/graph/_bmad-output/implementation-artifacts/'
for f,pat in [(G+'s317/gate-log-archive.md',r'(stray hyphen|lapsed|tool_use_id|re-?dispatch|abandon|Gate Reset|minted)'),(G+'gate-log.md',r'(lapsed|tool_use_id|abandon|minted|Gate Reset)')]:
    lines=open(f,errors='replace').read().split('\n')
    print('=====',f.split('/')[-2:])
    cur=''
    for i,l in enumerate(lines):
        if l.startswith('## '): cur=l[:90]
        if re.search(pat,l,re.I): print('L%d [%s] %s'%(i,cur[3:60],l[:330]))
