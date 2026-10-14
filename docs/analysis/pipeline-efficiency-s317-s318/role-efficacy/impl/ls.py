import os
G = '/Users/n8/git/graph'
for s in ('s317', 's318'):
    d = G + '/docs/reviews/' + s
    print('==', s, sorted(f for f in os.listdir(d) if f != 'shards'))
    print('shards:', len(os.listdir(d + '/shards')) if os.path.isdir(d + '/shards') else 0)
    d2 = G + '/_bmad-output/implementation-artifacts/' + s
    print('IA', sorted(os.listdir(d2)))
