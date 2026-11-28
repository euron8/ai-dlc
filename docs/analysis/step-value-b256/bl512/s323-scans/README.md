# Scan code behind `s323-catches.md`

Read-only scans of graph at the refs named, and of graph's session transcripts. Python is committed as `.py`
files beside this one; the shell scans are below as text, not as tracked scripts. The transcript scans read
the operator's local Claude projects directory for graph, so they run only on the operator's machine.

## Files

- `scan.py` (rows 1-3, hand h271-rows-a). Usage: `python3 -I scan.py <cutoff_iso> <regex> [ctxregex]`. It
  reads `files.txt` beside it, one graph transcript path per line (machine-specific, not committed; its
  builder is below), and prints `ts|file|kind|snippet` per hit and `TOTAL n` on stderr. The exact row 1-3
  commands are below.
- `rows-b-corpus.py` and `rows-b-11a-scan.py` (rows 6 and 8, hand h271-rows-b). The first pickles the
  transcript records of 2026-11-18T00:00Z to 16:10Z; the second runs the Check 11a scans over it. `<out>` is
  the scratch directory; the pickle is not committed.
- `scan-transcript-gatestatus-5-4.py` (row 9) and `scan-transcript-carried-5-5.py` (row 11), hand
  h271-rows-c. Both were re-run once in batch 271 cluster H; their output is in each file's header. The
  carried scan gained its negative token for that run.

## Rows 1-3: exact commands (hand h271-rows-a)

Run from `<out>`, the directory holding `scan.py` and `files.txt`. `files.txt` was built by:

```python
import os,glob,time
R='/Users/n8/.claude/projects/-Users-n8-git-graph/'
files=glob.glob(R+'**/*.jsonl',recursive=True)
sel=[f for f in files if '2026-11-17'<=time.strftime('%Y-%m-%d',time.gmtime(os.path.getmtime(f)))<='2026-11-22']
open('<out>'+'/files.txt','w').write('\n'.join(sel))
```

(8725 jsonl files in total, 1245 selected.) `scan.py <cutoff> <regex> [context-regex]` keeps records with a
timestamp before the cutoff; per text, tool_use or tool_result block it takes the first regex match, counted
only when the 250-character window either side matches the context regex; it prints `TOTAL n` on stderr.

Row 1 (planning-20261118T025210Z):

```bash
python3 -I scan.py 2026-11-18T03:01:01Z 'LEG2-PREBOUNDARY' '(\*\*Status|OPEN|vocabular|out-of-set|HARD_BLOCK)' > r1.txt 2>&1   # TOTAL 84
# the three excluded agents are the gate's adjudicators
grep -v -E 'agent-a91445e5|agent-ac1c8a07|agent-ab5427f9' r1.txt | grep -i -E 'vocabular|no \*\*Status|Status line|out-of|missing .{0,10}status' | cut -c1-700 | head -12
# T1c: python over r1.txt, records 02:00 <= ts < 02:53 on 2026-11-18, printing context around LEG2-PREBOUNDARY: 18 lines
cd /Users/n8/git/graph; R=a9b015557; GA=_bmad-output/implementation-artifacts/s323/gate-adjudication
git grep -n -E 'LEG2-PREBOUNDARY.{0,200}(vocabular|no \*\*Status|out-of)' $R -- . ":(exclude)$GA" | cut -c1-200 | head
echo pos; git grep -c -E 'LEG2-PREBOUNDARY.{0,200}(vocabular|no \*\*Status|out-of)|carries the token OPEN outside the closed vocabulary' $R -- "$GA/planning-20261118T025210Z.verdict.json"
echo neg; git grep -c 'zq9xx-no-such-token-h271' $R -- . ; echo rc=$?
git log --all --format='%h %cI %s' --since=2026-11-18T02:50Z --until=2026-11-18T03:22Z -- docs/escalations/pending.md | head -5   # dec6dd62b
```

Row 2 (sprint-review-20261119T193613Z):

