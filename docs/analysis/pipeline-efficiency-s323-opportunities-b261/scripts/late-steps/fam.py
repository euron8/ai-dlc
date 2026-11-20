import json, re, collections, sys, bisect, datetime as dt
D = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/hand-s323late/out/'
M = '/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/MONO/'
def T(s): return dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()

SKIP = re.compile(r'^(cd|echo|export|set|true|false|:|printf|test|\[|\[\[|unset|source|\.|local|pushd|popd|mkdir|rm|touch|date|read|exit|trap|wait)$')
def family(cmd):
    c = cmd.strip()
    c = re.sub(r'<<-?\s*[\'"]?(\w+)[\'"]?.*?(\n\1\b|$)', ' ', c, flags=re.S) if '<<' in c else c
    segs = re.split(r'&&|\|\||;|\n|\|', c)
    for s in segs:
        s = s.strip()
        s = re.sub(r'^(\w+=\S*\s+)+', '', s)         # VAR=x prefix
        s = re.sub(r'^(env|time|timeout \d+|nohup|command|exec)\s+', '', s)
        s = re.sub(r'^(\w+=("[^"]*"|\S*)\s*)+', '', s)
        if not s: continue
        w = s.split()
        if not w: continue
        prog = re.sub(r'^.*/', '', w[0].strip('"\'`($'))
        if prog.startswith('$') or prog == '': prog = 'var-cmd'
        if SKIP.match(prog): continue
        if prog == 'git':
            sub = next((x for x in w[1:] if not x.startswith('-') and '=' not in x), '?')
            if w[1:2] == ['-C']: sub = next((x for x in w[3:] if not x.startswith('-')), '?')
            return 'git ' + sub
        if prog == 'gh':
            return 'gh ' + ' '.join(x for x in w[1:3] if not x.startswith('-'))
        if prog in ('python', 'python3', 'uv', 'pytest', 'py.test') or re.match(r'python', prog):
            if 'pytest' in s: return 'pytest'
            m = re.search(r'-m\s+(\w+)', s)
            if m: return 'python -m ' + m.group(1)
            if re.search(r'\bpython3?\s+-\s*$|\bpython3?\s+-c', s) or '<<' in s: return 'python inline'
            m = re.search(r'(\S+\.py)', s)
            return 'python ' + (re.sub(r'^.*/', '', m.group(1)) if m else '?')
        if prog in ('bash', 'sh', 'zsh'):
            m = re.search(r'(\S+\.sh)', s)
            return re.sub(r'^.*/', '', m.group(1)) if m else 'bash inline'
        if prog.endswith('.sh'): return prog
        if prog in ('npm', 'npx', 'pnpm', 'yarn', 'docker', 'aws', 'cargo', 'make', 'ruff', 'mypy', 'pyright', 'black', 'flake8'):
            return prog + ' ' + ' '.join(x for x in w[1:3] if not x.startswith('-'))[:20]
        if prog in ('sleep', 'until', 'while', 'for', 'if'): return 'sleep/loop' if prog != 'if' else 'if'
        return prog[:30]
    return 'misc'

def load():
    rows = [json.loads(l) for l in open(D + 'bash.jsonl')]
    for r in rows: r['fam'] = family(r['cmd'])
    return rows

if __name__ == '__main__':
    TOP = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    rows = load()
    # control: paired lead Bash count vs tools.csv
    for sp in (321, 322, 323):
        for kind in ('lead', 'sub'):
            sel = [r for r in rows if r['sprint'] == sp and r['kind'] == kind]
            ok = [r for r in sel if not r['err']]
            print(f's{sp} {kind}: paired Bash {len(sel)} ok {len(ok)} err {len(sel)-len(ok)} wall ok {sum(r["lat"] for r in ok)/3600:.2f} h  err {sum(r["lat"] for r in sel if r["err"])/3600:.2f} h')
