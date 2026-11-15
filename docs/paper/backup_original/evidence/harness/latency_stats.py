# Evidence: mean/min/max/p50/p95 (nearest-rank) per endpoint from the RAW lines of latency.log (time_total in seconds).
import sys, math, collections
d = collections.OrderedDict()
for line in open(sys.argv[1], encoding='utf-8'):
    p = line.split()
    if len(p) >= 5 and p[0] == 'RAW':
        d.setdefault(p[1], []).append((p[3], float(p[4])))
print('%-14s %3s %8s %8s %8s %8s %8s  %s' % ('endpoint', 'n', 'mean_ms', 'min_ms', 'p50_ms', 'p95_ms', 'max_ms', 'http codes'))
for k, v in d.items():
    t = sorted(x[1] * 1000 for x in v)
    n = len(t)
    rank = lambda q: t[max(0, math.ceil(q * n) - 1)]
    codes = collections.Counter(x[0] for x in v)
    print('%-14s %3d %8.1f %8.1f %8.1f %8.1f %8.1f  %s' % (k, n, sum(t) / n, t[0], rank(0.5), rank(0.95), t[-1], dict(codes)))