```bash
python3 -I scan.py 2026-11-19T19:49:21Z 'step3-qa-validation' '(APPROVED|NEEDS_REWORK|verdict set|not in .{0,30}set|qa\.md)' > r2.txt 2>&1   # TOTAL 17
# one call; printed 2, 1, TOTAL 0
bash -c 'python3 -I scan.py 2026-11-19T19:49:21Z "step3-qa-validation" "(APPROVED|NEEDS_REWORK|verdict set|not in .{0,30}set|qa\.md)" 2>&1 | grep -v -E "agent-(ae1071e6|abeda6ea|a67c909b|adadffc7)" | grep -c -i -E "not in|isn.t in|outside|vocabular"; python3 -I scan.py 2026-11-19T19:49:21Z "step3-qa-validation" "(APPROVED|NEEDS_REWORK|verdict set|not in .{0,30}set|qa\.md)" 2>&1 | grep -c "agent-ae1071e6.*isn.t in"; python3 -I scan.py 2026-11-19T19:49:21Z "zq9xx-no-such-token-h271" 2>&1 | tail -1'
# T2c: the first pipeline above with `| cut -c1-60` in place of grep -c: the two hits are at 19:41:46 and 19:47:49, in the lead's main file
git grep -n -i -E "APPROVED.{0,80}(not in|outside).{0,40}(qa|set)|qa\.md.{0,40}(PASS \| NEEDS_REWORK)" $R -- docs/reviews/s323 _bmad-output/implementation-artifacts/s323 ":(exclude)$GA" | cut -c1-220 | head
echo pos; git grep -c -E "isn.t in|not in qa\.md|not in .{0,20}qa\.md" $R -- "$GA/sprint-review-20261119T193613Z.verdict.json"
```

Row 3 (implementation-20261119T015536Z, story 3-2):

```bash
python3 -I scan.py 2026-11-19T02:08:45Z 'dev-escalated|escalate_model' '(3[.-]2|a8b075e670fcd22ad|toolu_1795033671342).{0,200}(plain|rout|sonnet|not .{0,20}escalat)|(plain|rout|sonnet).{0,200}(3[.-]2)' 2>/dev/null | awk '$1>="2026-11-18T20:27"' | cut -c1-900 > r3c.txt   # 22 lines
python3 -I scan.py 2026-11-19T02:08:45Z 'escalate_model: true|dev-escalated' '(3[.-]2|a8b075e670fcd22ad).{0,300}(plain .?dev|not .{0,15}escalat|should .{0,30}escalat|rout)' 2>&1 | awk '{print $1,$2,$4}' | sort | uniq -c | sort -k2 | tail -12   # TOTAL 21
python3 -I scan.py 2026-11-19T02:08:45Z 'zq9xx-no-such-token-h271' 2>&1 | tail -1   # TOTAL 0
cd /Users/n8/git/graph; R=a9b015557
git grep -n -i -E 'dev-escalated|escalate_model|plain .?dev|sonnet' $R -- 'docs/reviews/s323/3-2-*' '_bmad-output/implementation-artifacts/s323/gate-transition/3-2-*' '_bmad-output/implementation-artifacts/s323/dev-report-3-2.md' | cut -c1-220   # 0 lines
git grep -c 'handled by a plain' $R -- '_bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261119T015536Z.verdict.json'   # 1
git grep -c 'zq9xx-no-such-token-h271' $R -- 'docs/reviews/s323/3-2-*' '_bmad-output/implementation-artifacts/s323/gate-transition/3-2-*' ; echo "neg rc=$?"   # rc=1
git grep -c 'zq9xx-no-such-token-h271' $R | wc -l   # 0
git ls-tree -r --name-only $R -- docs/reviews/s323/ _bmad-output/implementation-artifacts/s323/gate-transition/ | grep -c '3-2-'   # 43
git -C /Users/n8/git/graph show "5fe4b5ce7:_bmad-output/planning-artifacts/s323/stories/story-3-2-smoke-browser-tests-both-routes.md" | grep -n '^escalate_model'   # 19:escalate_model: true
```

