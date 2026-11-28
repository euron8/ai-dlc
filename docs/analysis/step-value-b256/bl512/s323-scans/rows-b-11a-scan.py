# Rows 6 and 8: Check 11a absence scans with controls (5-1, 5-3), over the corpus rows-b-corpus.py builds.
# Copied verbatim from hand h271-rows-b; <out> is the scratch directory holding the pickle.
# Recorded output: 5-1 pre-gate 0, POS 226, NEG 0. 5-3 pre-gate 10, POS 110, NEG 0 (all 10 5-3 pre-gate hits are 5-1 gate notes; real 5-3 hits 0).
import pickle,re,os
recs=pickle.load(open('<out>/h271b_recs.pkl','rb'))
NEG='zq9xx-no-such-token-h271b'
def scan(before,after,story_pat,pat=r'[Cc]heck 11a|11a[ :(]',show=0):
    n=0;out=[]
    for ts,f,l in sorted(recs):
        if not(after<=ts<before): continue
        if not re.search(story_pat,l): continue
        for m in re.finditer(pat,l):
            s=l[max(0,m.start()-220):m.end()+260].replace('\\n',' ')
            if re.search(story_pat,s): n+=1; out.append((ts,os.path.basename(f),s))
    for o in out[:show]: print(o)
    return n
for lab,cut,sp in [('5-1','2026-11-18T14:34:33',r'5[-.]1\b|story-5-1'),
                   ('5-3','2026-11-18T15:24:10',r'5[-.]3\b|story-5-3')]:
    print(lab,'pre-gate:',scan(cut,'2026-11-18',sp),
          'POS (cut..16:10):',scan('2026-11-18T16:10',cut,sp),
          'NEG:',sum(1 for r in recs if NEG in r[2]))
