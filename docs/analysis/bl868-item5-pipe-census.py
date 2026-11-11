#!/usr/bin/env python3
"""BL-868 item 5 census: pipes into early-exit readers in fixture shell, classified by writer.
usage: bl868-item5-pipe-census.py <repo> <rev|WORKTREE:dir> [--rows] [--all]
  default population: each fixture's run.sh and depth-1 *.sh; --all adds nested *.sh.
Reads a git rev via cat-file, or a plain directory tree (for the mktemp control) when rev starts WORKTREE:.
"""
import re, subprocess, sys, os, collections

repo, rev = sys.argv[1], sys.argv[2]
ROWS = '--rows' in sys.argv
ALL = '--all' in sys.argv  # include nested *.sh too (default: BL-867 glob run.sh + */*.sh depth 1)

def load():
    files = {}
    if rev.startswith('WORKTREE:'):
        root = rev.split(':', 1)[1]
        for dp, dn, fn in os.walk(os.path.join(root, 'core/fixtures')):
            for f in fn:
                if f.endswith('.sh'):
                    p = os.path.join(dp, f)
                    files[os.path.relpath(p, root)] = open(p, errors='replace').read()
        return files
    names = subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '--name-only', rev, 'core/fixtures'],
                           capture_output=True, text=True, check=True).stdout.split('\n')
    names = [n for n in names if n.endswith('.sh')]
    inp = ''.join(f'{rev}:{n}\n' for n in names)
    out = subprocess.run(['git', '-C', repo, 'cat-file', '--batch'], input=inp.encode(), capture_output=True, check=True).stdout
    i = 0
    for n in names:
        nl = out.index(b'\n', i); hdr = out[i:nl].split(); size = int(hdr[2])
        files[n] = out[nl + 1:nl + 1 + size].decode(errors='replace'); i = nl + 1 + size + 1
    return files

files = load()

def in_scope(p):
    parts = p.split('/')
    if len(parts) < 4: return False
    if parts[2] == 'lib' and not ALL: return False
    return ALL or len(parts) == 4

# --- function definitions per fixture dir (+ shared core/fixtures/lib) ---
FDEF = re.compile(r'^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{?')
def defs_of(text):
    d = {}
    lines = text.split('\n')
    for i, l in enumerate(lines):
        m = FDEF.match(l)
        if not m: continue
        ind = len(l) - len(l.lstrip())
        if l.rstrip().endswith('}') and l.count('{') == l.count('}'):
            d[m.group(1)] = l; continue
        body = [l]
        for j in range(i + 1, min(i + 4000, len(lines))):
            body.append(lines[j])
            s = lines[j]
            if re.match(r'^\s*\}\s*(;.*|#.*|[<>].*)?$', s) and (len(s) - len(s.lstrip())) <= ind:
                break
        d[m.group(1)] = '\n'.join(body)
    return d

fixdefs = collections.defaultdict(dict)
libdefs = {}
for p, t in files.items():
    parts = p.split('/')
    if len(parts) < 4: continue
    ds = defs_of(t)
    if parts[2] == 'lib': libdefs.update(ds)
    else:
        fixdefs[parts[2]].update(ds)

# counted bash start in command position
CMDPOS = r'(?:^|[;&|({!`]|\$\(|\bthen\b|\bdo\b|\belse\b|\btime\b|\bexec\b|\bnohup\b|\bcommand\b)\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*'
START = re.compile(CMDPOS + r'(?:(?:/usr)?/bin/(?:ba)?sh\b|(?:ba)?sh\s|env\s[^|;]*\b(?:ba)?sh\b|"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?(?:/[^"]*)?"(?:\s|$)|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/\S+\.sh\b|\S*/\S+\.sh\b|\./\S+)', re.M)
WORD = re.compile(CMDPOS + r'([A-Za-z_][A-Za-z0-9_]*)\b', re.M)

def strip_comments(t):
    return '\n'.join(l for l in t.split('\n') if not l.lstrip().startswith('#'))

memo = {}
def starts_bash(fx, name, seen=None):
    key = (fx, name)
    if key in memo: return memo[key]
    seen = seen or set()
    if key in seen: return False
    seen.add(key)
    body = fixdefs[fx].get(name, libdefs.get(name))
    if body is None: return False
    b = strip_comments(body.split('\n', 1)[1] if '\n' in body else body)
    r = bool(START.search(b))
    if not r:
        for m in WORD.finditer(b):
            w = m.group(1)
            if w != name and (w in fixdefs[fx] or w in libdefs) and starts_bash(fx, w, seen):
                r = True; break
    memo[key] = r
    return r

READER = re.compile(r'(?<!\|)\|(?!\|)\s*(head\b|grep\s+(?:-[A-Za-z]*\s+|-e\s+\S+\s+)*-[A-Za-z]*[qm]|awk\b[^|]*\bexit\b|sed\s+(?:-n\s+)?[\'"][^\'"]*\bq\b)')

