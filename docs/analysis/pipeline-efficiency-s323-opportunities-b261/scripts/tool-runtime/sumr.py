import re,glob,os
R='/Users/n8/git/graph/docs/reviews/s323/'
for f in sorted(glob.glob(R+'[1-5]-[1-5]-*.md')):
    b=os.path.basename(f)
    t=open(f).read()
    vm=re.search(r'(NEEDS_REWORK|NEEDS REWORK|FAIL\b)',t[:3000])
    if not vm: continue
    # first substantive paragraph after Summary / or findings
    m=re.search(r'##\s*(Summary|Verdict)[^\n]*\n+(.{60,600}?)(\n\n|$)',t,re.S)
    print('##',b,'|',(m.group(2) if m else t[:400]).replace('\n',' ')[:420]); print()
