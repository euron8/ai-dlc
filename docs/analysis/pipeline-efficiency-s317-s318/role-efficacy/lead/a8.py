import re, glob, collections
G='/Users/n8/git/graph/_bmad-output/'
gl=[G+'implementation-artifacts/s317/gate-log-archive.md']+glob.glob(G+'implementation-artifacts/gate-log*.md')
print(gl)
rx=re.compile(r'(abandon|discard|superseded|void|re-?dispatch|lapsed|stray|hyphen|tool_use_id|stale|restart|re-?run|invalid)',re.I)
for f in gl:
    lines=open(f,errors='replace').read().split('\n')
    hdr=[l for l in lines if l.startswith('## ')]
    print('==',f.split('/')[-1],'lines',len(lines),'headers',len(hdr))
    c=collections.Counter()
    for i,l in enumerate(lines):
        for m in rx.finditer(l): c[m.group(1).lower()]+=1
    print(c)
    shown=0
    for i,l in enumerate(lines):
        if re.search(r'(abandon|discard|superseded|lapsed|stray hyphen|without tool_use_id|void)',l,re.I) and shown<30:
            print('  L%d'%i,l[:260]); shown+=1
