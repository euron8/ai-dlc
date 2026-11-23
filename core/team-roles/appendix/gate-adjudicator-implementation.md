# Gate-adjudicator appendix: the implementation gate

**At an `implementation` gate you are the only seat** — your brief carries `shard: 1/1 implementation`
and you derive your slice with `--expected implementation --shard 1/1`. The checks decided by a script
arm or a rule table never appear on that list; of Check 2 you judge the hard-block half alone, since its
vocabulary and suppression-lifetime half is Check 2c, already decided by `gate-transition.sh`.
