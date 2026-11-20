"""classify asks317.jsonl: candidate push/merge/roll/fire asks + answer kind. usage: python3 -I pm.py asks317.jsonl [all]"""
import json, re, sys
def chosen(q, ans):
    qt = q.get("question") or ""; i = ans.find(qt[:80])
    if i < 0: return None
    m = re.search(r'"\s*=\s*"', ans[i:])
    if not m: return None
    rest = ans[i + m.end():]
    return (rest[:rest.find('"')] if '"' in rest else rest).strip()
def kind(q, ch):
    labels = [(o.get("label") or "").strip() for o in (q.get("options") or [])]
    recs = [l for l in labels if "recommend" in l.lower()]
    if ch is None: return "unparsed"
    if recs: return "rec" if ch in recs else ("other" if ch in labels else "free")
    if ch in labels: return "u-first" if labels.index(ch)==0 else "u-other"
    return "u-free"
PAT = re.compile(r"\b(push|merge|merging|pr\b|pull request|fire|roll|deploy|cdk|ship)", re.I)
rows = [json.loads(l) for l in open(sys.argv[1])]
n=0
for o in rows:
    for qi, q in enumerate(o["qs"]):
        txt = (q.get("header","")+" "+q.get("question","")+" "+" ".join(x.get("label","") for x in q.get("options",[])))
        if len(sys.argv)<3 and not PAT.search(txt): continue
        ch = chosen(q, o["ans"]); k = kind(q, ch)
        n+=1
        print(f"{o['sprint']}|{o['start'][5:16]}|{o['step'][:12]}|{o['wait']/60:.1f}m|err={int(o['err'])}|q{qi+1}/{len(o['qs'])}|{q.get('header','')[:24]}|{k}|opts={[x.get('label','')[:30] for x in q.get('options',[])]}|ch={ (ch or '')[:70]!r}")
print(n)