In the lead transcript 53b4296a up to 2026-11-19T02:09Z, toolu_1795053436956_0 is afe90b1d5e37548c3 (the 3-2
gate adjudicator) and toolu_1795033671342_0 is a8b075e670fcd22ad, whose result carries no warn, escalat, route
or guard text. Two further row 3 scans (T3a, T3b) were exploratory; no verdict rests on them.

Counts derived in batch 271 cluster H, one invocation from `<out>`, replacing figures first read off listings:

```bash
grep -c 'agent-a91445e5' r1.txt                                              # 8: row 1 positive control
grep -c afe90b1d r3c.txt                                                     # 4: row 3 positive control
grep -c 'toolu_1795033671342_0 | dev |' r3c.txt                              # 14: row 3 ledger listings (22:24Z to 02:02Z)
python3 -I scan.py 2026-11-18T03:01:01Z 'zq9xx-no-such-token-h271' 2>&1 | tail -1   # TOTAL 0: row 1's own negative control
```

## Check 11a grammar, used for every Check 11a row (6, 8, 10, 12, 13)

Rows 6 and 8 were first read with the narrower grammar in the next section, which found no record. The owner
re-ran the wider rows 9-13 grammar over the same review files at the same shas:

```bash
git show <sha>:<file> | grep -n -i -E 'live[- ]run|-m live|AGGREGATOR_URL|11a|deploy-pending|live attempt|no live'
```

Hits: graph a0a7dd4b0 docs/reviews/s323/5-1-code-review.md 2, 5-1-qa-validation.md 8; graph 14cad80ba
docs/reviews/s323/5-3-code-review.md 2, 5-3-qa-validation.md 10. Negative token `zq9xx-no-such-token-h271`
over all of graph a9b015557: 0. The QA records (5-1 lines 70-71 and 139; 5-3 lines 62 and 91) make rows 6
and 8 recorded elsewhere.

## Rows 4-8: review-file grep with controls (hand h271-rows-b)

```bash
cd /Users/n8/git/graph
N=zq9xx-no-such-token-h271b
for f in "a0a7dd4b0:docs/reviews/s323/5-1-code-review.md" "a0a7dd4b0:docs/reviews/s323/5-1-qa-validation.md" "14cad80ba:docs/reviews/s323/5-3-code-review.md" "14cad80ba:docs/reviews/s323/5-3-qa-validation.md"; do
  b="$(git show "$f")"
  dar="$(grep -n -i 'Dev Agent Record' <<<"$b" | cut -c1-220)"
  e="$(grep -c -i -E '11a|live-run (record|attempt)|attempt (is|was) not recorded|no (command|envvar)' <<<"$b")" || e=0
  ng="$(grep -c "$N" <<<"$b")" || ng=0
  echo "== $f  11a/attempt-gap hits=$e neg=$ng"; echo "$dar"
done
g="$(git show a9b015557:_bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261118T152410Z.verdict.json)"
echo "POS 5-3: $(grep -o 'Dev Agent Record' <<<"$g" | wc -l)"
g="$(git show a9b015557:_bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261118T143433Z.verdict.json)"
echo "POS 5-1: $(grep -o 'Dev Agent Record' <<<"$g" | wc -l)"
```

Recorded output (hits/neg): 5-1 code review 0/0, 5-1 QA 1/0 (line 56 "Production Integrity", not an 11a
finding), 5-3 code review 0/0, 5-3 QA 0/0. POS 5-3 = 5, POS 5-1 = 5.

Row 4 presence scan: transcript records before 2026-11-18T14:05:35Z carrying `4-3-qa-validation-p2` and
`untracked|\?\? docs/reviews`: 14 hits (lead, 13:40:38Z and 14:04:49Z).

Presence quotes for rows 5 and 7:

