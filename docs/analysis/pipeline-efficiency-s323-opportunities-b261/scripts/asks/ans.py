import re
def chosen(q, ans):
    qt=(q.get("question") or "")
    i=ans.find(qt[:60])
    if i<0: return None
    m=re.search(r'"\s*=\s*"', ans[i:])
    if not m: return None
    rest=ans[i+m.end():]
    # answer ends at '" ' followed by next question or end; take up to '"' + (' user notes' or end or ', "')
    j=rest.find('"')
    k=rest.find('" user notes:')
    s=rest[:k] if k>=0 and (j<0 or k<=j+1) else (rest[:j] if j>=0 else rest)
    return s.strip()
def kind(q, ans):
    labels=[(o.get("label") or "").strip() for o in (q.get("options") or [])]
    recs=[l for l in labels if "recommend" in l.lower()]
    c=chosen(q,ans)
    if c is None: return "unparsed", None
    if recs: return ("REC" if c in recs else ("other-opt" if c in labels else "free")), c
    return ("norec-first" if c in labels and labels.index(c)==0 else "norec-other" if c in labels else "norec-free"), c
