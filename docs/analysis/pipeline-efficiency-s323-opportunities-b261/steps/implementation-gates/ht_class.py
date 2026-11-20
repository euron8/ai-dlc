#!/usr/bin/env python3 -I
"""Classify head-tree WARN lines (warn_fp.323.tsv) : is the capture's head the plan base (RED-at-base by design), and does git diff head..frozen
touch a code or test path (so the capture could describe a different tree) or only records?  Path class as story_gates.py. Matched = a same-story C/I finding mentioned it (warn_fp.py).
Control: head==frozen would give N=0 and never be emitted (asserted: no line has equal heads)."""
import re,subprocess,collections,glob,os
G='/Users/n8/git/graph'
def cls(p):
    if re.match(r'(docs|_bmad-output|test-results)/',p) or re.search(r'\.(md|txt|log|out)$',p): return 'rec'
    if re.search(r'(^|/)tests?/|(^|/)test_[^/]*$|\.(test|spec)\.|(^|/)conftest\.py$|_test\.py$',p): return 'test'
    return 'code'
plan_base={}
for p in glob.glob(G+'/_bmad-output/implementation-artifacts/s323/gate-transition/*.plan'):
    t=open(p).read(); plan_base[os.path.basename(p)]=(re.search(r'^base: ?(\S+)',t,re.M) or [0,''])[1]
C=collections.Counter(); ex=collections.defaultdict(list); cache={}
for l in open('warn_fp.323.tsv'):
    pl,stem,cl,key,matched,line=l.rstrip('\n').split('\t')
    if cl!='head-tree': continue
    m=re.search(r'head (\w+) differs from (\w+) in (\d+)',line)
    if not m: continue
    h,f,n=m.group(1),m.group(2),int(m.group(3)); assert h!=f
    base=plan_base[pl]
    atbase = base.startswith(h[:7]) or h.startswith(base[:7])
    k=(h,f)
    if k not in cache:
        names=subprocess.run(['git','-C',G,'diff','--name-only',h,f],capture_output=True,text=True).stdout.split('\n')
        names=[x for x in names if x]
        cache[k]=collections.Counter(cls(x) for x in names)
    c=cache[k]
    kind='at-sprint-base' if atbase else ('records-only-delta' if not c['code'] and not c['test'] else ('test-only-delta' if not c['code'] else 'code-delta'))
    C[(kind,matched)]+=1
    if matched=='False' and len(ex[kind])<3: ex[kind].append((pl,key,h,f,dict(c)))
for k in sorted(C): print(k,C[k])
for k,v in ex.items():
    print(k); [print('  ',x) for x in v]