```bash
git show a0a7dd4b0:docs/reviews/s323/5-1-code-review.md | sed -n 48,49p
git show a0a7dd4b0:docs/reviews/s323/5-1-qa-validation.md | sed -n 97,98p
git show 14cad80ba:docs/reviews/s323/5-3-qa-validation.md | sed -n 156p
git show --stat 7fb1f0148
git diff --stat a0a7dd4b0 da15cf312
git log --oneline --stat 14cad80ba..dev/sprint-323/story-5-3
```

Verdict extraction: `json.loads` of `git show a9b015557:_bmad-output/implementation-artifacts/s323/gate-adjudication/implementation-20261118T<n>Z.verdict.json`,
printing `verdicts[]` with `check_id` in {1, 11, 11a}, for n in 140535, 141133, 143433, 144911, 152410, 154911.

## Rows 9-13: review files, verdicts and fixes (hand h271-rows-c)

Which review and capture files name the live-run gap (rows 10, 12, 13). Recorded: hits in the QA files for
each story (5-4-qa-validation.md lines 230-231; 5-5-qa-validation.md line 244, -p2.md line 253, -p3.md
line 41; 5-2-qa-validation-p2.md line 230); negative control 0 files for each story.

```bash
#!/bin/bash
cd /Users/n8/git/graph || exit 2
R=a9b015557
NEG=zq9xx-no-such-token-h271
for s in 5-4 5-5 5-2; do
 echo "=== $s live-run terms in reviews/captures/shards"
 git grep -n -i -E 'live[- ]run|-m live|AGGREGATOR_URL|11a|deploy-pending|live attempt|no live' "$R" -- "docs/reviews/s323/${s}-*" "docs/reviews/s323/shards/${s}-*" "_bmad-output/implementation-artifacts/s323/gate-transition/${s}-*" | cut -c1-330 | head -25
 echo "neg: $(git grep -c "$NEG" "$R" -- "docs/reviews/s323/${s}-*" "_bmad-output/implementation-artifacts/s323/gate-transition/${s}-*" | wc -l)"
done
```

FAIL checks per nonce, successor verdicts, and the fix diffs (rows 9-13):

```bash
#!/bin/bash
cd /Users/n8/git/graph || exit 2
python3 - <<'EOF'
import subprocess,json
R='a9b015557'
def show(p):
    return subprocess.run(['git','-C','/Users/n8/git/graph','show',f'{R}:{p}'],capture_output=True,text=True).stdout
# 170930Z has no verdict; its parts live under _bmad-output/gate-adjudication/ (only 1-3 of 8 exist)
for i in (1,2,3):
    t=show(f'_bmad-output/gate-adjudication/implementation-20261118T170930Z.part-{i}of8.jsonl')
    print('170930Z part',i,[(json.loads(l)['check_id'],json.loads(l)['verdict']) for l in t.splitlines() if l.strip()])
D='_bmad-output/implementation-artifacts/s323/gate-adjudication/'
def walk(o):
    if isinstance(o,dict):
        if 'check_id' in o and 'verdict' in o: yield o
        for v in o.values(): yield from walk(v)
    elif isinstance(o,list):
        for v in o: yield from walk(v)
for n in ['20261118T172256Z','20261118T173215Z','20261118T213543Z','20261118T220335Z','20261119T002345Z','20261119T004349Z']:
    o=json.loads(show(D+f'implementation-{n}.verdict.json'))
    cs={c['check_id']:c for c in walk(o)}
    print(n,o['gate_series_id'],'fails',[k for k,c in cs.items() if c['verdict']=='FAIL'],'c1',cs.get('1',{}).get('verdict'),'c11a',cs.get('11a',{}).get('verdict'))
EOF
for p in "0b634d223 496deae42" "496deae42 d7a8e25f3" "0617fced0 5c1d808dc" "cdbe474b0 e154f3a47"; do
  set -- $p; echo "== $1..$2"; git diff --stat -M "$1" "$2" | tail -4
done
git grep -n -i 'carried' a9b015557 -- docs/reviews/s323/5-5-code-review-p3.md | cut -c1-200
git show "a9b015557:test-results/s323-5-2-live-11a.txt" | tail -2
```
