# Rows 4-8: build the transcript corpus (graph transcripts, records 2026-11-18T00:00..16:10Z; 8725 files, 77713 records).
# Copied verbatim from hand h271-rows-b; <out> is the scratch directory the pickle was written to (not committed).
import glob,re,pickle
base='/Users/n8/.claude/projects/-Users-n8-git-graph'
files=sorted(set(glob.glob(base+'/*.jsonl')+glob.glob(base+'/*/subagents/*.jsonl')+glob.glob(base+'/*/*/*.jsonl')))
recs=[]
for f in files:
    for line in open(f,errors='replace'):
        m=re.search(r'"timestamp":"(2026-11-1[78]T[^"]+)"',line)
        if not m: continue
        ts=m.group(1)
        if ts<'2026-11-18T00:00' or ts>'2026-11-18T16:10': continue
        recs.append((ts,f,line))
pickle.dump(recs,open('<out>/h271b_recs.pkl','wb'))
