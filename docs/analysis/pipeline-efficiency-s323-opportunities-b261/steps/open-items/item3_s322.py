"""item 3, s322: per triage entry, roles with a MAJOR source, sole-role, recommend, and whether a commit in 95d831207..e0ebaf019 names the T-id.
Reads graph committed objects only (git show / git ls-tree / git log). python3 -I item3_s322.py
Controls: 45 major seat headings (the s322 doc/ triage header says 45 major, 112 minor); 26 major entries."""
import subprocess,re,collections
G='/Users/n8/git/graph'
def git(*a): return subprocess.run(['git','-C',G]+list(a),capture_output=True,text=True).stdout
R='39aa9db6f'; IN='95d831207'; SQ='e0ebaf019'
files=[l for l in git('ls-tree','--name-only',R,'_bmad-output/party-mode/s322/').split('\n') if re.search(r'sprint-review-(architect|dev|pm|qa|tea)-(\d+|cross)\.md$',l)]
sev={}
nmaj=nmin=0
for f in files:
    t=git('show',f'{R}:{f}');seat=re.search(r'sprint-review-(\w+-(?:\d+|cross))\.md',f).group(1)
    for m in re.finditer(r'(?m)^## (F-\d+) \((\w+)\)',t):
        sev[(seat,m.group(1))]=m.group(2)
        if m.group(2)=='major': nmaj+=1
        elif m.group(2)=='minor': nmin+=1
print('seat files',len(files),'major',nmaj,'minor',nmin,'(triage header: 45 major, 112 minor)')
tri=git('show',f'{R}:_bmad-output/implementation-artifacts/s322/sprint-review-party-triage.md')
log=git('log','--format=%H%x1f%s%x1f%b%x1e',f'{IN}..{SQ}')
commits=[c for c in log.split('\x1e') if c.strip()]
ents=re.split(r'\n(?=## T-\d+ \()',tri)
out=[]
for e in ents:
    m=re.match(r'## (T-\d+) \((major|minor)\) (.*)',e)
    if not m or m.group(2)!='major': continue
    tid=m.group(1)
    src=re.search(r'^sources: (.*)$',e,re.M).group(1)
    pairs=re.findall(r'(\w+-(?:\d+|cross))::(F-\d+)',src)
    roles_major=collections.Counter();roles_any=collections.Counter()
    for seat,fid in pairs:
        r=seat.split('-')[0];roles_any[r]+=1
        if sev.get((seat,fid))=='major': roles_major[r]+=1
    rec=re.search(r'^recommend: (\S+)',e,re.M).group(1)
    ver=re.search(r'^verdict: (\S+)',e,re.M).group(1)
    named=[c.split('\x1f')[0][:9] for c in commits if re.search(r'\b%s\b'%tid,c)]
    cross=any(s.endswith('cross') for (s,f) in pairs if sev.get((s,f))=='major')
    out.append((tid,sorted(roles_major),sorted(roles_any),rec,ver,named,cross,m.group(3)[:90]))
print('major entries',len(out))
for o in out: print(o)
sole=collections.defaultdict(list)
for o in out:
    if len(o[1])==1: sole[o[1][0]].append(o)
print()
for r in ('architect','dev','pm','qa','tea'):
    print(r,'sole-major entries',[(x[0],x[3],x[4],'commit' if x[5] else 'nocommit','cross' if x[6] else 'per-story') for x in sole[r]])