def unquoted_map(line):
    """per index: depth-stack aware 'is this char outside quotes at the current $( level'."""
    out = [False] * len(line)
    st = []  # stack of quote contexts: "'", '"', '$('
    i = 0
    while i < len(line):
        c = line[i]
        top = st[-1] if st else None
        if top == "'":
            if c == "'": st.pop()
            i += 1; continue
        if c == '\\': i += 2; continue
        if top == '"':
            if c == '"': st.pop()
            elif line.startswith('$(', i): st.append('$('); out[i] = out[i+1] = True; i += 2; continue
            i += 1; continue
        # top is None or '$('
        out[i] = True
        if c == "'": st.append("'")
        elif c == '"': st.append('"')
        elif line.startswith('$(', i): st.append('$('); out[i] = out[i+1] = True; i += 2; continue
        elif c == ')' and top == '$(': st.pop()
        i += 1
    return out

def writer_stage(line, pos):
    uq = unquoted_map(line)
    # walk back from pos to the pipeline start: an unquoted ; & ( { ` or $( or keyword, at same nesting
    depth = 0
    j = pos - 1
    start = 0
    while j >= 0:
        c = line[j]
        if uq[j]:
            if c == ')': depth += 1
            elif c == '(':
                if depth == 0: start = j + 1; break
                depth -= 1
            elif depth == 0 and c == '&' and ((j > 0 and line[j-1] in '<>') or (j + 1 < len(line) and line[j+1] == '>')):
                pass
            elif depth == 0 and c == '{' and j > 0 and line[j-1] == '$':
                pass
            elif depth == 0 and c in ';&{`\n':
                start = j + 1; break
        j -= 1
    seg = line[start:pos]
    # split seg on unquoted single pipes
    uqs = uq[start:pos]
    parts, cur = [], ''
    k = 0
    while k < len(seg):
        if uqs[k] and seg[k] == '|' and not (k + 1 < len(seg) and seg[k + 1] == '|') and not (k > 0 and seg[k - 1] == '|'):
            parts.append(cur); cur = ''
        else:
            cur += seg[k]
        k += 1
    parts.append(cur)
    prod = re.sub(r'^\s*(?:(?:if|then|do|while|until|else|elif|!)\s+)*', '', parts[0]).strip()
    return prod, parts[1:]

def classify(fx, prod, mids):
    toks = prod.split()
    while toks and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', toks[0]): toks = toks[1:]
    while toks and toks[0] in ('env', 'command', 'time', 'exec', 'nohup', '!'): toks = toks[1:]
    if not toks: return 'OTHER', ''
    w = toks[0]
    if re.match(r'^(/usr)?(/bin/)?(ba)?sh$', w) or re.match(r'^["]?\$', w) or w.endswith('.sh') or w.startswith('./'):
        return 'DIRECT', w
    if w in fixdefs[fx] or w in libdefs:
        return ('FUNC-START' if starts_bash(fx, w) else 'FUNC-NOSTART'), w
    return 'OTHER', w

rows = []
for p in sorted(files):
    if not in_scope(p): continue
    fx = p.split('/')[2]
    lines = files[p].split('\n')
    i = 0
    while i < len(lines):
        ln = i + 1
        line = lines[i]
        offs = [(0, ln)]
        while line.endswith('\\') and i + 1 < len(lines):
            i += 1; line = line[:-1] + ' '; offs.append((len(line), i + 1)); line += lines[i].lstrip()
        i += 1
        if line.lstrip().startswith('#'): continue
        uq = unquoted_map(line)
        for m in READER.finditer(line):
            if not uq[m.start()]: continue
            prod, mids = writer_stage(line, m.start())
            rank={'DIRECT':3,'FUNC-START':2,'FUNC-NOSTART':1,'OTHER':0}
            best=('OTHER','')
            for st in [prod]+[x.strip() for x in mids]:
                r=classify(fx, st, [])
                if rank[r[0]]>rank[best[0]]: best=r
            if best[0]=='OTHER': best=('OTHER', classify(fx, prod, [])[1])
            cls, w = best
            pl = [l2 for (o2, l2) in offs if o2 <= m.start()][-1]
            rows.append((cls, p, pl, w, m.group(1).split()[0]))

c = collections.Counter(r[0] for r in rows)
fxs = collections.defaultdict(set)
for r in rows: fxs[r[0]].add(r[1].split('/')[2])
print(f'rev={rev} files_scanned={sum(1 for p in files if in_scope(p))} total={len(rows)}')
for k in ('DIRECT', 'FUNC-START', 'FUNC-NOSTART', 'OTHER'):
    print(f'  {k:13s} {c.get(k,0):5d} sites in {len(fxs[k])} fixtures')
if ROWS:
    for r in rows:
        if True:
            print('\t'.join(map(str, r)))
