import subprocess,re,difflib,sys
sys.path.insert(0,'.')
G="/Users/n8/git/graph";P="_bmad-output/planning-artifacts/s323/stories"
exec(open("/private/tmp/claude-501/-Users-n8-git-ai-dlc/b2fb5d2f-285d-43b0-bb35-73998d6c5019/scratchpad/steps/stories-test-strategy/s5_survival.py").read().split("tot=")[0].replace("C0,C1,CF=sys.argv[1],sys.argv[2],sys.argv[3]","C0,C1,CF='45bed5dc6','ae63caf38','a9b015557'"))
for f in files:
    p=f"{P}/{f}"; a0=acs(show(C0,p)); af=acs(show(CF,p))
    # find first commit changing each AC after C1
    for k in a0:
        if k in af and norm(af[k])!=norm(a0[k]):
            sm=difflib.SequenceMatcher(None,norm(a0[k]),norm(af[k]),autojunk=False)
            ops=[o for o in sm.get_opcodes() if o[0]!='equal']
            ins=' || '.join(norm(af[k])[o[3]:o[4]][:170] for o in ops[:2])
            dele=' || '.join(norm(a0[k])[o[1]:o[2]][:90] for o in ops[:2] if o[2]>o[1])
            print(f[:14],k,'ops',len(ops),'+',ins,'| -',dele)
