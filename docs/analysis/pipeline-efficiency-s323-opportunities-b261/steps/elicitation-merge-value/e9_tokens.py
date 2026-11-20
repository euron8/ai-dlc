import glob,os,re,sys
PA="/Users/n8/git/graph/_bmad-output/planning-artifacts/s323/"; PM="/Users/n8/git/graph/_bmad-output/party-mode/s323/"
def cat(step,pm,keys):
    d={}
    d['party']=glob.glob(PM+f"{pm}-*.md")
    d['elic']=[f for k in keys for f in glob.glob(PA+f"shards/{k}-elicitation/*.md")]
    for p in ('p1','p2','p3'): d[p]=[f for k in keys for f in glob.glob(PA+f"shards/{k}-{p}/*.md")]
    return d
CAT={"req":cat("req","requirements",["requirements"]),"arch":cat("arch","architecture",["ARCHITECTURE-SPINE"]),"coe":cat("coe","carry-over-evaluation",["coe"]),"st":cat("st","stories",["stories"])}
T=[("req","a :17919 ceiling",":17919"),("req","b sentinel temp .env","temp `.env`"),("req","c Clientcert strip","strip"),("req","c2 Mtls-Clientcert","Mtls-Clientcert"),
("arch","d HEAD signs w/o gasPrice","signs without `gasPrice`"),("arch","e :24380",":24380"),("arch","e2 GasPriceRefusal catch Leg1/Leg2","GasPriceRefusal"),
("st","f :17919 RuntimeError",":17919"),("st","g :13499",":13499"),("st","h :15453",":15453"),("st","i _batch_positions","_batch_positions"),("st","j BIGINT","BIGINT"),
("coe","k no transaction is signed","no transaction is signed"),("coe","l native Leg 1","native leg"),("coe","m Playwright mTLS","Playwright mTLS")]
txt={}
def T_(f):
    if f not in txt: txt[f]=open(f).read()
    return txt[f]
for st,name,tok in T:
    row=[]
    for c,fs in CAT[st].items():
        n=sum(1 for f in fs if tok in T_(f))
        row.append(f"{c}:{n}/{len(fs)}")
    print(st,name,'|',' '.join(row))
print("control absent:", sum(1 for fs in CAT['req'].values() for f in fs if 'QZXV-NO-SUCH-TOKEN-90417' in T_(f)))
