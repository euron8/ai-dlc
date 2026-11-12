#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review and of a sharded gate-2 QA validation (--gate qa;
# arms Q1-Q16, S7-S10), and (BL-737) the seat's shard pre-check, the owner tails, the marker key, the
# content seal on review shards and the legacy rule (arms CS1-FT1). The mutation battery that once
# proved the older arms can fail has been retired; the predicates live in `lib.sh` beside this file.
# BL-740's verdict-backing arms (VB1-VB4) carry M7-M10 and an unmutated CONTROL (VBCTL) the same way.
# The BL-737 arms carry five in-process mutants (M1-M5 below), each run in a copy of the resolved
# script directory and only in the DISTRIBUTION layout: a consumer cannot edit core's scripts, so it
# keeps every correctness arm and loses only that proof.
#
# IN PROCESS. Every cell asks its subject in process through lib.sh's ip_run: the merge, the partition and
# partition-document.sh each hold their program in a *_main function behind a BASH_SOURCE guard, content-seal.sh
# (seal_main) and wait-for-deliverable.sh (wfd_mark_main) already did, and the recorder hook is sourced in a
# subshell with its payload on stdin. The merge is sourced ONCE per script directory (ip_load), a mutant's copy
# included. The end-to-end runs kept are EQ1-EQ8, one per distinct CLI outcome of each subject, each the same CLI
# line run both ways and compared byte for byte, with EQ0 proving the comparison can see a difference.
#
# WHAT IS AT STAKE. Check 1 in gate-validation.md reads ONE verdict line from ONE review file. A
# sharded review is N part reviewers plus one cross reviewer per cross group, and the merge writes that file. Its
# load-bearing claims are invisible to anything that only reads a finished review:
#   - the part set is RE-DERIVED from the manifest's inputs, never read off the shard directory;
#   - the merged verdict is the WORST shard verdict, never a count, the cross shard, or the last;
#   - the output matches Check 1's own pattern exactly once, and Check 1 reads the right value;
#   - every refusal writes nothing at --out.
#
# TWO SEEDED REPOSITORIES, ON PURPOSE. The merge re-runs the partition sibling, so a partition
# mutant runs inside every merge world. REPO A (dominant) puts every reviewable file under one top
# directory, `app/`: a first-path-component key sees one group and answers SERIAL, so only the
# adaptive split makes it partition -- arm P1 owns that. REPO B (equal) has three top directories
# of byte-identical numstat weight and is merged with --max-parts 3, where 3 x 1/3 of the weight
# never exceeds 1/K of the total, so adaptive and first-component keys give the SAME map; every
# merge world is built on B, so the first-component mutant moves P1 and nothing else.
#
# THE VERDICT WORLDS. W_disc {BLOCKED, APPROVED, APPROVED, cross APPROVED}: cross-wins, last-part-
# wins and majority all say APPROVED, worst-of says BLOCKED. W_bn {NEEDS_REWORK, BLOCKED,
# NEEDS_REWORK, cross APPROVED}: majority says NEEDS_REWORK, worst-of BLOCKED. W_ok (all APPROVED)
# stops "always BLOCKED" passing. W_c1 {NEEDS_REWORK, APPROVED, NEEDS_REWORK, cross NEEDS_REWORK}
# is the world where every one of those wrong rules AGREES with worst-of, so the Check-1 and
# conservation arms do not ride on the verdict mutants.
#
# CHECK 1'S PATTERN IS DERIVED from gate-validation.md with the sed gate-verdict-grep-shape uses,
# and the value is read back by this fixture's own reader, not by the merge's. The value rule is
# the one gate-validation.md Check 1 states, and it is cited there rather than restated here.
#
# The threshold key is named ONCE, in lib.sh's unset (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site. lib.sh sets the shell
# options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
#
# THE MUTANT MATRIX. Measured once by the re-measure command below, and re-measured whenever an arm or
# a mutant is added or changed: a mut_run line, a `cell` a mutant drive declares, or a file of the
# derived sibling set. Its population is each mutant x the cells of its own drive (the predicate its
# mut_run names), plus, for a drive declaring fewer than two cells, the deciding cell of every mutant of
# the same file; cells outside that population are not measured. Each cell is scored over the mutant
# copy and over the unmutated control copy, and reads RED (the cell failed), GREEN (it passed, exactly
# one cell run) or SKIP (not exactly one cell run). decides= is the cell the mutant is scored on (the arm whose reason token its killed line names);
# any other cell RED over the mutant and GREEN over the control is listed on a `# also trips:` comment line above the rows. twins= is a GREEN-under-both cell
# of the population outside decides=, the nearest to the deciding cell in declaration order. On each
# push a mutant runs its deciding cell (the kill) and each twin, which must pass: the mutant fails only
# its own assertion. An arm is <predicate>/<cell>.
# also trips: M12 vb_qa.q-nr-empty,vb_r3.r3-graph-cross1,vb_qa.q-unclassed,fr_bound.frb-legacy,lead.lr-record
# also trips: M15 fr_verdict.fr-reorder
# also trips: M18 serial.sr-q-suffix
# also trips: M23 canon.cr-path-other,canon.cr-filter-suffix,canon.cr-filter-gorun,canon.cr-filter-lf,canon.cr-filter-xff,canon.cr-filter-dd
# also trips: M24 canon.cr-exempt-evil,canon.cr-exempt-whole,canon.cr-norun-na,canon.cr-norun-nonebt,canon.cr-norun-other,canon.cr-exempt-link
# also trips: M25 canon_merge.crm-disk-legacy
# also trips: M27 canon_merge.crm-disk-held,canon_merge.crm-bind,canon_merge.crm-bind-hist,canon_merge.crm-hist-merge,canon_merge.crm-hist-shallow,canon_merge.crm-hist-replace,canon_merge.crm-hist-dir,canon_merge.crm-hist-sprint,canon_merge.crm-sprint-roll,canon_merge.crm-sprint-view,canon_merge.crm-schema-env,canon_merge.crm-root-env,canon_merge.crm-py-cwd
# also trips: M29 canon.cr-path-super,canon.cr-conv-runner
# also trips: M30 canon.cr-conv-runner-none,canon.cr-norun-other
# also trips: m-no-index canon.cr-bind-trunc,canon.cr-glob-literal
# also trips: m-wv-skip wv955.wv955-seat,wv955.wv955-merge,wv955.wv955-merge-unrec
# also trips: m-wv-seat wv955.wv955-merge-unrec
# also trips: m-single-file canon.cr-bind-repoint-k,canon.cr-bind-xdir-nostat,canon.cr-hist-replace
# also trips: m-endpoint-only canon.cr-hist-merge,canon.cr-roll-mid,canon.cr-py-cwd
# also trips: m-story-dir canon.cr-schema-env,canon.cr-root-env
# also trips: m-sprint canon.cr-hist-sprint,canon.cr-sprint-roll1
# also trips: m-story-dir-merge canon_merge.crm-schema-env,canon_merge.crm-root-env
# also trips: m-sprint-merge canon_merge.crm-hist-sprint,canon_merge.crm-sprint-roll
# also trips: m-endpoint-only-merge canon_merge.crm-hist-merge,canon_merge.crm-hist-replace,canon_merge.crm-py-cwd
# also trips: m-worktree canon.cr-bind-repoint-k,canon.cr-bind-trunc-ok,canon.cr-bind-xdir,canon.cr-bind-xdir-nostat,canon.cr-launder-rowdel,canon.cr-launder-rowdel-ok,canon.cr-hist-merge,canon.cr-hist-shallow,canon.cr-hist-shallow-blob,canon.cr-hist-replace,canon.cr-hist-dir,canon.cr-hist-sprint,canon.cr-sprint-roll1,canon.cr-sprint-view,canon.cr-schema-env,canon.cr-roll-ok,canon.cr-root-env,canon.cr-sprint-relpath,canon.cr-roll-mid,canon.cr-hist-crlf,canon.cr-bind-letter,canon.cr-b1-right,canon.cr-py-cwd,canon.cr-sprint-link-ok
# also trips: m-serial-only canon_merge.crm-bind-hist,canon_merge.crm-hist-merge,canon_merge.crm-hist-shallow,canon_merge.crm-hist-replace,canon_merge.crm-hist-dir,canon_merge.crm-hist-sprint,canon_merge.crm-sprint-roll,canon_merge.crm-sprint-view,canon_merge.crm-schema-env,canon_merge.crm-root-env,canon_merge.crm-py-cwd
# also trips: m-one-sprint-merge canon_merge.crm-sprint-link
# also trips: m956-1102 bind956.bind956-binds-run,bind956.bind956-receipt
# also trips: M41 adv_qa.ad-q-unreadable-absent,adv_qa.ad-q-world-b,adv_qa.ad-q-untracked-new
# also trips: M42 adv_qa.ad-q-legacy-prose,adv_qa.ad-q-world-a,adv_qa.ad-q-untracked-old
# also trips: M43 xc_count.xc-count,xc_one.xc-one
# also trips: M53 files.fl-del
# also trips: m-record-key lead.lr-ok,lead.lr-seatbase,lead.lr-orphan,lead.lr-rsha-legacy,lead.lr-disk-qa,lead.a3-letter,lead.a1-alias
# also trips: m-record-path lead.lr-norecord,lead.lr-rsha-legacy,lead.a3-letter,lead.a3-slug
# also trips: m-record-ignored lead.lr-record,lead.lr-ok,lead.lr-orphan,lead.lr-rsha-legacy,lead.lr-disk-qa,lead.a3-letter,lead.a1-alias
# also trips: m-rsha-off lead.lr-record,lead.lr-ok,lead.lr-seatbase,lead.lr-rsha-ne,lead.lr-rsha-strip,lead.a1-alias
# also trips: m-qa-at-F lead.lr-rsha-legacy,lead.a1-alias
# also trips: m-disk-qa lead.lr-rsha-legacy
# also trips: m-rec-write lead_rec.lr-9a,lead_rec.lr-legacy,lead_rec.lr-repass,lead_rec.d1-prefix-alias
# also trips: m-unrec lead_rec.lr-repass,lead_rec.lr-run-bind,lead_rec.lr-run-ok
# also trips: m-run-bind lead_rec.lr-run-bind
# also trips: m-run-bind-merge lead_rec.lr-run-bind-serial
# also trips: m-letter-idx canon.cr-glob-literal
# also trips: m-rec-base lead_rec.a2-redirect
# also trips: m-lc-merge lead_rec.a2-cwd
# also trips: M77 worst.w-bn
# also trips: M60 run_rec.rr-legacy,run_rec.rr-replay,run_rec.rr-rbind,run_rec.rr-stale,run_rec.rr-cross-code,run_rec.rr-s-lrange,run_rec.rr-s-lead,run_rec.rr-s-leg,run_rec.rr-s-lrl,run_rec.rr-s-lru
# also trips: M61 run_rec.rr-s-lrange
# also trips: M62 run_rec.rr-s-lead,run_rec.rr-s-lru
# also trips: M64 run_rec.rr-stale
# also trips: M65 run_rec.rr-s-lru
# also trips: M76 run_rec.rr-c-lru
# also trips: M74 run_rec.rr-ok,run_rec.rr-replay,run_rec.rr-earlier-eq,run_rec.rr-cross-ok
# also trips: m988-w2 wrap.wr-receipt,wrap.wr-undecl,wrap.wr-ph,wrap.wr-arity,wrap.wr-eqval,wrap.wr-slash,wrap.wr-d3npm,wrap.wr-d3git,wrap.wr-n5rel,wrap.rr-w-kfoo,wrap.rr-w-shape
# also trips: m988-w3 wrap.wr-receipt,wrap.wr-arity
# also trips: m988-w4 wrap.wr-mslow,wrap.wr-d4w
# also trips: m988-loop wrap.wr-receipt,wrap.wr-ok,wrap.wr-ok-shape,wrap.wr-pos,wrap.wr-adm,wrap.wr-admit,wrap.wr-subpath,wrap.wr-mslow,wrap.wr-prefix,wrap.wr-artpy1,wrap.wr-arity,wrap.wr-eqval,wrap.wr-artpy2,wrap.wr-prelude-f,wrap.wr-d4w,wrap.wr-n5abs,wrap.rr-w-decl
# also trips: m988-w6 wrap.rr-w-undecl
# also trips: m988-st2 wrap.wr-artpy2
# also trips: m988-prefix wrap.wr-arity
# also trips: m988-arity wrap.wr-eqval
# also trips: m988-1041 run_rec.rr-sum-cut
# MUTANT-MATRIX M1 decides=cs.partcite twins=cs.crossone
# MUTANT-MATRIX M2 decides=owner.dup-merge twins=owner.dup-check-owner-unsealed
# MUTANT-MATRIX M3 decides=mark.shard-3 twins=mark.caller-key
# MUTANT-MATRIX M4 decides=seal_rewrite.seal-rewrite twins=mark.shard-3
# MUTANT-MATRIX M5 decides=legacy.sentinel twins=legacy.absent
# MUTANT-MATRIX M6 decides=unmarked.unmarked-sentinel twins=unmarked.control-old-engine
# MUTANT-MATRIX M7 decides=vb_qa.q-nr-empty twins=vb_qa.q-nr-imp
# MUTANT-MATRIX M8 decides=vb_cr.cr-blocked-sug twins=vb_cr.cr-approved-crit
# MUTANT-MATRIX M9 decides=vb_cr.cr-approved-crit twins=vb_cr.cr-approved-imp
# MUTANT-MATRIX M10 decides=vb_cr.cr-nr-imp twins=vb_cr.cr-blocked-crit
# MUTANT-MATRIX M11 decides=vb_r3.r3-graph-cross1 twins=cs.partcite
# MUTANT-MATRIX M12 decides=vb_qmode.q-mode-sug twins=cs.partcite
# MUTANT-MATRIX M13 decides=vb_qleg.q-leg-nr-one twins=vb_qleg.q-two-containers
# MUTANT-MATRIX M14 decides=vb_qa.q-unclassed twins=vb_qa.q-nr-empty
# MUTANT-MATRIX M15 decides=fr_verdict.fr-plain twins=fr_verdict.fr-expected-only
# MUTANT-MATRIX M16 decides=fr_verdict.fr-reorder twins=fr_verdict.fr-expected-only
# MUTANT-MATRIX M17 decides=fr_orphan.fr-ac10 twins=fr_orphan.fr-ac1
# MUTANT-MATRIX M18 decides=serial.sr-q-set twins=serial.sr-cr-approved
# MUTANT-MATRIX M19 decides=serial.sr-q-twosame twins=serial.sr-q-suffix
# MUTANT-MATRIX M20 decides=fr_bound.frb-legacy twins=fr_bound.frb-severity
# MUTANT-MATRIX M21 decides=x_dupall.two twins=x_dupall.one
# MUTANT-MATRIX M22 decides=x_dupall.check twins=x_dupall.preca
# MUTANT-MATRIX M23 decides=canon.cr-filter-k twins=canon.cr-m-noconv
# MUTANT-MATRIX M24 decides=canon.cr-exempt-code twins=canon.cr-exempt-norange
# MUTANT-MATRIX M25 decides=canon_merge.crm-legacy twins=canon_merge.crm-disk-held
# MUTANT-MATRIX M26 decides=canon.cr-nr-norun twins=canon.cr-exempt-rec
# MUTANT-MATRIX M27 decides=canon_merge.crm-norun twins=canon_merge.crm-nr-norun
# MUTANT-MATRIX M28 decides=canon.cr-exempt-narrow twins=canon.cr-exempt-abs-rec
# MUTANT-MATRIX M29 decides=canon.cr-path-conv twins=canon.cr-path-other
# MUTANT-MATRIX M30 decides=canon.cr-norun-na twins=canon.cr-norun-nonebt
# MUTANT-MATRIX M31 decides=canon.cr-exempt-evil twins=canon.cr-exempt-narrow
# MUTANT-MATRIX M32 decides=canon.cr-serial-legacy twins=canon.cr-serial-redirect
# MUTANT-MATRIX M33 decides=canon_merge.crm-disk-legacy twins=canon_merge.crm-disk-held
# MUTANT-MATRIX M34 decides=canon.cr-filter-suffix twins=canon.cr-filter-gorun
# MUTANT-MATRIX M35 decides=canon.cr-filter-gorun twins=canon.cr-filter-lf
# MUTANT-MATRIX M36 decides=canon.cr-filter-lf twins=canon.cr-filter-xff
# MUTANT-MATRIX M37 decides=canon.cr-filter-dd twins=canon.cr-path-super
# MUTANT-MATRIX M38 decides=canon.cr-path-super twins=canon.cr-conv-runner
# MUTANT-MATRIX M39 decides=canon.cr-norun-nonebt twins=canon.cr-norun-other
# MUTANT-MATRIX M40 decides=canon.cr-conv-runner twins=canon.cr-conv-runner-none
# MUTANT-MATRIX M49 decides=canon.cr-exempt-abs-rec twins=canon.cr-exempt-typo
# MUTANT-MATRIX M50 decides=story_path.story-path twins=canon.cr-exempt-evil
# MUTANT-MATRIX M51 decides=story_frozen.story-frozen twins=canon.cr-exempt-evil
# MUTANT-MATRIX M58 decides=story_hist.story-hist twins=canon.cr-exempt-evil
# MUTANT-MATRIX M59 decides=story_hist.story-hist twins=canon.cr-exempt-evil
# MUTANT-MATRIX M66 decides=story_hist.story-hist twins=canon.cr-exempt-evil
# MUTANT-MATRIX m-row-exit decides=canon.cr-bind-seed twins=canon.cr-bind-sibling
# MUTANT-MATRIX m-no-index decides=canon.cr-bind-sibling-pre twins=canon.cr-bind-repoint-k
# MUTANT-MATRIX m-wv-skip decides=wv955.wv955-accepted twins=wv955.wv955-noentry
# MUTANT-MATRIX m-wv-frozen decides=wv955.wv955-inrange twins=wv955.wv955-seat
# MUTANT-MATRIX m-wv-seat decides=wv955.wv955-seat twins=wv955.wv955-bind
# MUTANT-MATRIX m-single-file decides=canon.cr-bind-xdir twins=canon.cr-launder-rowdel
# MUTANT-MATRIX m-status-skip decides=canon.cr-bind-xdir-nostat twins=canon.cr-launder-rowdel
# MUTANT-MATRIX m-index-grammar decides=canon.cr-bind-longidx twins=canon.cr-bind-letter
# MUTANT-MATRIX m-endpoint-only decides=canon.cr-launder-rowdel twins=canon.cr-launder-rowdel-ok
# MUTANT-MATRIX m-date-born decides=canon.cr-hist-merge twins=canon.cr-hist-shallow
# MUTANT-MATRIX m-shallow-ok decides=canon.cr-hist-shallow-blob twins=canon.cr-hist-replace
# MUTANT-MATRIX m-replace decides=canon.cr-hist-replace twins=canon.cr-hist-dir
# MUTANT-MATRIX m-story-dir decides=canon.cr-hist-dir twins=canon.cr-hist-sprint
# MUTANT-MATRIX m-crlf decides=canon.cr-hist-crlf twins=canon.cr-bind-longidx
# MUTANT-MATRIX m-sprint decides=canon.cr-sprint-view twins=canon.cr-sprint-nopath
# MUTANT-MATRIX m-view-sprint decides=canon.cr-sprint-roll1 twins=canon.cr-sprint-view
# MUTANT-MATRIX m-schema-env decides=canon.cr-schema-env twins=canon.cr-gwt
# MUTANT-MATRIX m-root-env decides=canon.cr-root-env twins=canon.cr-sprint-relpath
# MUTANT-MATRIX m-relpath decides=canon.cr-sprint-relpath twins=canon.cr-roll-mid
# MUTANT-MATRIX m-gwt decides=canon.cr-gwt twins=canon.cr-roll-ok
# MUTANT-MATRIX m-roll-drop-off decides=canon.cr-roll-ok twins=canon.cr-root-env
# MUTANT-MATRIX m-roll-drop-every decides=canon.cr-roll-mid twins=canon.cr-hist-crlf
# MUTANT-MATRIX m-legacy-env decides=canon.cr-serial-redirect twins=canon.cr-py-cwd
# MUTANT-MATRIX m-date-born-merge decides=canon_merge.crm-hist-merge twins=canon_merge.crm-hist-shallow
# MUTANT-MATRIX m-shallow-ok-merge decides=canon_merge.crm-hist-shallow twins=canon_merge.crm-hist-replace
# MUTANT-MATRIX m-replace-merge decides=canon_merge.crm-hist-replace twins=canon_merge.crm-hist-dir
# MUTANT-MATRIX m-story-dir-merge decides=canon_merge.crm-hist-dir twins=canon_merge.crm-hist-sprint
# MUTANT-MATRIX m-sprint-merge decides=canon_merge.crm-sprint-view twins=canon_merge.crm-schema-env
# MUTANT-MATRIX m-view-sprint-merge decides=canon_merge.crm-sprint-roll twins=canon_merge.crm-sprint-view
# MUTANT-MATRIX m-schema-env-merge decides=canon_merge.crm-schema-env twins=canon_merge.crm-root-env
# MUTANT-MATRIX m-root-env-merge decides=canon_merge.crm-root-env twins=canon_merge.crm-range
# MUTANT-MATRIX m-endpoint-only-merge decides=canon_merge.crm-bind-hist twins=canon_merge.crm-hist-shallow
# MUTANT-MATRIX m-digit-slug decides=canon.cr-bind-trunc twins=canon.cr-bind-trunc-ok
# MUTANT-MATRIX m-worktree decides=canon.cr-bind-ok twins=canon.cr-exempt-whole
# MUTANT-MATRIX m-serial-only decides=canon_merge.crm-bind twins=canon_merge.crm-bind-ok
# MUTANT-MATRIX m956-1102 decides=bind956.bind956-binds twins=bind956.bind956-other
# MUTANT-MATRIX m956-1132 decides=bind956.bind956-onestory twins=bind956.bind956-hist
# MUTANT-MATRIX m956-1145 decides=bind956.bind956-hist twins=bind956.bind956-onestory
# MUTANT-MATRIX m956-rekey decides=bind956.bind956-rekey twins=bind956.bind956-binds
# MUTANT-MATRIX m956-rekey-ko decides=bind956.bind956-rekey-ko twins=bind956.bind956-binds
# MUTANT-MATRIX m956-window decides=bind956.bind956-prebase twins=bind956.bind956-rekey
# MUTANT-MATRIX m956-stem decides=bind956.bind956-stem twins=bind956.bind956-binds
# MUTANT-MATRIX M41 decides=adv_qa.ad-q-present-absent twins=adv_qa.ad-q-called
# MUTANT-MATRIX M42 decides=adv_qa.ad-q-legacy-absent twins=adv_qa.ad-q-unreadable-absent
# MUTANT-MATRIX M43 decides=xc_flip.xc-flip twins=xc_merge.xc-merge
# MUTANT-MATRIX M44 decides=xc_merge.xc-merge twins=xc_flip.xc-flip
# MUTANT-MATRIX M45 decides=xc_count.xc-count twins=xc_flip.xc-flip
# MUTANT-MATRIX M46 decides=xc_one.xc-one twins=xc_flip.xc-flip
# MUTANT-MATRIX m-k2only decides=x_lone.x-lone-k8 twins=x_lone.x-partial
# MUTANT-MATRIX m-nomix decides=x_mix.x-mix twins=cs.partcite
# MUTANT-MATRIX M47 decides=qclass.qc-foo twins=qclass.qc-evidence
# MUTANT-MATRIX M48 decides=qclass.qc-none twins=qclass.qc-foo
# MUTANT-MATRIX M52 decides=files.fl-nc twins=files.fl-dup
# MUTANT-MATRIX M53 decides=files.fl-gone twins=files.fl-ok
# MUTANT-MATRIX M54 decides=files.fl-tick twins=files.fl-line
# MUTANT-MATRIX M55 decides=files.fl-dup twins=files.fl-empty
# MUTANT-MATRIX M56 decides=files.fl-empty twins=files.fl-tick
# MUTANT-MATRIX M57 decides=files.fl-del twins=files.fl-ok
# MUTANT-MATRIX m-lead-anc decides=lead.lr-orphan twins=lead.lr-rewind
# MUTANT-MATRIX m-record-key decides=lead.lr-record twins=lead.lr-rewind
# MUTANT-MATRIX m-record-path decides=lead.lr-record twins=lead.lr-ok
# MUTANT-MATRIX m-unrec-refuse decides=lead.lr-norecord twins=lead.lr-rsha-ne
# MUTANT-MATRIX m-unrec-silent decides=lead.lr-norecord twins=lead.lr-rsha-ne
# MUTANT-MATRIX m-record-ignored decides=lead.lr-seatbase twins=lead.lr-rewind
# MUTANT-MATRIX m-rsha-eq decides=lead.lr-rsha-ne twins=lead.lr-rsha-legacy
# MUTANT-MATRIX m-rsha-always decides=lead.lr-rsha-legacy twins=lead.lr-rsha-strip
# MUTANT-MATRIX m-rsha-off decides=lead.lr-rewind twins=lead.lr-norecord
# MUTANT-MATRIX m-live-ref decides=lead.lr-rewind twins=lead.lr-norecord
# MUTANT-MATRIX m-qa-at-F decides=lead.lr-rsha-strip twins=lead.lr-disk-qa
# MUTANT-MATRIX m-disk-qa decides=lead.lr-disk-qa twins=lead.cr-slot-suffix
# MUTANT-MATRIX m-slot-loose decides=lead.cr-slot-suffix twins=lead.lr-slot
# MUTANT-MATRIX m-lead-slot decides=lead.lr-slot twins=lead.a3-letter
# MUTANT-MATRIX m-rec-idx decides=lead.a3-slug twins=lead.a3-bad
# MUTANT-MATRIX m-letter-idx decides=canon.cr-b1-right twins=canon.cr-bind-ok
# MUTANT-MATRIX m-idx-pattern decides=canon.cr-glob-literal twins=canon.cr-bind-ok
# MUTANT-MATRIX m-py-isolated decides=canon.cr-py-cwd twins=canon.cr-sprint-link
# MUTANT-MATRIX m-py-isolated-merge decides=canon_merge.crm-py-cwd twins=canon_merge.crm-sprint-link
# MUTANT-MATRIX m-one-sprint decides=canon.cr-sprint-link twins=canon.cr-sprint-link-ok
# MUTANT-MATRIX m-one-sprint-merge decides=canon_merge.crm-sprint-link-check twins=canon_merge.crm-ok
# MUTANT-MATRIX m-ro-mode decides=canon.cr-exempt-link twins=canon.cr-exempt-link-ok
# MUTANT-MATRIX m-rec-write decides=lead_rec.lr-ok twins=lead_rec.lr-sha
# MUTANT-MATRIX m-rec-unkeyed decides=lead_rec.lr-repass twins=lead_rec.a2-redirect
# MUTANT-MATRIX m-rec-base decides=lead_rec.lr-move twins=lead_rec.lr-9a
# MUTANT-MATRIX m-rec-sha decides=lead_rec.lr-sha twins=lead_rec.lr-move
# MUTANT-MATRIX m-rec-era decides=lead_rec.lr-9a twins=lead_rec.lr-legacy
# MUTANT-MATRIX m-unrec decides=lead_rec.lr-unrec twins=lead_rec.lr-ok
# MUTANT-MATRIX m-run-bind decides=lead_rec.lr-run-bind-serial twins=lead_rec.lr-run-ok-serial
# MUTANT-MATRIX m-run-bind-merge decides=lead_rec.lr-run-bind twins=lead_rec.lr-run-ok
# MUTANT-MATRIX m-lc-serial decides=lead.a1-redirect twins=lead.a1-alias
# MUTANT-MATRIX m-lc-record decides=lead_rec.a2-record twins=lead_rec.a2-cwd
# MUTANT-MATRIX m-lc-merge decides=lead_rec.a2-redirect twins=lead_rec.a2-record
# MUTANT-MATRIX m-d1-merge decides=lead_rec.d1-symlink-sprint twins=lead_rec.d1-record-link
# MUTANT-MATRIX m-d1-record decides=lead_rec.d1-record-link twins=lead_rec.d1-outside
# MUTANT-MATRIX m-d1-name decides=lead_rec.d1-outside twins=lead_rec.d1-prefix-alias
# MUTANT-MATRIX m-d1-abs decides=lead_rec.d1-prefix-alias twins=lead_rec.lr-run-bind
# MUTANT-MATRIX M60 decides=run_rec.rr-fab twins=run_rec.rr-ok
# MUTANT-MATRIX M61 decides=run_rec.rr-stale twins=run_rec.rr-earlier-eq
# MUTANT-MATRIX M62 decides=run_rec.rr-fab twins=run_rec.rr-legacy
# MUTANT-MATRIX M63 decides=run_rec.rr-earlier-eq twins=run_rec.rr-cross-ok
# MUTANT-MATRIX M64 decides=run_rec.rr-cross-code twins=run_rec.rr-head
# MUTANT-MATRIX M65 decides=run_rec.rr-s-lead twins=run_rec.rr-s-leg
# MUTANT-MATRIX M67 decides=run_rec.rr-s-head twins=run_rec.rr-s-lrange
# MUTANT-MATRIX M68 decides=run_rec.rr-replay twins=run_rec.rr-mq
# MUTANT-MATRIX M69 decides=run_rec.rr-rbind twins=run_rec.rr-stale
# MUTANT-MATRIX M70 decides=run_rec.rr-sum-cut twins=run_rec.rr-sum-log
# MUTANT-MATRIX M71 decides=run_rec.rr-sum-log twins=run_rec.rr-sum-q
# MUTANT-MATRIX M72 decides=run_rec.rr-s-lrl twins=run_rec.rr-s-lru
# M73 is scored by hand, not per push: the run.sh copy whose --matrix recording (mut_run_one's MX_ROWS append) skips
# every mutant outside RSM_MATRIX_SLICE, so each slice's populations shrink; MX1's slice arm refuses it, and so
# does --merge-slices. MX1.plain is its twin, because a run with no slice never reaches the filter.
# MUTANT-MATRIX M73 decides=MX1.slice twins=MX1.plain
# K1-K3 are scored by hand, not per push, the same way: run.sh copies that switch KS1 off (K1), make its kill set its
# deal (K2), or make its FAIL branch print ok (K3). KS1-CTL kills each (its block, beside KS1, spells the three edits).
# MUTANT-MATRIX K1 decides=KS1-CTL twins=KS1
# MUTANT-MATRIX K2 decides=KS1-CTL twins=KS1
# MUTANT-MATRIX K3 decides=KS1-CTL twins=KS1
# GM1's mutant is built and scored IN p_gmaint on every run (G's `declare -f` body less -c maintenance.auto=false, cmp-guarded,
# the flag counted 1 -> 0); it has no mut_run call, so it is never dealt and never reaches mutant_killed.
# MUTANT-MATRIX gm-no-maint decides=gmaint twins=- why=the mutant is built inside the one arm it decides and is scored there on every run, so no other cell runs it
# GM1's must-fire (BL-980) is a mutant of the same kind: receipt-bl980.sh (which p_gmaint runs) copies receipt-bl904.sh
# less every -c maintenance.auto=false, drives it as lib.sh does and requires at least one spawn, on every run; one that
# does not spawn makes the receipt, and so the fixture, BROKEN.
# MUTANT-MATRIX gm-mustfire-bl904 decides=gmaint twins=- why=the mutant is built inside the receipt the one arm it decides runs, and is scored there on every run, so no other cell runs it
# MUTANT-MATRIX M74 decides=run_rec.rr-mq twins=run_rec.rr-mu
# MUTANT-MATRIX M75 decides=run_rec.rr-c-lrl twins=run_rec.rr-c-lru
# MUTANT-MATRIX M76 decides=run_rec.rr-s-lru twins=run_rec.rr-c-lrl
# MUTANT-MATRIX m988-w2 decides=wrap.rr-w-undecl twins=wrap.wr-ok
# MUTANT-MATRIX m988-w3 decides=wrap.wr-pos twins=wrap.wr-adm
# MUTANT-MATRIX m988-w4 decides=wrap.wr-subpath twins=wrap.wr-kpay
# MUTANT-MATRIX m988-quote decides=wrap.wr-d4 twins=wrap.wr-d4w
# MUTANT-MATRIX m988-loop decides=wrap.wr-term twins=wrap.wr-loop-twin
# MUTANT-MATRIX m988-n2 decides=wrap.wr-prelude twins=wrap.wr-prelude-f
# MUTANT-MATRIX m988-w6 decides=wrap.rr-w-kfoo twins=wrap.rr-w-shape
# MUTANT-MATRIX m988-w6s decides=wrap.rr-w-shape twins=wrap.wr-receipt
# MUTANT-MATRIX m988-d3 decides=wrap.wr-d3git twins=wrap.wr-d4
# MUTANT-MATRIX m988-fb decides=wrap.wr-fallback twins=wrap.wr-artpy1
# MUTANT-MATRIX m988-st2 decides=wrap.wr-artpy1 twins=wrap.wr-ph
# MUTANT-MATRIX m988-prefix decides=wrap.wr-prefix twins=wrap.wr-fallback
# MUTANT-MATRIX m988-arity decides=wrap.wr-arity twins=wrap.wr-slash
# MUTANT-MATRIX m988-ph decides=wrap.wr-ph twins=wrap.wr-arity
# MUTANT-MATRIX m988-slash decides=wrap.wr-slash twins=wrap.wr-artpy2
# MUTANT-MATRIX m988-oper decides=wrap.wr-d4w twins=wrap.wr-n5rel
# MUTANT-MATRIX m988-1041 decides=run_rec.rr-nosum twins=run_rec.rr-sum-log
# MUTANT-MATRIX M77 decides=worst.w-disc twins=worst.w-ok
# MUTANT-MATRIX M78 decides=miss_ord.miss-ord twins=cs.partcite
# MUTANT-MATRIX M79 decides=a3.a3-two twins=cs.partcite
# MUTANT-MATRIX M80 decides=a3.a3-two twins=cs.partcite
# MUTANT-MATRIX-CONTROL VBCTL why=no mutation: each mutant's deciding cell reuses the passing top-level arm of the same predicate from this run as its base-pass flag, and runs over the unmutated sibling copy only when no such arm passed or under --matrix
# MUTANT-MATRIX-DYNAMIC mut_run why=mut_run hands its <id> argument to mutant_killed; every id it is called with has its own MUTANT-MATRIX row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/review-shard-merge/run.sh --matrix
# REMEASURE, SLICED: the same matrix in five parallel parts, each with its own verdict store and output, then merged:
#   for k in 0 1 2 3 4; do RSM_MATRIX_SLICE=$k/5 AI_DLC_VERDICT_STORE="$(mktemp -d)" \
#     bash core/fixtures/review-shard-merge/run.sh --matrix > slice-$k.out 2>&1 & done; wait
#   bash core/fixtures/review-shard-merge/run.sh --merge-slices slice-0.out slice-1.out slice-2.out slice-3.out slice-4.out
# REMEASURE, OWED ROWS ONLY: RSM_MATRIX_IDS="<id> <id>..." with --matrix records every mutant as above and scores only
# the rows named (MX1's whole-population counts then read short and it is not a verdict); a change re-measures the
# rows whose predicate's population it moved and keeps the rest.
# RSM_MATRIX_SLICE=k/n (integers, 0 <= k < n, --matrix only; anything else exits 2) is read only by matrix_score's
# row loop: every slice still RECORDS all mutants, because a drive declaring fewer than two cells borrows the
# deciding cell of every other mutant of its file from the full record, and it SCORES the rows whose 0-based index
# mod n is k, printing for them the MATRIX, MATRIX-HEADER and MATRIX-ALSO lines the unsliced run prints. It also
# prints one MATRIX-POP line per (mutant, cell) of EVERY row and one MATRIX-SLICE line. --merge-slices prints the
# slices' MATRIX* lines and exits 1 unless the files are n slices k = 0..n-1 of one n, each ending in PASS, their
# MATRIX-POP sets agree, and the MATRIX pairs equal that population with none missing and none twice.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
# rsm_merge_slices <slice output>...: the join of a sliced --matrix (header above). One awk, no world built.
rsm_merge_slices() {
  [ $# -ge 1 ] || { echo "usage: run.sh --merge-slices <slice output>..." >&2; return 2; }
  awk -v name="$NAME" '
    FNR == 1 { nf++; F[nf] = FILENAME; sl[nf] = ""; pass[nf] = 0 }
    $1 == "MATRIX-SLICE" { if (sl[nf] != "") err = err "\n  " FILENAME ": two MATRIX-SLICE lines"; sl[nf] = $2 }
    $0 == name ": PASS" { pass[nf] = 1 }
    $1 == "MATRIX-POP" && NF == 3 { k = $2 SUBSEP $3; if (!((nf, k) in PS)) { PS[nf, k] = 1; PN[nf]++; if (nf == 1) { P[k] = 1; NP++ } } }
    $1 == "MATRIX" && NF == 5 { k = $2 SUBSEP $3; M[k]++; NM++ }
    /^MATRIX(-HEADER|-ALSO)? / { print }
    END {
      for (i = 1; i <= nf; i++) {
        if (sl[i] !~ /^[0-9]+\/[0-9]+$/) { err = err "\n  " F[i] ": no MATRIX-SLICE k/n line; not a sliced --matrix output"; continue }
        split(sl[i], a, "/")
        if (n == "") n = a[2]; else if (a[2] != n) err = err "\n  " F[i] ": slice " sl[i] " is not of n=" n
        if (a[1] in K) err = err "\n  " F[i] ": slice " sl[i] " given twice"; K[a[1]] = 1
        if (!pass[i]) err = err "\n  " F[i] ": the slice did not end in " name ": PASS"
        if (PN[i] != NP) err = err "\n  " F[i] ": its MATRIX-POP set has " PN[i] + 0 " pairs, the first slice " NP + 0
      }
      if (n != "" && nf != n) err = err "\n  " nf " slice file(s) for n=" n
      for (j = 0; n != "" && j < n; j++) if (!(j in K)) err = err "\n  slice " j "/" n " is absent"
      for (x in PS) { split(x, b, SUBSEP); if (!((b[2], b[3]) in P)) { err = err "\n  " F[b[1]] ": MATRIX-POP " b[2] " " b[3] " is not in the first slice"; break } }
      if (NP == 0) err = err "\n  no MATRIX-POP population was read"
      for (k in M) { split(k, c, SUBSEP); if (M[k] > 1) err = err "\n  MATRIX " c[1] " " c[2] " appears " M[k] " times"; if (!(k in P)) err = err "\n  MATRIX " c[1] " " c[2] " is outside the recorded population" }
      for (k in P) if (!(k in M)) { split(k, c, SUBSEP); err = err "\n  MATRIX " c[1] " " c[2] " is missing"; miss++ }
      if (err != "") { printf "MERGE-SLICES: REFUSED:%s\n", err > "/dev/stderr"; exit 1 }
      printf "MERGE-SLICES: %d slices of n=%s, %d MATRIX pairs = the recorded population, none missing, none twice\n", nf, n, NM > "/dev/stderr"
    }' "$@"
}
# ---------------------------------------------------------------------------- shards (BL-906)
# THIS FILE IS TWO SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY (the
# readset-skip shape). Every top-level arm sits inside a UNIT, `if sg <unit>; then` ... `fi # sg <unit>`, and `--group
# <x>` runs the units dealt to shard <x>. The sibling `review-shard-merge-b/run.sh` is a one-line driver that execs this
# file with `--group b`; no `--group` is shard a. A MUTANT RIDES WITH ITS PREDICATE'S ARM: its unit is the unit whose
# guard holds the `arm`/`arm2` line of the predicate its mut_run names, so its base-pass flag is set in the same shard.
# The seed (lib.sh, seed_controls), the mutant machinery (SIB, the control copy) and the closing tally run in every shard.
#   a  seam arms bl737 bl885 bl808        the in-process seam (EQ0-EQ8, every subject start), the P/V/R/Q/H/X/G arms, CS1-
#      gmaint                             SR1, the BL-885 story arms, both lead arms (LR0), AD1-AD3, SR2, QC1, VB3-XC5,
#                                         and GM1 (lib.sh's G wrapper spawns no auto-maintenance, BL-868)
# The step and role prose pins (S0-S13, XC-STEP) run no subject and live in process-rule-pins section 4i.
#   b  canon canon_merge files            CR1, CR2, FL1, BL-904's story history (receipt-bl904.sh, M58 M59 M66) and
#      story_hist run_rec                 BL-905's RR1 (M60-M72, M74-M76) and BL-988's WR1 (m988-*), each with its mutants
# M73 (MX1.slice) and K1-K3 (KS1-CTL) are hand-scored, never dealt: they have no mut_run call. MX1 is per-run accounting and runs in both shards.
# THE COVERAGE JOIN (J0) runs in EVERY shard, and under --deal, before lib.sh builds anything: the declared units are
# DERIVED from this file's `if sg <unit>; then` lines, the dealt lists must be disjoint and their union exact, every
# arm line must sit inside a unit, every mutant (read off its mut_run call with a stub, the emission site) must map to
# a dealt unit, the mutant total must be 177, and every declared shard must have a driver directory. It proves it can
# fire first, on a seeded duplicate and a seeded omission. --matrix runs every unit's arms and records every mutant;
# alone it scores all 177 rows, with --group <x> only shard <x>'s dealt rows, printing every row's population as
# MATRIX-ALLPOP so the two shards' MATRIX pairs join to the unsharded population. A plain run's KS1 asserts the shard
# killed exactly the mutants it was dealt, and its KS1-CTL proves KS1 refuses that run's kill set less one id.
# --deal prints each shard's dealt units, arms, mutants and its static unit-cell count (an arm's `cell` declarations in
# its lib.sh predicate, at least 1; a mutant's deciding cell plus its twins), then exits 0: the BL-906 receipt reads it.
SHARDS="a b"
UNITS_a="seam arms bl737 bl885 bl808 gmaint"
UNITS_b="canon canon_merge files story_hist run_rec"
GROUP=a; RSM_MATRIX=0; RSM_DEAL=0; _grp=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) _grp=1; GROUP="${2:-}"
      [ -n "$GROUP" ] || { echo "usage: run.sh [--group <shard> | --matrix | --deal]: --group needs a shard name" >&2; exit 2; }
      shift; shift ;;
    --matrix) RSM_MATRIX=1; shift ;;
    --deal) RSM_DEAL=1; shift ;;
    --merge-slices) shift; [ "$GROUP" = a ] || NAME="review-shard-merge-$GROUP"; rsm_merge_slices "$@"; exit $? ;;
    *) echo "usage: run.sh [--group <shard>] [--matrix] | --deal | [--group <shard>] --merge-slices <slice output>..." >&2; exit 2 ;;
  esac
done
# --group with --matrix scores that shard's dealt mutants only (the per-shard matrix); --matrix alone scores every unit.
[ $((RSM_MATRIX + RSM_DEAL)) -le 1 ] && [ $((_grp + RSM_DEAL)) -le 1 ] || { echo "usage: run.sh [--group <shard>] [--matrix] | --deal: --deal takes neither" >&2; exit 2; }
# RSM_MATRIX_SLICE=k/n (header): parsed here so a malformed value refuses before any world is built.
RSM_SLICE_K=""; RSM_SLICE_N=""
if [ -n "${RSM_MATRIX_SLICE+set}" ]; then
  case "$RSM_MATRIX_SLICE" in
    [0-9]*/[0-9]*) RSM_SLICE_K="${RSM_MATRIX_SLICE%%/*}"; RSM_SLICE_N="${RSM_MATRIX_SLICE#*/}" ;;
  esac
  case "$RSM_SLICE_K/$RSM_SLICE_N" in
    */*/*|*[!0-9/]*|/*|*/|0[0-9]*|*/0*) echo "run.sh: RSM_MATRIX_SLICE='$RSM_MATRIX_SLICE' is not k/n with integers 0 <= k < n" >&2; exit 2 ;;
  esac
  [ "$RSM_SLICE_K" -lt "$RSM_SLICE_N" ] || { echo "run.sh: RSM_MATRIX_SLICE='$RSM_MATRIX_SLICE' is not k/n with integers 0 <= k < n" >&2; exit 2; }
  [ "$RSM_MATRIX" = 1 ] || { echo "run.sh: RSM_MATRIX_SLICE is read only with --matrix" >&2; exit 2; }
fi
case " $SHARDS " in *" $GROUP "*) ;; *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;; esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
# MINE is the units whose ARMS run; DEALT the units whose MUTANTS this run scores. A plain run: both the shard's deal.
# --matrix runs every arm and records every mutant (a drive declaring fewer than two cells borrows the deciding cells of
# its file's other mutants from the full record), and scores the rows of DEALT: all of them with no --group, the
# shard's with one, so the per-shard matrices partition the unsharded pair population (MATRIX-POP, below).
DEALT="$MINE"
[ "$RSM_MATRIX" = 0 ] && [ "$RSM_DEAL" = 0 ] || MINE="$UNITS_a $UNITS_b"
{ [ "$RSM_MATRIX" = 1 ] && [ "$_grp" = 0 ]; } || [ "$RSM_DEAL" = 1 ] && DEALT="$MINE"
[ "$GROUP" = a ] || NAME="review-shard-merge-$GROUP"
rsm_broken() { echo "FIXTURE BROKEN: $1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || rsm_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
dg() { case " $DEALT " in *" $1 "*) return 0 ;; esac; return 1; }
rsm_partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
RSM_JW="$(mktemp -d "${TMPDIR:-/tmp}/review-shard-merge-join.XXXXXX")" || rsm_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$RSM_JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$RSM_JW/pdup"; printf '%s\n' u1 u3 > "$RSM_JW/pmiss"; printf '%s\n' u3 u1 u2 > "$RSM_JW/pok"
if rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pdup" > /dev/null || rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pmiss" > /dev/null \
   || ! rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pok" > /dev/null; then
  rm -rf "$RSM_JW"; rsm_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
RSM_SELF="$HERE/run.sh"
sed -n 's/^if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$RSM_SELF" > "$RSM_JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$RSM_JW/dealt"
_ndecl="$(grep -c . "$RSM_JW/declared")" || _ndecl=0
_ndup="$(sort "$RSM_JW/declared" | uniq -d | grep -c .)" || _ndup=0
[ "$_ndecl" -gt 0 ] && [ "$_ndup" = 0 ] || { rm -rf "$RSM_JW"; rsm_broken "$_ndecl unit guards derived from $RSM_SELF ($_ndup declared twice)"; }
_why="$(rsm_partition_ok "$RSM_JW/declared" "$RSM_JW/dealt")" || { rm -rf "$RSM_JW"; rsm_broken "the shard partition does not cover the guarded units exactly -- $_why"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../review-shard-merge-$_s/run.sh"
  [ -f "$_drv" ] && grep -qF -- "--group $_s" "$_drv" || { rm -rf "$RSM_JW"; rsm_broken "shard '$_s' is declared but $_drv does not drive it"; }
done
# Each arm line's unit (one awk): `<predicate> <unit>`, the unit `-` for an arm outside every guard.
awk '/^if sg [a-z0-9_]+; then$/ { u = $3; sub(/;$/, "", u) } /^fi # sg [a-z0-9_]+$/ { u = "" }
  /^[[:space:]]*arm2? [a-z0-9_]+ / { print $2 " " (u == "" ? "-" : u) }' "$RSM_SELF" > "$RSM_JW/arms"
_nout="$(grep -c ' -$' "$RSM_JW/arms")" || _nout=0
_narm="$(grep -c . "$RSM_JW/arms")" || _narm=0
[ "$_narm" -gt 0 ] && [ "$_nout" = 0 ] || { rm -rf "$RSM_JW"; rsm_broken "$_nout of $_narm arm line(s) sit outside every unit guard"; }
# Each mutant, read off its mut_run call by a stub (receipt-bl755.sh's reading): `<id>\t<predicate>\t<file old new>`.
_calls="$(awk '/^[[:space:]]*(CS_ONLY=[^ ]+[[:space:]]+)?mut_run [A-Za-z]/ { p = 1 } p { print; if ($0 !~ /\\$/) p = 0 }' "$RSM_SELF")"
( mut_run() { printf '%s\t%s\t%s\037%s\037%s\n' "$1" "$5" "$2" "$3" "$4"; }; eval "$_calls" ) > "$RSM_JW/muts" 2> /dev/null \
  || { rm -rf "$RSM_JW"; rsm_broken "the mut_run calls in $RSM_SELF did not execute under the stub"; }
# MUT_ROWS: `<id> <unit> <shared>` per mutant, shared 1 when an earlier mutant of the SAME SHARD made the identical edit.
_unitshard="$(for _s in $SHARDS; do eval "_us=\"\${UNITS_$_s}\""; for _u in $_us; do printf '%s %s\n' "$_u" "$_s"; done; done)"
MUT_ROWS="$(US="$_unitshard" awk -F'\t' 'BEGIN { n = split(ENVIRON["US"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], f, " "); sh[f[1]] = f[2] } }
  FILENAME == ARGV[1] { split($0, f, " "); pu[f[1]] = f[2]; next }
  { u = ($2 in pu) ? pu[$2] : "-"; k = sh[u] SUBSEP $3; s = (k in seen) ? 1 : 0; seen[k] = 1; print $1, u, s }' "$RSM_JW/arms" "$RSM_JW/muts")"
_mall="$(printf '%s\n' "$MUT_ROWS" | grep -c .)" || _mall=0
_mnou="$(printf '%s\n' "$MUT_ROWS" | awk '$2 == "-"' | grep -c .)" || _mnou=0
_mdup="$(printf '%s\n' "$MUT_ROWS" | awk '{ print $1 }' | sort | uniq -d | grep -c .)" || _mdup=0
[ "$_mall" = 177 ] && [ "$_mnou" = 0 ] && [ "$_mdup" = 0 ] \
  || { rm -rf "$RSM_JW"; rsm_broken "the mut_run calls name $_mall mutants (want 177), $_mdup id(s) twice, $_mnou whose predicate has no unit-guarded arm"; }
MUT_MINE=" "; MUT_MINE_N=0; MUT_MINE_SHARED=0
while read -r _id _u _sh; do
  dg "$_u" || continue
  MUT_MINE="$MUT_MINE$_id "; MUT_MINE_N=$((MUT_MINE_N + 1)); MUT_MINE_SHARED=$((MUT_MINE_SHARED + _sh))
done <<< "$MUT_ROWS"
if [ "$RSM_DEAL" = 1 ]; then
  # The static unit-cell count: an arm's `cell` declarations in its lib.sh body (at least 1), a mutant's 1 + its twins.
  awk 'match($0, /^p_[a-z0-9_]+\(\) *\{/) { p = substr($0, 3, RLENGTH - 2); sub(/\(.*/, "", p); n[p] += 0 }
    /^[[:space:]]*#/ { next } p != "" { s = $0; while (match(s, /(^|[^a-z_])cell [a-z0-9]/)) { n[p]++; s = substr(s, RSTART + RLENGTH) } }
    /^}/ { p = "" } END { for (k in n) print k, n[k] }' "$HERE/lib.sh" > "$RSM_JW/cells"
  sed -n 's/^# MUTANT-MATRIX \([^ ]*\) decides=[^ ]* twins=\([^ ]*\)$/\1 \2/p' "$RSM_SELF" | awk '{ print $1, 1 + split($2, t, ",") }' > "$RSM_JW/mcells"
  _total=0
  for _s in $SHARDS; do
    eval "_us=\"\${UNITS_$_s}\""
    _out="$(awk -v us=" $_us " 'FILENAME == ARGV[1] { c[$1] = $2; next } FILENAME == ARGV[2] { m[$1] = $2; next }
      FILENAME == ARGV[3] { if (index(us, " " $2 " ")) { na++; x = ($1 in c) && c[$1] > 0 ? c[$1] : 1; cl += x } next }
      { split($0, f, " "); if (index(us, " " f[2] " ")) { nm++; ids = ids (ids == "" ? "" : ",") f[1]; cl += (f[1] in m) ? m[f[1]] : 2 } }
      END { printf "arms=%d mutants=%d cells=%d ids=%s\n", na, nm, cl, ids }' "$RSM_JW/cells" "$RSM_JW/mcells" "$RSM_JW/arms" <(printf '%s\n' "$MUT_ROWS"))"
    echo "DEAL $_s units=$(printf '%s' "$_us" | tr ' ' ',') $_out"
    _c="${_out#*cells=}"; _total=$((_total + ${_c%% *}))
  done
  echo "DEAL-TOTAL cells=$_total"
fi
rm -rf "$RSM_JW"
echo "  [J0] coverage join: $_ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; $_narm arm lines each inside a unit; $_mall mutants each dealt with its predicate's arm; this shard runs {$MINE} and $MUT_MINE_N mutant(s)"
[ "$RSM_DEAL" = 1 ] || echo "DEALT-IDS $(printf '%s' "${MUT_MINE# }" | tr ' ' ',' | sed 's/,$//')"
[ "$RSM_DEAL" = 0 ] || exit 0
# I10 reads run.sh, not lib.sh, for the ambient-env scrub; this is the same scrub lib.sh performs.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
. "$HERE/lib.sh"
# The kill emitter (BL-828): a kill is scored only behind the same run's base-pass flag.
. "$(cd "$HERE/../lib" && pwd)/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/partition-review-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/merge-review-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/sprint-status.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
seed_controls

if sg seam; then
# ---------------------------------------------------------------- the in-process seam (EQ1-EQ8)
# Every arm below asks its subject IN PROCESS (lib.sh ip_run). These are the end-to-end runs kept, one per
# distinct CLI outcome of each subject: the same CLI line run in process and as a process must answer
# byte-identically (stdout, stderr, exit code, the files it writes), and the outcomes of one subject must
# differ from each other, so a seam that answered one fixed thing cannot pass.
eq_arm() { # <id> <label> <pair names...>: each pair passed eq_pair (EQP_<name>=1) and their answers pairwise differ
  local id="$1" lbl="$2" a b w=""; shift 2
  for a in "$@"; do eval "[ \"\${EQP_$a:-0}\" = 1 ]" || w="$w $a{$(eval "printf %s \"\${EQW_$a:-not run}\"")}"; done
  for a in "$@"; do for b in "$@"; do
    [ "$a" \< "$b" ] || continue
    ! cmp -s "$WORK/eq-$a.ans" "$WORK/eq-$b.ans" || w="$w $a=$b"
  done; done
  if [ -z "$w" ]; then ok "$id: $lbl"; else bad "$id: the in-process seam differs from the CLI, or two outcomes answered alike:$w"; fi
}
eqp() { # <name> <want rc> eq_pair-args... -> EQP_<name>, EQW_<name>
  local n="$1" want="$2"; shift 2
  if eq_pair "$n" "$@" && [ "$EQ_RC" = "$want" ]; then eval "EQP_$n=1"; else eval "EQP_$n=0; EQW_$n=\"rc=\$EQ_RC want $want\$EQ_WHY\""; fi
}
_eqd="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)"; _eqo="$(out_of "$_eqd")"
EQ_FILES="$_eqo" eqp mrg_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
ip_run -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo" > /dev/null 2>&1 < /dev/null
EQ_FILES="$_eqo" eqp mrg_same 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
rm -f "$_eqo"
EQ_FILES="$_eqo" eqp chk_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --check-shard "$_eqd/1.md"
shard "$_eqd" 2 APPROVED 3
EQ_FILES="$_eqo" eqp chk_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --check-shard "$_eqd/2.md"
EQ_FILES="$_eqo" eqp mrg_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
eq_arm EQ1 "merge-review-shards.sh in process answers byte-for-byte what the CLI does: MERGED (rc 0, the review written), UNCHANGED over its own output (rc 0), REFUSED on a part citing another part (rc 2, nothing written)" mrg_ok mrg_same mrg_no
eq_arm EQ2 "--check-shard in process answers byte-for-byte what the CLI does: SHARD-OK on a clean shard, REFUSED on a part citing another part" chk_ok chk_no
_eqs="$WORK/eq-serial-1-code-review.md"
{ printf '# Code Review: 1\n\n'; adv_l; printf '\n## Summary\nSerial.\n\n## Verdict\nAPPROVED\n\n## Findings\n\nNone.\n'; } > "$_eqs"
eqp ser_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main --check-serial "$_eqs" --gate code-review
printf '\n## Verdict\nBLOCKED\n' >> "$_eqs"
eqp ser_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main --check-serial "$_eqs" --gate code-review
eq_arm EQ3 "--check-serial in process answers byte-for-byte what the CLI does: SERIAL-OK on one APPROVED verdict, REFUSED on two different verdict values" ser_ok ser_no
_eqw="$(mktemp -d "$WORK/eqp.XXXXXX")"
EQ_FILES="$_eqw/sd/.manifest" eqp prt_ok 0 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$_eqw/sd"
eqp prt_ser 3 -e "$KEY=0" "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA"
eqp prt_no 2 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" --max-parts 1
eq_arm EQ4 "partition-review-diff.sh in process answers byte-for-byte what the CLI does: a map and its manifest (rc 0), SERIAL with the key at 0 (rc 3), REFUSED on --max-parts 1 (rc 2)" prt_ok prt_ser prt_no
eqp pdc_ok 0 "$SRCDIR/partition-document.sh" pdoc_main --cross-groups 3
eqp pdc_no 64 "$SRCDIR/partition-document.sh" pdoc_main --cross-groups 1
eq_arm EQ5 "partition-document.sh --cross-groups in process answers byte-for-byte what the CLI does: the K=3 table (rc 0), the USAGE refusal at K=1 (rc 64)" pdc_ok pdc_no
_eqm="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)"
fire "$_eqm/1.md" agent && fire "$_eqm/2.md" agent || bad "EQ6-EQ8: FIXTURE BROKEN -- the recorder wrote no row for the seam world"
EQ_FILES="$_eqm/1.md $LEDGER" eqp mk_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$WFD_SRC" wfd_mark_main --mark "$_eqm/1.md" implementation code-reviewer 1 findings=1
EQ_FILES="$_eqm/2.md $LEDGER" eqp mk_no 64 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$WFD_SRC" wfd_mark_main --mark "$_eqm/2.md" implementation code-reviewer 3 findings=1
eq_arm EQ6 "wait-for-deliverable.sh --mark on a review shard in process (wfd_mark_main) answers byte-for-byte what the CLI does: marked (rc 0, the marker and its ledger row written), refused on a <shard> that is not the file key (rc 64, nothing written)" mk_ok mk_no
eqp seal_ok 0 "$SEAL_SRC" seal_main --review-shard "$_eqm/2.md"
sed -i.bak -e 's/^## Summary$/## Overview/' "$_eqm/2.md" && rm -f "$_eqm/2.md.bak"
eqp seal_no 1 "$SEAL_SRC" seal_main --review-shard "$_eqm/2.md"
eq_arm EQ7 "content-seal.sh --review-shard in process (seal_main) answers byte-for-byte what the CLI does: SEAL-OK on a sealed shard (rc 0), SEAL-REFUSED once a Bash rewrite moved it (rc 1)" seal_ok seal_no
# EQ7b, --first-tool-ts (FT1's mode): a state dir with a gate-part row prints its ts (rc 0); one that does not
# exist is refused (rc 2). The ledger row's ts is fixed so the answer names no clock.
_eqf="$(mktemp -d "$WORK/eqf.XXXXXX")"; mkdir -p "$_eqf/_bmad-output/planning-artifacts"
printf '{"v":1,"kind":"content-seal","ts":"2001-02-03T04:05:06Z","path":"gate-adjudication/g1.part-1.jsonl","actor":"agent","agent_id":"a0123456789abcdef","session":"s","tool":"Write","tool_use_id":"t","transcript_path":"/dev/null","root":"%s","sha256":"0"}\n' \
  "$(cd "$_eqf" && pwd -P)" > "$_eqf/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
eqp fts_ok 0 "$SEAL_SRC" seal_main --first-tool-ts "$_eqf/_bmad-output"
eqp fts_no 2 "$SEAL_SRC" seal_main --first-tool-ts "$_eqf/absent"
eq_arm EQ7b "content-seal.sh --first-tool-ts in process (seal_main) answers byte-for-byte what the CLI does: the earliest tool row's ts (rc 0), and a missing state dir refused (rc 2)" fts_ok fts_no
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"fixture-session","tool_use_id":"toolu_fixture","transcript_path":"/dev/null","agent_id":"a0123456789abcdef","agent_type":"code-reviewer"}\n' "$_eqm/3.md" > "$WORK/eq-hook-row.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"fixture-session","tool_use_id":"toolu_fixture","transcript_path":"/dev/null"}\n' "$WORK/eq-not-sealed.md" > "$WORK/eq-hook-none.json"
EQ_IN="$WORK/eq-hook-row.json" EQ_FILES="$LEDGER" eqp hk_row 0 -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" -
EQ_IN="$WORK/eq-hook-none.json" EQ_FILES="$LEDGER" eqp hk_none 0 -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" -
cp "$WORK/eq-hk_row.ans" "$WORK/eq-hk_row.ans.o"; { cat "$WORK/eq-hk_row.ans.o"; grep -c . "$LEDGER"; } > "$WORK/eq-hk_row.ans"
_hk1="$(grep -c . "$LEDGER")"; EQ_IN="$WORK/eq-hook-row.json" ip_run -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" - < "$WORK/eq-hook-row.json"; _hk2="$(grep -c . "$LEDGER")"
[ "$_hk2" = $((_hk1 + 1)) ] || EQP_hk_row=0 EQW_hk_row="the in-process recorder appended $((_hk2 - _hk1)) row(s), want 1"
# EQ0, the comparison's own control: the same partition pair with ONE argument added on the CLI side only
# (EQ_CLI_TAIL) must be reported as differing, so a comparison that cannot see a difference cannot pass EQ1-EQ8.
if EQ_CLI_TAIL="--max-parts=junk" eq_pair eq0 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA"; then
  bad "EQ0: FIXTURE BROKEN -- eq_pair called a CLI run with an extra argument byte-equal to the in-process run"
else ok "EQ0: eq_pair reports a CLI run given one extra argument as differing from the in-process run (${EQ_WHY# })"; fi
eq_arm EQ8 "the recorder hook sourced in process answers byte-for-byte what the CLI does on a review-shard Write (one ledger row appended) and on a path outside the sealed set (no row)" hk_row hk_none
fi # sg seam

arm() { # <predicate> <label-ok> <label-bad>
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3 (rc=${RC:-?}): $(cat "$MO" 2>/dev/null | head -3)"; fi
}
arm2() { # <predicate> <label-ok> <label-bad> -- the predicate sets WHY to what it saw
  WHY=""
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3:${WHY:- (no reason recorded)}"; fi
}
if sg arms; then
arm part "P1: repo A (all files under app/) partitions to >= 2 parts above --min-files 4, app/ split across parts, no part keyed on bare app/, the docs/reviews/ artifact excluded" \
         "P1: repo A did not partition by adaptive depth"
arm dflt_lo "P2: key unset, no flag, $((DFLT - 1)) reviewable files ($DFLT in the diff, one under a scan root) -> exit 3, 'SERIAL:' naming the built-in default $DFLT and $KEY, no manifest" \
             "P2: below the built-in default did not answer SERIAL naming the default"
arm dflt_hi "P2b: key unset, no flag, exactly $DFLT reviewable files -> partitions to >= 2 parts (the default is ON, and the boundary is inclusive)" \
            "P2b: exactly the built-in default's file count did not partition"
arm off "P2c: $KEY=0, and --min-files 0, each on $DFLT files -> exit 3, 'SERIAL: review sharding is disabled' naming the source, no manifest" \
        "P2c: a zero threshold did not answer SERIAL disabled"
arm refuse_val "P2d: $KEY set but EMPTY, and $KEY=abc -> each REFUSED exit 2 'is not a non-negative integer', no manifest (empty is NOT unset)" \
               "P2d: an empty or non-numeric key was not refused"
arm prec "P2e: --min-files $((DFLT + 1)) with $KEY=4 on $DFLT files -> SERIAL naming --min-files; --min-files 4 with $KEY=$((DFLT + 1)) -> partitions (the flag wins both ways)" \
         "P2e: the key overrode --min-files"
arm dmerge "P2f: a repo of $((DFLT + 2)) files partitioned with the threshold UNSET records a NUMERIC min-files in its manifest and merges end to end (the merge hands it back as --min-files)" \
           "P2f: a default-built partition did not merge, or its manifest did not record the numeric threshold"
arm env_key "P3: the key set to 4 in the environment, no flag -> repo B partitions to >= 2 parts" \
        "P3: the environment threshold did not partition"
arm worst "V1: worst-of -- {B,A,A,xA} merges BLOCKED (cross, last and majority say APPROVED); {NR,B,NR,xA} merges BLOCKED (majority says NR); all-APPROVED merges APPROVED; each read back Check 1's way" \
          "V1: the merged verdict is not the worst shard verdict"
arm c1 "C1: the merged file matches Check 1's derived pattern exactly once and Check 1's read gives NEEDS_REWORK" \
       "C1: the merged file does not match Check 1 exactly once with the right value"
arm conserve "C2: conservation -- a unique token and the finding heading of each of parts 1-3 and cross appear in the merged file" \
             "C2: a shard's content was lost in the merge"
arm miss_ord "R1: part 2 missing -> REFUSED, exit 2, nothing at --out" "R1: a missing part was not refused cleanly"
arm miss_cross "R2: cross.md missing -> REFUSED, exit 2, nothing at --out" "R2: a missing cross shard was not refused cleanly"
arm dup "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing at --out" "R3: a duplicate part was not refused cleanly"
arm part_cite "R4: part 2 reporting a finding citing part 3 -> REFUSED, exit 2, nothing at --out" "R4: a part citing another part was not refused cleanly"
arm cross_one "R5: a cross finding citing one part -> REFUSED, exit 2, nothing at --out" "R5: a one-part cross finding was not refused cleanly"
arm sha_dir "R6: a shard dir named for another sha12 than the manifest's -> REFUSED, exit 2, nothing at --out" "R6: a manifest/dir-name sha mismatch was not refused cleanly"
arm sha_rev "R7: a shard whose reviewed-sha is not the manifest's sha -> REFUSED, exit 2, nothing at --out" "R7: a reviewed-sha mismatch was not refused cleanly"
arm moved "R8: the worktree's scan roots moved after the manifest was written (the re-run still partitions, differently) -> REFUSED 'differs from the map it records', nothing at --out" \
          "R8: a manifest map that no longer matches a re-run partition was not refused cleanly"
arm a3 "R9: a shard body carrying '## Verdict' -> REFUSED on Check 1's count (2), exit 2, nothing at --out" "R9: a shard verdict heading was not refused"
arm rerun "R10: an identical re-merge is UNCHANGED; a re-merge after shard 1 changed -> REFUSED 'never overwritten', exit 2, the first review byte-unchanged" \
          "R10: a re-merge over a different existing review was not refused with the file intact"
arm anc "R11: a base that is not an ancestor of the frozen sha (a sibling commit, same two-dot file set) -> partition REFUSED on stderr, exit 2, no map, no manifest" \
        "R11: a diverged base was partitioned"
arm cross_sha "R12: cross.md whose reviewed-sha is the base -> REFUSED 'not the frozen sha', exit 2, nothing at --out" \
              "R12: a cross shard reviewing another tree was not refused"
arm bad_verdict "R13: 'shard-verdict: PASS' -> REFUSED, exit 2, nothing at --out" "R13: a verdict outside the ranked three was not refused"
arm noparts "R14: a '#### ' finding under ## Findings with no 'parts:' line -> REFUSED, exit 2, nothing at --out" \
            "R14: an uncited finding was not refused"
arm manifest "R15: an identical partition re-run leaves .manifest; a --max-parts 2 re-run (a different map) -> REFUSED 'never overwritten', manifest byte-unchanged" \
             "R15: a differing partition re-run over an existing manifest was not refused with the manifest intact"
arm two_sha "R16: a shard carrying two 'reviewed-sha:' lines (the right one first) -> REFUSED, exit 2, nothing at --out" \
            "R16: a second reviewed-sha line was not refused"
arm default_k "P4: four equal-weight groups and no --max-parts -> exactly 4 parts (the default K)" \
              "P4: the default part ceiling is not 4"
arm stray "R17: a 'parts:' line behind a bullet inside ## Findings, and a '#### ' citing part 3 under '## Critical Issues' beside a real ## Findings -> each REFUSED, exit 2, nothing at --out" \
          "R17: a parts: line outside a '#### ' finding under ## Findings was not refused"
arm nofind "R18: a shard with no '## Findings' section -> REFUSED, exit 2, nothing at --out" "R18: a shard without ## Findings was merged"
arm knob "R19: --min-files, the env key and --max-parts at 18446744073709551617 -> each REFUSED 'longer than 9 digits', no manifest; a 9-digit --min-files answers SERIAL" \
         "R19: a value over 9 digits was not refused before arithmetic"
arm fence_nested "R20: a '#### ' finding inside a four-backtick fence holding a three-backtick block is not counted -> MERGED with the base world's findings count" \
                 "R20: a four-backtick fence closed on the inner three-backtick line and the fenced finding was counted"
arm q_worst "Q1: --gate qa worst-of -- all PASS merges PASS; one part NEEDS_REWORK (cross PASS) merges NEEDS_REWORK; cross NEEDS_REWORK (parts PASS) merges NEEDS_REWORK; each read back Check 1's way" \
            "Q1: the merged QA verdict is not the worst shard verdict"
arm q_table "Q2: a cross shard carrying a '| AC | Verdict |' table under '## Acceptance Criteria' merges with exactly one Check-1 match, every shard's token and finding conserved" \
            "Q2: a QA cross shard with a per-AC table did not merge to exactly one Check-1 match"
arm q_title "Q3: the merged title is '# Code Review: 1 (merged from 4 shards)' for gate 1 and '# QA Validation: 1 (merged from 4 shards)' for gate 2" \
            "Q3: a merged title does not name its gate"
arm q_fenced "Q4: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges (the section refusals skip fenced text)" \
             "Q4: a fenced section heading in a part shard was refused"
arm q_part_ac "Q5: a part shard carrying '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q5: a part shard's per-AC section was merged"
arm q_part_def "Q6: a part shard carrying '## Deferred ACs' -> REFUSED, exit 2, nothing at --out" "Q6: a part shard's deferred-AC section was merged"
arm q_cross_noac "Q7: cross.md without '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q7: a cross shard with no per-AC section was merged"
arm q_cross_twoac "Q8: cross.md with two '## Acceptance Criteria' sections -> REFUSED, exit 2, nothing at --out" "Q8: a cross shard with two per-AC sections was merged"
arm q_cross_twodef "Q9: cross.md with two '## Deferred ACs' sections -> REFUSED, exit 2, nothing at --out" "Q9: a cross shard with two deferred-AC sections was merged"
arm q_nodef "Q10: cross.md with NO '## Deferred ACs' merges (at most one, not exactly one)" "Q10: a cross shard without a deferred-AC section was refused"
arm q_rank "Q11: a qa shard carrying 'shard-verdict: APPROVED' -> REFUSED, exit 2 (gate 1's set is not gate 2's)" "Q11: a gate-1 verdict was ranked under --gate qa"
arm q_pm "Q12: pass markers, both gates -- dir -p2 with --out -p2 merges, dir -p2 with an unmarked --out and an unmarked dir with --out -p2 refuse (qa); the same three cells for code-review at -p3/-p2" \
         "Q12: a shard directory's pass marker and --out's disagree and the merge went ahead, or agree and it refused"
arm q_suffix "Q13: a <idx>-code-review-<sha12> dir merged --gate qa, and a <idx>-qa-validation-<sha12> dir merged --gate code-review -> each REFUSED, nothing at --out" \
             "Q13: a shard directory of the other gate was merged"
arm q_gate "Q14: --gate deploy -> REFUSED, exit 2, nothing at --out" "Q14: an unknown gate was not refused"
arm q_vset "Q15: qa.md declaring a third verdict -> --gate qa REFUSED; code-reviewer.md declaring a fourth -> --gate qa still merges PASS and --gate code-review refuses (QA's set is lifted from qa.md)" \
           "Q15: QA's verdict set is not lifted from qa.md alone"
arm q_secvar "Q16: part shards carrying '## Acceptance Criteria:', '##  Acceptance Criteria', '## acceptance criteria', '### ACCEPTANCE CRITERIA', '### Deferred ACs', '## Deferred / operator-owned', '## deferred acs', and a cross shard with a second '## Acceptance Criteria:' -> each REFUSED; the variants inside a fence and '#### ' findings titled with a section name merge" \
             "Q16: a section-heading variant escaped the count, or a fenced variant or a '#### ' finding was counted"
arm q_ho_ok "H1: part 2's 'handover: AC7' matched by cross's 'handover-run: 2 AC7 RED' merges PASS (the shard verdicts' worst-of), read back Check 1's way, the replay tabled" \
            "H1: a matched RED hand-over did not merge at the shard verdicts' worst-of"
arm q_ho_unm "H2: part 2's 'handover: AC7' with no 'handover-run:' in cross.md -> REFUSED naming '2 AC7', exit 2, nothing at --out" \
             "H2: an unmatched hand-over was merged -- its HARD GATE replay was run by nobody"
arm q_ho_orph "H3: cross.md's 'handover-run: 2 AC7 RED' with no hand-over in part 2 -> REFUSED, exit 2, nothing at --out" \
              "H3: an orphan handover-run was merged"
arm q_ho_force "H4: 'handover-run: 2 AC7 GREEN-SURVIVED', and NO-BASELINE, each over four PASS shards -> merges NEEDS_REWORK, read back Check 1's way" \
               "H4: an unmet hand-over replay did not force NEEDS_REWORK"
arm q_ho_cross "H5: a 'handover:' line in cross.md -> REFUSED, exit 2, nothing at --out" "H5: a cross-shard hand-over was merged"
arm q_ho_prun "H6: a 'handover-run:' line in part shard 3 -> REFUSED, exit 2, nothing at --out" "H6: a part-shard handover-run was merged"
arm q_ho_fenced "H7: 'handover: AC7' fenced in part 2 and 'handover-run: 2 AC9 GREEN-SURVIVED' fenced in cross merge PASS (neither is counted)" \
                "H7: a fenced hand-over line was counted"
arm q_ho_shape "H8: a replay finding citing '1, 2' for a part-2 replay, and a bulleted '- handover: AC7', each REFUSED" \
               "H8: a mis-cited replay finding or a bulleted hand-over was merged"
arm q_ho_multi "H9: part 2's 'handover: AC7 AC8' with only 'handover-run: 2 AC7 RED' in cross.md -> REFUSED 'names more than one AC', nothing at --out" \
               "H9: a two-AC hand-over line was merged -- the second AC's replay is run by nobody"
arm q_ho_twoline "H10: two 'handover:' lines in one part-2 finding, both run -> REFUSED on the per-finding count, nothing at --out" \
                 "H10: a finding carrying two hand-over lines was merged"
arm q_ho_dup "H11: two part-2 findings each 'handover: AC7', run once -> REFUSED 'handed over more than once', nothing at --out" \
             "H11: a duplicate hand-over was merged"
arm q_ho_deco "H12: '**handover:** AC7', '*handover*: AC7', a backtick-quoted and a '>'-quoted hand-over, 'hand-over: AC7', and the same for handover-run -> each REFUSED as a malformed hand-over" \
              "H12: a decorated, quoted or hyphenated hand-over line was merged -- the AC dropped with no replay owed"
arm q_ho_nocolon "H13: 'handover - AC7', 'handover AC7', 'handover-run 2 AC7 RED' and 'handover-run - 2 AC7 RED' at column 0 -> each REFUSED as a malformed hand-over" \
                 "H13: a column-0 hand-over missing its colon was merged"
arm q_ho_prose "H14: prose naming the hand-over at column 0 ('The handover step ...', 'Handover to the cross shard: none ...', 'Handover step', 'hand-over is not owed') merges PASS" \
               "H14: prose about the hand-over was refused as a malformed hand-over line"
arm q_ho_acid "H15: an empty 'handover:' (recorded as '-') and 'handover: .', each with its matching run -> REFUSED, an <AC-id> begins with a letter or digit" \
              "H15: a hand-over naming no AC was merged"
arm q_hc_dash "H16: part 2 declaring 'handovers: 1' with its hand-over written 'handover — AC7' (em dash, unparsed) -> REFUSED on the count mismatch, nothing at --out" \
              "H16: an em-dash hand-over under a declared count of 1 was not refused on the count"
arm q_hc_hidden "H17: 'handovers: 1' with the hand-over as a pipe-table row and as an HTML comment (forms the malformed-line pattern does not match) -> each REFUSED on the count mismatch" \
                "H17: a hand-over the malformed-line pattern cannot see merged with no replay owed"
arm q_hc_zero "H18: 'handovers: 0' over a correct, run 'handover: AC7' -> REFUSED on the count mismatch" \
              "H18: a declared count of 0 over a parsed hand-over was merged"
arm q_hc_missing "H19: a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                 "H19: a part shard without its declared hand-over count was merged"
arm q_hc_two "H20: a part shard with two 'handovers:' lines -> REFUSED, nothing at --out" \
             "H20: a part shard declaring its hand-over count twice was merged"
arm q_hc_nonint "H21: 'handovers: x', '-1', 2^64, and '?' / '[1]' from a cwd holding files 0 and 1 -> each REFUSED as not a non-negative integer" \
                "H21: a non-integer hand-over count was merged"
arm q_hc_cross "H22: a 'handovers:' line in cross.md -> REFUSED, nothing at --out" \
               "H22: a cross shard declaring a hand-over count was merged"
arm q_hc_none "H23: every part shard 'handovers: 0', cross.md with none, no hand-over anywhere -> merges PASS, read back Check 1's way" \
              "H23: a world with no hand-overs and correct zero counts was refused"
arm q_ho_widen "H24: under 'handovers: 0', 'handover' followed by an em dash, en dash, '=', '->', a trailing reason, a parenthesised reason, a '1. ' list prefix (bare and bold), and 'handover-run —' -> each REFUSED as a malformed hand-over" \
               "H24: a hand-over spelling the widened malformed-line pattern names was merged"
arm x_k8 "X1: K=8 -- eight parts and cross-1..6 (one per --cross-groups row) merge, titled 'merged from 14 shards', one body header per group" \
         "X1: a K=8 shard dir with every cross group was not merged as fourteen shards"
arm2 x_lone "X2: ONE cross.md in place of the groups at K>2 is ACCEPTED (BL-811) -- K=8 merges titled 9 shards, the parts then '## Shard: cross' last, a 1, 2 finding owned by it; a partial cross-1..5 set at K=8 REFUSED naming cross-6" \
          "X2: the lone cross shard at K>2 was refused, mis-merged, or a partial cross-<g> set was merged"
arm2 x_mix "X3: cross.md beside cross-1..3 -> REFUSED as a mix, nothing at --out" "X3: cross.md and cross-<g>.md merged together"
arm x_unknown "X4: cross-4 at K=3, and cross-1.md in place of cross.md at K=2 -> each REFUSED as a group --cross-groups does not print" \
              "X4: a cross shard naming a group the table does not print was merged"
arm x_owner "X5: K=8, a finding citing 1, 2 in cross-3 AND in its owner cross-1 -> REFUSED naming the owner; 1, 2, 7 in cross-3 alone merges, count +1; the same finding in cross-1 merges and the finding count rises by one" \
            "X5: a cross finding reported by a group that does not own it was merged, or its owner's copy was refused"
arm x_actable "X6: --gate qa, the per-AC table in cross-2 and the deferred record in cross-3 -> each REFUSED, only cross-1 writes them" \
              "X6: a per-AC table or deferred record outside cross-1 was merged"
arm x_horun "X7: --gate qa, part 2's hand-over replayed by cross-2 rather than cross-1 -> REFUSED, only cross-1 runs a replay" \
            "X7: a hand-over replayed by a cross group other than the execution owner was merged"
arm x_k2 "X8: K=2 -- cross.md merges under both gates, titled 'merged from 3 shards', its body header '## Shard: cross'" \
         "X8: a K=2 shard dir with its one cross.md did not merge as before"
arm x_seat "X9: one shard without 'seat-complete:' beside shards with it, a marker that is not the last non-blank line, and findings=3 over 1 finding -> each REFUSED; every shard ending in it (blank lines after) merges, the marker dropped" \
           "X9: an unfinished shard was merged beside finished ones, or finished shards were refused"
arm cr_ho_ok "G1: --gate code-review, parts 1 and 2 each hand over a disjoint replay, cross-1 runs both once -> merges APPROVED with both tabled; AC7 GREEN-SURVIVED merges NEEDS_REWORK" \
             "G1: gate-1 hand-overs owned by two parts and run once each did not merge, or an unmet replay did not force NEEDS_REWORK"
arm cr_ho_block "G2: --gate code-review, every shard BLOCKED and a NO-BASELINE replay -> merges BLOCKED (the forced NEEDS_REWORK never lowers a verdict)" \
                "G2: an unmet replay lowered a BLOCKED review to NEEDS_REWORK"
arm cr_ho_unm "G3: --gate code-review, part 2's hand-over run by no shard -> REFUSED, nothing at --out" \
              "G3: a gate-1 hand-over handed to no replay was merged"
arm cr_ho_runtwice "G4: --gate code-review, one hand-over replayed twice by cross-1 -> REFUSED 'more than one handover-run', nothing at --out" \
                   "G4: a hand-over replayed twice was merged"
arm cr_hc_missing "G5: --gate code-review, a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                  "G5: a gate-1 part shard without its declared hand-over count was merged"
fi # sg arms

if sg bl737; then
# ------------------------------------------------------------------------------------ BL-737
# Each predicate sets WHY to what it saw. A predicate that never ran leaves no `ok` line, so every arm
# here is presence-shaped: the receipt counts these labels' `ok` lines, never the exit alone. arm2
# itself is defined beside arm, above, because X2 and X3 use it too.
arm2 cs "CS1: --check-shard prints the full merge's REFUSED line byte-for-byte, the physical path through a symlinked alias, for $CS_N single-defect worlds (every per-shard class under both gates, the marker count, key= and <shard>, and the content seal; qa includes graph's '## Deferred live check (not scored here)' part heading); a clean shard answers SHARD-OK" \
         "CS1: --check-shard's verdict is not the merge's own"
arm2 copies "CP1: has_marker, content_hash, seal_body and seal_of in merge-review-shards.sh, and content-seal.sh's seal_review_body body, are byte-identical to wait-for-deliverable.sh's, extracted by name, and a one-byte drift in either copy is seen" \
             "CP1: the merge's copy of the seal reader is not wait-for-deliverable.sh's"
arm2 owner "OT1: every refusal family's owner tail names the shard whose file must change -- per-shard, missing, unfinished, duplicate key (both files), hand-over join (part and cross-1), hand-over twice, replay twice, Check-1 multi-match, bad name and set-level (lead); the owner duplicate names the NON-owner, and --check-shard over the non-owner answers SHARD-OK while its owner is unsealed" \
           "OT1: an owner tail names the wrong shard"
arm2 key "KY1: a set every seat wrote and --mark closed merges with each marker keyed by its own file name; a marker key= naming another shard, and a <shard> field naming another, each REFUSED [owner: 2]" \
         "KY1: the marker key check accepts a key that is not the file's, or refuses the right one"
arm2 mark "MK1: --mark on a review shard refuses a <shard> that is not the file key, a caller key= and a caller sha= word, and findings=3 over 1 finding -- each exit 64, the file byte-unchanged -- and the same call with the right fields marks it 'key=2'" \
          "MK1: --mark marked a review shard it should have refused, or refused the right call"
arm2 seal_rewrite "SE1: a qa part shard its seat wrote and marked reads SEAL-OK; rewritten by an in-place sed rewrite and re-marked, --mark refuses (64) with the re-dispatch remedy, the file unchanged" \
                  "SE1: a Bash-rewritten review shard was re-marked"
arm2 session "SE2: a seat-sealed set merges; after a top-level-session Edit row on shard 2 the merge REFUSES it [owner: 2]; after an agent Edit row it merges again" \
             "SE2: a shard last written by the session was merged, or the agent's re-write refused"
arm2 legacy "LG1: legacy markers over an old engine merge with the exact 'LEGACY: ... reviewed sha <full sha> predates the key= engine' line per shard (a Write then the old Bash append accepted on body_sha); the same Write then a sed rewrite, the sentinel engine at the frozen sha, and an engine in neither layout each REFUSED" \
            "LG1: the legacy rule acquitted what it should refuse, or refused a legitimate legacy shard"
arm2 layouts "LY1: from a linked worktree the seal reader names the MAIN checkout's ledger in a distribution-layout and a consumer-layout tree (never the worktree's own decoy); the recorder fired there writes MAIN's ledger, both readers read SEAL-OK, and a set sealed there merges" \
             "LY1: the review-shard ledger is not the main checkout's from a linked worktree"
arm2 first_ts "FT1: a review-shard row written before a gate part does not move --first-tool-ts; the same row without body_sha does" \
              "FT1: a review-shard row moved --first-tool-ts, or the control did not"
arm2 env "EV1: on a PATH built from tools.decl without jq, a seat-sealed set is REFUSED 'SEAL-UNAVAILABLE' [owner: lead] with no re-dispatch, and --mark exits 64 relaying it with the environment remedy, the file unchanged; the same set with jq added back merges" \
         "EV1: an environment that cannot read the seal was charged to a reviewer, or the jq control did not merge"
arm2 unmarked "UM1: adv-strip.sh's input -- every seat-complete line stripped, one verdict rewritten by sed -- over a sentinel-engine frozen sha with no seal rows is REFUSED 'carries no content-seal row'; the same steps over the old engine merge" \
              "UM1: an unmarked set over the key= engine merged without a seal row, or the old-engine control was refused"

# ------------------------------------------------------------------------------------ BL-740
# VERDICT BACKING. Every refusal is driven through the merge AND --check-shard, the two REFUSED lines
# byte-equal; every pass merges and answers SHARD-OK. Each cell writes its own WHY token.
arm2 vb_cr "VB1: --gate code-review -- NEEDS_REWORK with the empty findings template REFUSED with the stem, NEEDS_REWORK with one Important merges, BLOCKED with one Critical merges, BLOCKED with only a Suggestion REFUSED, APPROVED with a Critical REFUSED, APPROVED with an Important merges; each refusal byte-equal under --check-shard" \
           "VB1: a code-review verdict was not held to its own findings"
arm2 vb_qmode "VB2M: --gate qa over qa.md's three containers -- NEEDS_REWORK backed only by a Suggestions finding REFUSED, the severity mode alone (M12's one cell)" \
              "VB2M: QA verdict backing stayed count-only over a three-container qa.md"
arm2 vb_qa "VB2: --gate qa over qa.md's three containers -- NEEDS_REWORK with 0 findings REFUSED; with an Important finding merges, no LEGACY line; PASS with a Critical REFUSED, with an Important merges; a finding under no container REFUSED as unclassed; each refusal byte-equal under --check-shard" \
           "VB2: a qa verdict was not held to its own findings' severity"
arm2 vb_qleg "VB2L: --gate qa over a qa.md declaring NO container (a consumer between pull step 3 and the reconcile merge) -- the LEGACY count-only line and an uncontained NEEDS_REWORK finding merge; a qa.md declaring TWO containers REFUSED [owner: lead]; the code-review gate under that root still refuses an unclassed finding" \
             "VB2L: the zero-container fallback is not count-only, or a two-container qa.md was read"
arm2 fr_verdict "FR1: --gate qa, cross-1's per-AC table -- a PASS merge over an AC4 row reading FAIL, and FAIL under a Result column moved to position 3, each REFUSED [owner: cross-1]; FAIL only in Expected/Got, and all-PASS rows, merge PASS; NEEDS_REWORK carried by part 2's finding naming AC4 merges" \
                 "FR1: a QA merge read PASS over a per-AC FAIL row, or refused a row that does not fail"
arm2 fr_orphan "FR2: a FAIL row under a NEEDS_REWORK merge whose AC no '#### ' finding names is REFUSED as an orphan (the table's own mention does not count), a finding naming only AC10 does not name AC1; a finding naming AC1 beside AC10 merges" \
               "FR2: an orphan per-AC FAIL row merged, or the AC id matched as a substring"
arm2 fr_graph "FR4: graph 811ad3d7d story 3.1 qa p2 as two states, frozen over a tree whose INSTALLED qa.md declares no container and judged by today's -- cross-1 PASS with an AC4 FAIL row and the NEEDS_REWORK cross shard carrying only its AC10 finding REFUSED as an orphan FAIL row [owner: cross-1] (not the FAIL-under-PASS rule); with its hand-added uncontained AC4 finding the set merges NEEDS_REWORK with the severity-boundary LEGACY line naming cross-2" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_bound "FRB: the severity boundary is read off qa.md AS INSTALLED AT THE FROZEN SHA -- graph's post-F2 set frozen over a container-less installed qa.md merges NEEDS_REWORK with the LEGACY line; frozen over the three-container one REFUSED unclassed [owner: cross-2], no LEGACY line; frozen over a tree installing no qa.md (unreadable) REFUSED the same way" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_remedy "FR3: the orphan remedy is satisfiable -- cross-1 filing the AC4 finding under cross-2's own parts set is the owner-duplicate refusal, under a set cross-1 owns it merges, and the owning cross-2 naming AC4 in its own finding merges" \
               "FR3: the orphan FAIL row's remedy cannot be satisfied under the owner rule"
arm2 serial "SR1: --check-serial, gate 3's Check 1 rule and no stricter -- '## Verdict / PASS', 'Verdict: NEEDS_REWORK', 'Verdict: PASS (all ACs)', '## Verdict / PASS.' and two matches both reading PASS answer SERIAL-OK; the heading-then-'Verdict: PASS' union and two different values, 'PASS-pending', APPROVED under --gate qa, a renamed '## Result' code review (0 matches), a PASS over a FAIL or FAILED row (the latter under '### Acceptance criteria'), and FAIL rows named only by 'AC-4.1' or a 'handover:' line each REFUSED [owner: serial]; code-review APPROVED and a backed NEEDS_REWORK FAIL row answer SERIAL-OK" \
             "SR1: --check-serial accepted a malformed serial verdict, or refused a correct one"
fi # sg bl737
if sg canon; then
arm2 canon "CR1: --check-serial --gate qa, a PASS waits for its canonical run -- the run line plus a counted result, a bulleted pair and a '-p no:cacheprovider' near-miss answer SERIAL-OK; no run line, counts only on a RED replay line, -k, a path root and a marker the conventions do not declare, no result line, a NOT FINISHED result and a result with no count each REFUSED [owner: serial]; NEEDS_REWORK with no run SERIAL-OK; 'none, <reason>' over a record-only --range SERIAL-OK, over a range touching a test, a test module under test-results/, a seat-narrowed rework range, and a non-ancestor base, and with no range REFUSED; BL-895 STORY-BIND: a typo or a directory --story, a review-like file created in a record-only range, a listed story whose index is not the review's, a fresh story under the review's index listed under another key, and a review index that is a prefix of the story's (2 for story-2-1-y.md) REFUSED; the listed story whose row exists only at the frozen sha (not HEAD), under a -p2 review name, SERIAL-OK; N/A, TBD and skipped held to the same partition (refused over code); a bare none REFUSED; -m unit accepted with no conventions and declared, a declared path root accepted; a root whose qa.md lacks the sentinel prints LEGACY and accepts" \
           "CR1: --check-serial accepted a PASS with no canonical run, or refused a correct one"
arm2 wv955 "WV955: the canonical-run waiver -- 'Canonical run: none, AC3 waives it' over a code range whose story carries the AC3 '## Canonical-run waivers' entry at a lead-written base SERIAL-OK (the lead's --lead-range over a recorded dispatch) and MERGED (the qa merge under the lead's partition record); no entry at either end, and the entry added only inside the range, REFUSED not record-only; the same world over the seat's --range and an unrecorded --lead-range REFUSED naming --record-dispatch, and the unrecorded merge REFUSED naming --record-partition; a waived claim whose --story is another (waived) story REFUSED by STORY-BIND [owner: serial]" \
           "WV955: canon_gate did not honour a base-time waiver over a lead-written base only"
arm2 bind956 "BIND956 (BL-956): STORY-BIND binds the bare review index through the implementation view's row -- 6-qa-validation.md binds story-1-6-a.md when row story-1-6 names it at the frozen sha, as a no-run and as a run claim (SERIAL-OK); a row naming another file, no row and a row keyed story-1-7 each REFUSED at the index on both claims; a second entry keyed story-6 in another directory REFUSED by the one-story loop, and a historic row story-1-6 naming story-q.md REFUSED by the view's history; --story story-1-1-x.md bound by a frozen row the range re-keyed to story-1-6 (story 6 absent or key-only at the base) REFUSED by the history's re-key check, which holds --story's pairs to the index from --base to frozen, so a story the lead re-keyed from story-1-7 before the base binds (SERIAL-OK); stem-names in sprint 3 reads story-3-3 as index 3 and story-3-1-3 as 1-3; receipt-bl956.sh (sprint 3, epic 1) holds its four cells" \
             "BIND956: STORY-BIND did not bind the bare index through the view's row, or bound one it must refuse"
fi # sg canon
if sg canon_merge; then
arm2 canon_merge "CR2: the qa merge -- four PASS shards carrying the run merge with no LEGACY line; the execution owner's run lines removed REFUSED [owner: cross-1]; the same with a NEEDS_REWORK part merges NEEDS_REWORK; frozen over an installed qa.md with no label, LEGACY and merges; qa.md untracked at the frozen sha and on disk without the label LEGACY, with it held; --range on the merge REFUSED; BL-895: a record-only sharded diff whose execution owner claims none, with a non-story --story, REFUSED naming that owner; with the listed story MERGED" \
                 "CR2: the merge did not hold the execution owner's PASS to its canonical run, or held a legacy set"
fi # sg canon_merge
if sg bl885; then
arm2 story_path "BL-885 STORY PATH: record-only-diff.sh's story-base and paths resolve an absolute story spelled through a symlink, its physical spelling under a link-spelled -C, './' and './/' to the repo-relative story (status: review at the base -> 1; a story-only diff RECORD-ONLY, a diff adding app.py NOT-RECORD-ONLY naming it); /etc/hosts, 'stories/./s.md', 'stories//s.md', 'stories/../stories/s.md' and '' are exit 2 UNEVALUABLE (receipt-bl885.sh, all $SP_CELLS cells)" \
                "BL-885 STORY PATH: record-only-diff.sh resolved a story path wrongly"
arm2 story_frozen "BL-885 STORY FROZEN: record-only-diff.sh's story-base with the third operand <frozen> -- a typo, '<top>/.git/HEAD' and '.git/HEAD' (no file at the base or at the frozen sha), 'stories' (a tree at the base) and 'stories/later' (absent at the base, a tree at the frozen sha) exit 2 UNEVALUABLE; a story created after the base exits 0, one at status: review at the base 1; the two-operand typo keeps the old 0 (receipt-bl885-frozen.sh, all $SF_CELLS cells)" \
                  "BL-885 STORY FROZEN: record-only-diff.sh's story-base read a story that is no file as a gate-1 base, or refused a real one"
arm2 lead_rec "LR1: the lead's partition record (U1l) -- no record: LEGACY-UNRECORDED and MERGED; --record-partition's record read back by the merge MERGED; a record whose sha or base (a seat-moved .manifest) differs REFUSED [owner: lead]; a held era REFUSES a none claim over code in range though the range strips qa.md's sentinel (9a), a legacy era merges LEGACY; a run claim with the wrong --story REFUSED STORY-BIND on the merge and --check-serial, the right one accepted" \
              "LR1: the merge did not decide from the lead's partition record, or a run claim's --story went unbound"
# BL-790: THE ADVISOR LINE, per shard under both gates and through --check-serial, its absence keyed on
# the gate's role file AT THE FROZEN SHA (lead worlds a and b; the untracked fallback refuses).
AD_ARM="the sentinel world: absent REFUSED [owner: 1] naming the role file that prescribes it, called, unavailable and 'unavailable' with trailing blanks and CR merge with no LEGACY line, maybe, two lines, '- advisor: called' (naming the remediator near-miss) and '**advisor:** called' REFUSED; a fenced 'advisor: maybe' above the bare line, and graph's prose 'Advisor: ...' line beside it, merge; a role file at the frozen sha without the sentinel accepts the absence, and that prose line alone, with the LEGACY line by value and still refuses maybe; a role file unreadable at the sha REFUSED; world (a), frozen over the old role file with the new one on disk, LEGACY and merges; world (b), frozen over the new one with the old on disk, REFUSED; untracked at the sha with the new copy on disk REFUSED naming the on-disk fallback and the commit remedy, with the old copy on disk LEGACY naming it"
arm2 adv_qa "AD1: --gate qa -- $AD_ARM" "AD1: the qa merge did not hold the advisor line to its era"
arm2 adv_cr "AD2: --gate code-review -- $AD_ARM" "AD2: the code-review merge did not hold the advisor line to its era"
arm2 lead "LR1: the lead's re-run (--check-serial --lead-range <seat base> <go-signal sha>, its base the dispatch record --record-dispatch wrote) -- the writer prints RECORDED, keeps the first value on a second call (RECORD-KEPT) and its record reads back SERIAL-OK; the real world SERIAL-OK with no LEGACY line; no record SERIAL-OK with exactly one LEGACY-UNRECORDED line; a go-signal not descending from the recorded dispatch sha (a3's orphan pair), a pre-prescription seat base beside the record, a missing reviewed-sha line with the live sprint ref rewound to a pre-prescription commit, a reviewed-sha naming another sha, and a qa.md whose reviewed-sha prescription is stripped inside the range each REFUSED [owner: serial]; a dispatch sha whose qa.md prescribes neither line SERIAL-OK with the LEGACY reviewed-sha line; the review repository's working-tree qa.md edited to drop the canonical-run label never LEGACY and REFUSED; s1x, s1.Ab12, foo/s1, a symlink spelled s2 onto s1 and a relative path REFUSED by the physical slot; the seat's own run under docs/reviews/s1x/ REFUSED as carrying no sprint; a letter-led index (B1) RECORDED by --record-dispatch and read back SERIAL-OK by the lead's re-run, a slug index (5-browser-smoke) RECORDED, and s1-a/b, s1-.. and s1--x REFUSED with no record written" \
           "LR1: the lead's re-run accepted a review bound to a range, path or qa.md the lead did not choose, or refused the real one"
# LR0 (BL-906): the shared LR_D record. Exactly two subject writes of it over SRCDIR, the second byte-identical to the
# first in record and output, and at least one later cell served from those bytes: a share that never served, or served
# without the proof, fails here rather than reading like a cache that saved nothing.
if [ "$LR_REC_N" = 2 ] && [ "$LR_REC_PROOF" = 1 ] && [ "$LR_REC_HITS" -ge 1 ]; then
  ok "LR0: the lead cells' LR_D record is written by the subject twice, byte-identical, and served to $LR_REC_HITS later SRCDIR cells from those bytes"
else bad "LR0: the shared LR_D record read writes=$LR_REC_N proof=$LR_REC_PROOF served=$LR_REC_HITS, want 2, 1 and at least 1"; fi
arm2 adv_serial "AD3: --check-serial under both gates, over the installed role file carrying the sentinel -- absent, maybe, two lines and '- advisor: called' REFUSED [owner: serial], called, unavailable, a trailing CR and a fenced 'advisor: maybe' above the bare line SERIAL-OK; over a root whose role files lack it, absent SERIAL-OK with the LEGACY line by value" \
                 "AD3: --check-serial did not hold the advisor line to the installed role file's era"
# SR2 (BL-742 role text): qa.md's and code-reviewer.md's serial passages each name the --check-serial
# call; offenders with the step removed from either file are refused.
grep -vF -- "$SR_ROLE_CMD <validation file> --gate qa" "$QA_MD" > "$WORK/sr-qa-nostep.md"
grep -vF -- "$SR_ROLE_CMD <review file> --gate code-review" "$ROLE_MD" > "$WORK/sr-cr-nostep.md"
if cmp -s "$QA_MD" "$WORK/sr-qa-nostep.md" || cmp -s "$ROLE_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE STALE -- a serial-step offender's edit matched nothing, so the predicate would score the shipped text"
elif ! p_serial_role "$QA_MD" "$ROLE_MD"; then
  bad "SR2: qa.md or code-reviewer.md does not tell its serial seat to run --check-serial before returning"
elif p_serial_role "$WORK/sr-qa-nostep.md" "$ROLE_MD" || p_serial_role "$QA_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE BROKEN -- the serial-step predicate passed a role file with the step removed"
else
  ok "SR2: qa.md and code-reviewer.md each tell the serial seat to run merge-review-shards.sh --check-serial before returning; with the step removed from either, refused"
fi
arm2 qclass "QC1: --gate qa, the Class line lifted from qa.md -- a part shard's 'Class: FOO' REFUSED byte-equal under --check-shard naming qa.md's set, 'Class: EVIDENCE' merges and is SHARD-OK, and over a qa.md declaring no Class template the FOO shard merges and is SHARD-OK (nothing checked)" \
             "QC1: the qa merge did not hold the Class line to qa.md's template, or checked one with no template"
fi # sg bl885
if sg story_hist; then
arm2 story_hist "BL-904 STORY HISTORY: record-only-diff.sh's story-base refuses (1, 'existed before') a base where the story was \`git rm\`'d and later re-added, under both operand forms and behind a merge whose first-parent side never held it (plain rev-list hides that deletion); a story never in the base's history exits 0 under both forms, one at status: review at the base 1, a shallow repository exits 2, and a deleted-and-re-added story asked with -C a subdirectory refuses as from the top (receipt-bl904.sh, all \$SH_CELLS cells)" \
                "BL-904 STORY HISTORY: record-only-diff.sh's story-base read a deleted-and-re-added story as created after the base, or refused one that never existed"
fi # sg story_hist
if sg run_rec; then
arm2 run_rec "RR1 (BL-905): the canonical run is bound to a recorded run -- in a held era (qa.md at the base prescribes --record-run) a typed run and result with no record REFUSED [owner: cross], the same pair over a qa.md without the sentinel MERGED with one LEGACY line; --record-run's RECORDED-RESULT copied verbatim MERGED; a recorded run behind a Canonical run: naming another invocation REFUSED naming both, a recorded invocation RUN-FILTER narrows REFUSED; a verbose run cut off at a per-test progress line records nothing, pytest's session line is the summary over a later log line carrying a count, quiet output's own count line is the summary; this pass's run at another sha over code REFUSED, an earlier pass's run at the frozen sha MERGED with no --story, one at a sha whose change since is record-only MERGED, one whose change since touches code REFUSED naming the predicate's line; --record-run with the frozen worktree at another HEAD refused recording nothing, a runner exiting 1 after a summary recorded with exit 1, no summary refused recording nothing; a none claim needs no record;  serial --record-run with the worktree at another sha than --frozen refused recording nothing; the lead's --lead-range over a run recorded at another sha than the go-signal REFUSED; the lead's --lead-range over a base whose tracked qa.md lacks the sentinel SERIAL-OK with one LEGACY line though the installed qa.md carries it; a recorded run whose argv carries a quoted multi-word marker the conventions declare canonical recorded as the one shell line the Canonical run: copies, and MERGED, its bare-word twin MERGED; the lead's --lead-range over a base whose tracked qa.md lacks the canonical-run label SERIAL-OK with one canonical LEGACY line though the installed qa.md carries it, the seat's own form over the same file REFUSED" \
             "RR1: a canonical result was accepted with no run recorded at the frozen sha, or a recorded one refused"
arm2 wrap "WR1 (BL-988): a conventions-declared wrapper is one canonical-run language for record and check -- RUN-FILTER passes the declared stub wrapper with its declared options and a declared payload and RUN-SHAPE reads it as a run; an undeclared wrapper, a relative evil/ spelling of the declared one, no conventions file and a conventions file declaring no wrapper each read exactly as at base; a positional before the bare --, --adm, the prefix --pyth of --python, --admit-only and --prelude (also beside an option value ending in pytest) are refused naming the token, a filtered pytest run ahead of a wrapper run on one line keeps its refusal, an undeclared payload sub-path, -m slow and -k refused as pytest's own arguments; --prelude beside a count is still a run (RUN-SHAPE only widens); git checkout -- <file> and npm test -- --watch declare nothing; a quoted '--junitxml=x>y' is no shell operator, so the test file after it is refused, plain and in a wrapper payload; the conventions span an earlier draft looped on reads a run under a CPU and wall kill switch; --record-run records the declared wrapper (its stub's sentinel present) and --check-serial over its RECORDED-RUN copy reads SERIAL-OK with no LEGACY line, the same record behind a tampered Canonical result: count REFUSED; an undeclared wrapper and a run RUN-FILTER refuses are each REFUSED before anything runs, the sentinel absent and nothing recorded, while a program only RUN-SHAPE refuses is recorded as at base (the pre-check is RUN-FILTER alone, run_bind's own check); BL-988's receipt passes" \
          "WR1: a declared wrapper was refused, an undeclared or narrowed one accepted, the base reading moved without a declaration, the declaration read did not end, or --record-run ran or recorded what its check half refuses"
fi # sg run_rec
if sg files; then
arm2 files "FL1: the Files: line -- a CODE finding naming two paths tracked at the frozen sha is SHARD-OK; Files: on an EVIDENCE finding, two Files: lines, an empty list, a backticked entry, a ':line' entry and a path tracked nowhere are each REFUSED by --check-shard naming the line; a path the range deleted is SHARD-OK (fl-del)" \
           "FL1: --check-shard did not hold the Files: line to its grammar"
fi # sg files
if sg bl808; then
arm2 vb_r3 "VB3: graph s319 3.1's cross-1 shape (qa NEEDS_REWORK, its ## Findings saying the gap is another group's) REFUSED byte-equal under --check-shard, naming the set 'shard-verdict: PASS' exit first, then the file-here exit, and [owner: cross-1]" \
           "VB3: the cross-1 refusal does not name both exits and its owner"
arm2 vb_mark "VB4: --mark findings=0 on an empty NEEDS_REWORK code-review shard exits 64 relaying the stem, the file byte-unchanged; the same file with one Important finding re-written marks findings=1 key=2" \
             "VB4: --mark marked an unbacked NEEDS_REWORK, or refused the backed one"
# BL-763: every owner-duplicate refusal in one run, and --check-shard exits 2 on one (--mark keys on it).
arm2 x_dupall "X10: K=3 -- duplicates in cross-2 and cross-3 print two REFUSED lines (tails cross-2, cross-3), one prints one, an owner's own repeat merges, --check-shard over a duplicate exits 2 with no SHARD-OK, a duplicate then a later per-shard refusal print both (the duplicate first), an earlier per-shard refusal stands alone, and one shard's duplicate then its own verdict-backing refusal print two lines naming it; nothing written" \
              "X10: a merge did not name every owner duplicate in one run, or --check-shard passed a duplicate"
# BL-808: cited captures leave the threshold COUNT, never the file set (partition-review-diff.sh
# --exclude-captures). XC1 is the discriminating seed: a capture-heavy diff that stays sharded, so the
# merge's flagless re-derivation must reproduce the flagged map. M43-M46 below are owned by these.
arm2 xc_merge "XC1: $((DFLT + 2)) code files and 10 captures partitioned WITH --exclude-captures into a shard dir (no exclude key in its manifest) merge end to end: the merge's flagless re-derivation reproduces the recorded map" \
              "XC1: a capture-heavy flagged partition did not merge through the flagless re-derivation"
arm2 xc_flip "XC2: $((DFLT - 1)) code files and 10 captures partition without the flag; with it -> exit 3, 'SERIAL: $((DFLT - 1)) reviewable file(s) (... 10 cited capture(s) not counted), below the threshold of $DFLT', no shard dir written" \
             "XC2: the flag did not flip a capture-heavy diff to SERIAL cleanly"
arm2 xc_count "XC3: the excluded count is the INTERSECTION -- a list of 13 lines (cap10 only as CRLF, an out-of-diff path, a scan-root path, a duplicate) prints '10 cited capture(s) not counted'; the same ten spelled './' print 0, in the same arm" \
              "XC3: the excluded count is not the list's intersection with the counted files"
arm2 xc_one "XC4: one code file and five captures under --min-files 1 partition without the flag and answer SERIAL 'a review of at most one counted file is never sharded' with it; two code files under the same flag still shard" \
            "XC4: a one-counted-file review was sharded, or a two-file one was not"
arm2 xc_missing "XC5: --exclude-captures naming a file that does not exist -> REFUSED exit 2, nothing on stdout, no manifest" \
                "XC5: an unreadable capture list was not refused"
fi # sg bl808
if sg gmaint; then
# A git with no `maintenance` subcommand (before 2.29) cannot spawn the child GM1 counts, so the arm stands down with a
# DISTINCT ok line claiming no spawn count; gm_vacuous exits 2 (FIXTURE BROKEN) when the git is 2.29 or later.
if ! gm_has_maint; then
gm_vacuous
ok "GM1 VACUOUS on git $GM_GITV: this git predates git maintenance (2.29), so no commit can spawn the child GM1 counts; no spawn was read and the arm asserts nothing here"
else
arm2 gmaint "GM1 (BL-868, BL-980): a commit through lib.sh's G spawns 0 'git maintenance run' children (trace2 child_start), so no detached repack races a later cp -R of the repository; the same commit through raw git spawns 1 (the control), and G with -c maintenance.auto=false stripped spawns 1 (the mutant); and receipt-bl980.sh answers BL980 OK: every receipt-*.sh in this directory (the line above names them), run as lib.sh runs it, commits and spawns 0 across its whole run, and receipt-bl904.sh less its flag (the must-fire) spawns at least 1" \
            "GM1: a commit through G or a receipt spawns auto-maintenance, or the arm cannot tell"
fi
fi # sg gmaint

# ------------------------------------------------- BL-737 mutants (distribution layout only, in-process)
# Each is a copy of the WHOLE resolved script directory (the merge, --mark and the seal resolve their
# siblings beside themselves), one exact substring replaced -- refused unless it occurs exactly once,
# reported DID NOT APPLY otherwise -- and driven through the one predicate that owns it. A kill must
# carry its own reason token in WHY, so a mutant that died for another cause is not scored a kill.
if [ -d "$LIB_DIR/../../scripts" ] && [ "$(cd "$LIB_DIR/../../scripts" && pwd)" = "$SRCDIR" ]; then
  mutate() { # <copy dir> <file> <old> <new> -> 0 applied once
    local f="$1/$2" n
    n="$(OLD="$3" awk 'BEGIN { o = ENVIRON["OLD"] } { s = $0; while ((i = index(s, o)) > 0) { n++; s = substr(s, i + length(o)) } } END { print n + 0 }' "$f")"
    [ "$n" = 1 ] || return 1
    OLD="$3" NEW="$4" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] }
      { i = index($0, o); if (i > 0) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' "$f" > "$f.mut" \
      && ! cmp -s "$f" "$f.mut" && cat "$f.mut" > "$f" && rm -f "$f.mut"
  }
  # THE COPY IS THE DERIVED SIBLING SET (BL-755), never the whole script directory. Its roots are the
  # scripts the predicates invoke through their script-dir argument (`$sd/`, `$1/`, `$md/`, `$vb_ctl/`
  # joined to `<name>.sh` in lib.sh and this file). The closure adds every `<name>.sh` that a
  # non-comment line of a member resolves beside itself, meaning a directory expression (`$VAR/`,
  # `${VAR}/`, `)/`) joined to the name, until nothing is added. A sibling the closure misses cannot pass
  # silently: every mutant first runs its selected cell over the UNMUTATED copy (the control, below).
  sib_set() { # -> the derived set, one basename per line, sorted
    local s t f new
    s="$(grep -ohE '\$(sd|1|md|vb_ctl)/[A-Za-z0-9_-]+\.sh' "$LIB_DIR/lib.sh" "$LIB_DIR/run.sh" | sed 's|.*/||' | sort -u)"
    while :; do
      new="$s"
      for f in $s; do
        [ -f "$SRCDIR/$f" ] || continue
        for t in $(grep -v '^[[:space:]]*#' "$SRCDIR/$f" | grep -oE '(\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\))/[A-Za-z0-9_-]+\.sh' | sed 's|.*/||' | sort -u); do
          [ -f "$SRCDIR/$t" ] && new="$(printf '%s\n%s\n' "$new" "$t" | sort -u)"
        done
      done
      [ "$new" = "$s" ] && break
      s="$new"
    done
    for f in $s; do [ -f "$SRCDIR/$f" ] && printf '%s\n' "$f"; done
  }
  SIB_SET="$(sib_set)"
  sib_copy() { # <fresh dir> -> 0 when it holds exactly SIB_SET, byte-identical to SRCDIR's
    local f
    [ ! -e "$1" ] && mkdir -p "$1" || return 1
    for f in $SIB_SET; do cp "$SRCDIR/$f" "$1/$f" || return 1; done
    [ "$(for f in "$1"/*; do [ -f "$f" ] && basename "$f"; done | sort)" = "$SIB_SET" ]
  }
  # The set must hold what every predicate drives and what the merge, --mark and the seal resolve. Its
  # size against the directory is printed, never asserted: under hermetic-run the directory holds only
  # declared inputs, so the two can be equal there; sib_copy asserts each copy IS the set, nothing more.
  sib_n="$(printf '%s\n' "$SIB_SET" | grep -c .)" || sib_n=0
  src_n=0; for f in "$SRCDIR"/*; do [ -f "$f" ] && src_n=$((src_n + 1)); done
  sib_miss=""
  for f in merge-review-shards.sh wait-for-deliverable.sh content-seal.sh partition-review-diff.sh partition-document.sh \
           merge-adversarial-shards.sh validate-adversarial-convergence.sh wfd-start-of.sh artifact-path-config.sh; do
    grep -qxF "$f" <<<"$SIB_SET" || sib_miss="$sib_miss $f"
  done
  if [ -z "$sib_miss" ] && [ "$sib_n" -ge 9 ]; then
    ok "SIB: the mutant copy is the derived sibling set, $sib_n of the $src_n files in $SRCDIR, holding the four mut_run siblings and every script they resolve"
  else bad "SIB: FIXTURE ERROR -- the derived sibling set ($sib_n of $src_n) lacks [${sib_miss# }]"; fi
  # THE SELECTOR (BL-755). Every mut_run line names the one cell its mutant is scored on (CS_ONLY), and
  # every predicate a mutant drives runs only that cell (lib.sh `cell`). CS_RAN counts the cells run. The
  # control is each mutant's own cell over the UNMUTATED copy in vb_ctl, which must run exactly ONE cell
  # and pass. A mutant run that runs no cell prints the sentinel `CS-UNSELECTED`, which the receipt counts.
  vb_ctl="$WORK/mut-VBCTL"; VB_CTL_N=0; VB_CTL_OK=1
  if sib_copy "$vb_ctl" && cmp -s "$SRCDIR/merge-review-shards.sh" "$vb_ctl/merge-review-shards.sh"; then :; else VB_CTL_OK=0; fi
  # THE BASE-PASS FLAG (BL-828). B_rsm_ctl is reset at the top of every mut_run and set to 1 only in the
  # passing branch of THAT mutant's own control, so its kill is emitted through mutant_killed only when
  # its own cell passed unmutated in this run. Each control prints its own VBCTL <id> line.
  # THE TWINS. A plain run reads the mutant's `# MUTANT-MATRIX` header line: its first decides= arm must
  # be this mut_run's <predicate>/<cell> (a mutant added or changed without a re-measure is refused), and
  # each twins= arm is run over the mutant copy and must PASS, one cell run. Its unmutated control is the
  # arm above that runs the same predicate over SRCDIR. --matrix records the mutant (mx_rows) instead and
  # matrix_score, after the last mut_run, scores the mutant x cell population the header describes.
  mx_line() { awk -v id="$1" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == id { print; n++ } END { exit n != 1 }' "$HERE/run.sh"; }
  mx_field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"; } # <header line> <decides|twins>
  TWIN_N=0; MX_CELLS=0; MX_ROWS="$WORK/mx-rows"; : > "$MX_ROWS"
  # IN PROCESS (lib.sh ip_load): each mutant's copy of the merge is SOURCED ONCE into this shell before its
  # cells run, so every in-process ask of "$md/merge-review-shards.sh" (its deciding cell and its twins) forks
  # a subshell holding the mutant's functions; SRCDIR's merge is loaded back after it. Only the owning cell
  # and the named twins run per mutant, never the fixture.
  mut_run() {
    # Dealt to another shard (J0 holds the deal): a plain run skips it; --matrix records every mutant and scores DEALT's.
    [ "$RSM_MATRIX" = 1 ] || case "$MUT_MINE" in *" $1 "*) ;; *) return 0 ;; esac
    mut_run_one "$@"
    ip_load "$SRCDIR/merge-review-shards.sh" || bad "$1: FIXTURE ERROR -- SRCDIR's merge was not loaded back after the mutant"
  }
  # ONE COPY PER DISTINCT MUTATION (BL-906). Twelve mutants are the byte-identical edit of their partner (each -merge
  # row: the same <file> <old> <new>, scored on the merge's cell where its partner is scored on --check-serial's), so
  # the second of a pair drives the copy the first built rather than building and mutating its own. The registry is
  # keyed on the three strings, compared in the shell, and a reused copy must still differ from SRCDIR's file (cmp),
  # so a copy that is no longer a mutant cannot score. Each id keeps its own control, kill and twins.
  MUT_KN=0
  mut_dir_of() { # <file> <old> <new> -> the copy an earlier identical mutation built (0), else 1
    local i=0
    while [ "$i" -lt "$MUT_KN" ]; do
      if [ "${MUT_KF[$i]}" = "$1" ] && [ "${MUT_KO[$i]}" = "$2" ] && [ "${MUT_KW[$i]}" = "$3" ]; then printf '%s' "${MUT_KD[$i]}"; return 0; fi
      i=$((i + 1))
    done
    return 1
  }
  MUT_SHARED=0; MUT_SCORED=""
  mut_run_one() { # <id> <file> <old> <new> <predicate> <reason token> <label>; CS_ONLY names the cell
    local id="$1" md="$WORK/mut-$1" hl dec tw a tp tc mshare=0
    B_rsm_ctl=0
    [ -n "${CS_ONLY:-}" ] || { bad "$id: FIXTURE ERROR -- no CS_ONLY selector names the cell this mutant is scored on"; return; }
    [ "$VB_CTL_OK" = 1 ] || { bad "$id: FIXTURE ERROR -- the unmutated control copy $vb_ctl was not built from the derived set"; return; }
    WHY=""; CS_RAN=0
    # The control copy is byte-identical to SRCDIR (sib_copy), and the arm that runs this predicate over SRCDIR passed
    # earlier in THIS run with every cell, this one included: that pass is the base-pass flag, so the cell is not
    # re-run over the copy (one run per distinct state). A predicate with no passing arm runs its cell here.
    if [ "$(eval "printf %s \"\${ARMOK_$5:-0}\"")" = 1 ] && [ "$RSM_MATRIX" = 0 ]; then
      VB_CTL_N=$((VB_CTL_N + 1)); ok "VBCTL $id: cell '$CS_ONLY' of $5 passed unmutated (arm $5 passed over the byte-identical SRCDIR set earlier in this run)"; B_rsm_ctl=1
    elif "p_$5" "$vb_ctl" && [ "$CS_RAN" = 1 ]; then
      VB_CTL_N=$((VB_CTL_N + 1)); ok "VBCTL $id: cell '$CS_ONLY' of $5 passed over the unmutated copy, one cell run"; B_rsm_ctl=1
    else bad "$id: FIXTURE ERROR -- the unmutated copy failed cell '$CS_ONLY' of $5 (cells run: $CS_RAN):${WHY}"; return; fi
    if a="$(mut_dir_of "$2" "$3" "$4")"; then
      md="$a"; mshare=1
      [ -f "$md/$2" ] && ! cmp -s "$md/$2" "$SRCDIR/$2" || { bad "$id: FIXTURE ERROR -- the shared copy $md/$2 is no longer a mutant of $SRCDIR/$2"; return; }
      MUT_SHARED=$((MUT_SHARED + 1))
    else
      sib_copy "$md" || { bad "$id: FIXTURE ERROR -- the derived sibling set was not copied fresh into $md"; return; }
      [ -f "$md/merge-review-shards.sh" ] && [ -f "$md/wait-for-deliverable.sh" ] && [ -f "$md/content-seal.sh" ] && [ -f "$md/partition-review-diff.sh" ] \
        || { bad "$id: FIXTURE ERROR -- a sibling is absent from $md"; return; }
      mutate "$md" "$2" "$3" "$4" || { bad "$id: DID NOT APPLY -- '$3' does not occur exactly once in $2"; return; }
      MUT_KF[$MUT_KN]="$2"; MUT_KO[$MUT_KN]="$3"; MUT_KW[$MUT_KN]="$4"; MUT_KD[$MUT_KN]="$md"; MUT_KN=$((MUT_KN + 1))
    fi
    ip_load "$md/merge-review-shards.sh" || { bad "$id: FIXTURE ERROR -- the mutant copy's merge could not be loaded in process"; return; }
    WHY=""; CS_RAN=0
    if "p_$5" "$md"; then bad "$id: SURVIVED -- $7 ($5 passed over $md/$2)"
    elif case "$WHY" in *"$6"*) true ;; *) false ;; esac; then mutant_killed "${B_rsm_ctl:-0}" "$id" "$id: killed -- $7 ($5:${WHY})" && MUT_SCORED="$MUT_SCORED$id
"
    else bad "$id: died for another reason than '$6' -- $7 ($5:${WHY})"; fi
    [ "$CS_RAN" -le 1 ] || bad "$id: FIXTURE ERROR -- the mutant ran $CS_RAN cells of $5 under CS_ONLY=$CS_ONLY, not one"
    [ "$CS_RAN" -ge 1 ] || echo "CS-UNSELECTED: $id ran no cell of $5 for CS_ONLY=$CS_ONLY"
    if [ "$RSM_MATRIX" = 1 ]; then printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$2" "$5" "$CS_ONLY" "$md" >> "$MX_ROWS"; return; fi
    hl="$(mx_line "$id")" || { bad "$id: FIXTURE STALE -- run.sh carries no single '# MUTANT-MATRIX $id' line; re-measure the matrix"; return; }
    dec="$(mx_field "$hl" decides | cut -d, -f1)"; tw="$(mx_field "$hl" twins)"
    [ "$dec" = "$5.$CS_ONLY" ] || { bad "$id: FIXTURE STALE -- its MUTANT-MATRIX line decides=$dec, but mut_run scores $5.$CS_ONLY; re-measure the matrix"; return; }
    [ -n "$tw" ] || { bad "$id: FIXTURE STALE -- its MUTANT-MATRIX line names no twin"; return; }
    for a in $(printf '%s\n' "$tw" | tr ',' ' '); do
      tp="${a%%.*}"; tc="${a#*.}"; WHY=""; CS_RAN=0
      if CS_ONLY="$tc" "p_$tp" "$md" && [ "$CS_RAN" = 1 ]; then TWIN_N=$((TWIN_N + 1)); ok "TWIN $id: $a passed over the mutant copy, one cell run"
      else bad "$id: co-tripped its twin $a, or ran $CS_RAN cells of it, over the mutant copy:${WHY}"; fi
    done
  }
  # matrix_score (--matrix only): for every recorded mutant, its population is the cells of its own drive
  # (listed by running the predicate under CS_LIST, which runs no cell), plus, when that drive declares
  # fewer than two cells, the deciding cell of every other mutant of the same file. Each cell is scored
  # over the mutant copy and over the unmutated control copy (one control per cell, memoised).
  mx_state() { # <predicate> <cell> <script-dir> -> RED|GREEN|SKIP; the predicate's own stdout is dropped
    ip_load "$3/merge-review-shards.sh" || { echo SKIP; return; }
    WHY=""; CS_RAN=0
    if CS_ONLY="$2" "p_$1" "$3" > /dev/null 2>&1 < /dev/null; then [ "$CS_RAN" = 1 ] && echo GREEN || echo SKIP
    else [ "$CS_RAN" = 1 ] && echo RED || echo SKIP; fi
  }
  # mx_twin <id> <deciding arm> <decides list> <population...> -> the twin: the first cell of the
  # population, outside decides=, GREEN over the mutant and the control, after the deciding cell in
  # declaration order, else before it. A function, not a $( ) body: bash 3.2 misparses a `case`
  # pattern's unbalanced `)` inside a command substitution.
  mx_twin() {
    local id="$1" d="$2" dec="$3" q
    shift 3
    for q in $(printf '%s\n' "$@" | awk -v d="$d" '$0 == d { s = 1; next } { if (s) a[++na] = $0; else b[++nb] = $0 }
      END { for (i = 1; i <= na; i++) print a[i]; for (i = 1; i <= nb; i++) print b[i] }'); do
      if printf ',%s,' "$dec" | grep -qF ",$q,"; then continue; fi
      if grep -qxF "MATRIX $id $q mutant=GREEN control=GREEN" "$WORK/mx-log"; then printf '%s' "$q"; return 0; fi
    done
    return 0
  }
  # RSM_MATRIX_SLICE=k/n (header): the row loop scores only rows whose 0-based index mod n is k; it still lists every
  # row's population (MATRIX-POP) for --merge-slices. MX_SROWS/MX_SPOP/MX_TPOP feed MX1's slice arm.
  MX_SROWS=0; MX_SPOP=0; MX_TPOP=0
  matrix_score() {
    local id f p c mdir cl pop q pc ms cs key dec tw ri=-1
    mkdir -p "$WORK/mx-cells" "$WORK/mx-ctl"
    [ -z "$RSM_SLICE_N" ] || echo "MATRIX-SLICE $RSM_SLICE_K/$RSM_SLICE_N"
    while IFS='	' read -r id f p c mdir <&3; do
      cl="$WORK/mx-cells/$p"
      [ -f "$cl" ] || { CS_LIST="$cl.tmp"; : > "$CS_LIST"; WHY=""; "p_$p" "$vb_ctl" > /dev/null 2>&1 < /dev/null || :; CS_LIST=""
        awk '!s[$0]++' "$cl.tmp" > "$cl"; }
      pop="$(sed "s|^|$p.|" "$cl")"
      if [ "$(grep -c . "$cl")" -lt 2 ]; then
        pop="$(printf '%s\n%s\n' "$pop" "$(awk -F'\t' -v id="$id" -v f="$f" '$1 != id && $2 == f { print $3 "." $4 }' "$MX_ROWS")" | awk 'NF && !s[$0]++')"
      fi
      # A per-shard matrix (--group with --matrix) prints the WHOLE fixture's population (MATRIX-ALLPOP) and scores
      # only its dealt rows, so the shards' MATRIX pairs can be joined against the unsharded population.
      if [ "$_grp" = 1 ]; then
        for q in $pop; do echo "MATRIX-ALLPOP $id $q"; done
        case "$MUT_MINE" in *" $id "*) ;; *) continue ;; esac
      fi
      # RSM_MATRIX_IDS="<id>..." (--matrix only): score only the rows named, the re-measure of the rows a change owes
      # (fixture-mutants.md clause 2: every mutant whose predicate's population moved); the rest keep their rows.
      [ -z "${RSM_MATRIX_IDS:-}" ] || case " $RSM_MATRIX_IDS " in *" $id "*) ;; *) continue ;; esac
      ri=$((ri + 1))
      if [ -n "$RSM_SLICE_N" ]; then
        for q in $pop; do echo "MATRIX-POP $id $q"; MX_TPOP=$((MX_TPOP + 1)); done
        [ $((ri % RSM_SLICE_N)) = "$RSM_SLICE_K" ] || continue
        MX_SROWS=$((MX_SROWS + 1)); for q in $pop; do MX_SPOP=$((MX_SPOP + 1)); done
      fi
      dec="$p.$c"; tw=""; also=""
      for q in $pop; do
        pc="${q#*.}"; key="$WORK/mx-ctl/$(printf '%s' "$q" | tr '.' '_')"
        [ -f "$key" ] || mx_state "${q%%.*}" "$pc" "$vb_ctl" > "$key"
        cs="$(cat "$key")"; ms="$(mx_state "${q%%.*}" "$pc" "$mdir")"; MX_CELLS=$((MX_CELLS + 1))
        echo "MATRIX $id $q mutant=$ms control=$cs" | tee -a "$WORK/mx-log"
        [ "$q" = "$p.$c" ] && continue
        if [ "$ms" = RED ] && [ "$cs" = GREEN ]; then also="$also,$q"; fi
      done
      tw="$(mx_twin "$id" "$p.$c" "$dec" $pop)"
      echo "MATRIX-HEADER # MUTANT-MATRIX $id decides=$dec twins=${tw:-NONE}"
      [ -z "$also" ] || echo "MATRIX-ALSO # also trips: $id ${also#,}"
    done 3< "$MX_ROWS"
  }
  CS_ONLY=partcite mut_run M1 merge-review-shards.sh '[ $# -eq 1 ] && [ "$1" = "$key" ]' \
    '{ [ -n "$CHECK" ] || { [ $# -eq 1 ] && [ "$1" = "$key" ]; }; }' cs "csc_partcite{" \
    "the part-cite refusal dropped in --check-shard only"
  CS_ONLY=dup-merge mut_run M2 merge-review-shards.sh '|| collect_dup "$sf:$line ($key) cites$distinct, a finding owned by' \
    '|| refuse_to "$ownk" "$sf:$line ($key) cites$distinct, a finding owned by' owner "dup-merge{" \
    "the owner-duplicate refusal names the owner"
  CS_ONLY=shard-3 mut_run M3 wait-for-deliverable.sh '[ "$mk_s_" != "!" ] || mark_refuse' 'true || mark_refuse' mark "shard-3{" \
    "--mark skips the <shard> key check"
  CS_ONLY=seal-rewrite mut_run M4 wait-for-deliverable.sh '*-qa-validation-????????????) MK_GATE=qa ;;' '*-qa-validation-NOMATCH) MK_GATE=qa ;;' \
    seal_rewrite "review-shard branch" "--mark's review-shard (seal) branch does not match a qa-validation path"
  CS_ONLY=sentinel mut_run M5 merge-review-shards.sh 'present) refuse "' 'present) : "' legacy "sentinel{" \
    "a legacy marker is accepted when the frozen sha's engine carries the sentinel"
  CS_ONLY=unmarked-sentinel mut_run M6 merge-review-shards.sh '[ "$ENGINE" != present ] || SEAL_MODE=""' ':' unmarked "unmarked-sentinel{" \
    "the unmarked shard's engine reading is dropped, so it keeps the legacy seal"
  # BL-740. The CONTROL is now per mutant: mut_run runs each mutant's own selected cell over the
  # unmutated copy in $vb_ctl (the same derived set every mutant copies) before it scores the mutant,
  # and VBCTL, after M22, asserts that every mutant's control ran.
  CS_ONLY=q-nr-empty mut_run M7 merge-review-shards.sh '      NEEDS_REWORK|BLOCKED)' '      M7)' vb_qa "q-nr-empty{" \
    "the severity-mode verdict-backing rule removed"
  CS_ONLY=cr-blocked-sug mut_run M8 merge-review-shards.sh '(cls(t, ENVIRON["PS_IMP_"]) ? "imp" : "")' '"imp"' vb_cr "cr-blocked-sug{" \
    "a Suggestions finding counted as Important"
  CS_ONLY=cr-approved-crit mut_run M9 merge-review-shards.sh '[ "$kc_" -eq 0 ] \' 'true \' vb_cr "cr-approved-crit{" \
    "the APPROVED-forbids-Critical half dropped"
  CS_ONLY=cr-nr-imp mut_run M10 merge-review-shards.sh 'CRIT_NAME="$1"; IMP_NAME="$2"; SUG_NAME="$3"' 'CRIT_NAME="Critical"; IMP_NAME=""; SUG_NAME="Suggestions"' \
    vb_cr "cr-nr-imp{" "the container lift replaced by a hard-coded list that omits Important"
  # M11 keeps all three r3 phrases present and reverses only their ORDER (the file-here clause first),
  # so the single token that can fire is the order one.
  CS_ONLY=r3-graph-cross1 mut_run M11 merge-review-shards.sh \
    "If the finding belongs to another shard, set 'shard-verdict: \$best_' here and let that shard's verdict carry it; otherwise file the finding that makes it \$v here, as a '#### ' heading under '### \$CRIT_NAME' or '### \$IMP_NAME' with a 'parts:' set this shard may own (one the owning group's shard does not already carry), or move" \
    "Either way, otherwise file the finding that makes it \$v here, as a '#### ' heading under '### \$CRIT_NAME' or '### \$IMP_NAME' with a 'parts:' set this shard may own (one the owning group's shard does not already carry); If the finding belongs to another shard, set 'shard-verdict: \$best_' here and let that shard's verdict carry it, or move" \
    vb_r3 "r3-owner-first-order{" "the owner-first clause moved after the file-here clause"
  # BL-746. M12 reads qa.md as count-only whatever its template declares (code-review's rule only);
  # M13 drops the zero-container fallback, so a consumer's installed qa.md is refused; M14 drops the
  # unclassed-finding refusal. Each is owned by one cell.
  CS_ONLY=q-mode-sug mut_run M12 merge-review-shards.sh 'if [ "$GATE" = qa ] && [ "$#" -eq 0 ]; then' 'if [ "$GATE" = qa ]; then' \
    vb_qmode "q-mode-sug{" "QA stays count-only when qa.md declares the three containers"
  CS_ONLY=q-leg-nr-one mut_run M13 merge-review-shards.sh 'if [ "$GATE" = qa ] && [ "$#" -eq 0 ]; then' 'if false; then' \
    vb_qleg "q-leg-nr-one{" "the zero-container fallback dropped, so the old installed qa.md is refused"
  CS_ONLY=q-unclassed mut_run M14 merge-review-shards.sh '[ "$ku_" = 0 ] \' 'true \' vb_qa "q-unclassed{" \
    "a finding under no container accepted in severity mode"
  # BL-747. M15 removes the FAIL-row gate from the merge; M16 reads the first column after AC instead
  # of the one headed Result/Verdict; M17 matches the AC id as a substring.
  CS_ONLY=fr-plain mut_run M15 merge-review-shards.sh '  fail_gate "$(awk' '  : "$(awk' fr_verdict "fr-plain{" \
    "the FAIL-row check removed from the merge"
  CS_ONLY=fr-reorder mut_run M16 merge-review-shards.sh 'if (!ac) ac = 2' 'if (!ac) ac = 2; rc = ac + 1' fr_verdict "fr-reorder{" \
    "the result column read by position instead of by its header"
  CS_ONLY=fr-ac10 mut_run M17 merge-review-shards.sh 'if (p !~ /[A-Za-z0-9.]/ && q !~ /[A-Za-z0-9.]/) return 1' 'return 1' fr_orphan "fr-ac10{" \
    "the AC id matched as a substring, so AC10 names AC1"
  # BL-742. M18 drops --check-serial's set-membership read.
  CS_ONLY=sr-q-set mut_run M18 merge-review-shards.sh '    *" $C1V "*) ;;' '    *) ;;' serial "sr-q-set{" \
    "--check-serial skips the set-membership read"
  CS_ONLY=sr-q-twosame mut_run M19 merge-review-shards.sh '  [ "$C1D" = 1 ] \' '  [ "$C1N" = 1 ] \' serial "sr-q-twosame{" \
    "--check-serial reverts to the merge's strict one-match count"
  # M20 drops the severity boundary's LEGACY arm, so a set frozen over a container-less installed qa.md
  # is judged by the current three-container rule.
  CS_ONLY=frb-legacy mut_run M20 merge-review-shards.sh '    if [ "$QA_AT" = legacy ]; then sev_=0' '    if false; then sev_=0' fr_bound "frb-legacy{" \
    "the severity boundary's LEGACY arm dropped"
  # BL-763. M21 collects every duplicate but prints only the first; M22 drops the --check-shard barrier
  # (the two-space-indented one), so --check-shard answers SHARD-OK over a duplicate and --mark seals it.
  CS_ONLY=two mut_run M21 merge-review-shards.sh 'collect_dup() { printf' 'collect_dup() { [ "$DUP_N" -gt 0 ] || printf' x_dupall "two{" \
    "only the first owner duplicate of a run printed"
  CS_ONLY=check mut_run M22 merge-review-shards.sh '  [ "$DUP_N" -eq 0 ] || exit 2' '  :' x_dupall "check{" \
    "the --check-shard duplicate barrier dropped"
  # BL-769. M23 the filter read dropped, so a -k PASS is accepted. M24 the record-only decision dropped,
  # so a code-touching none is accepted. M25 the merge's LEGACY gate dropped, so a set frozen over an
  # installed qa.md with no label is refused. M26 the PASS-only scope dropped, so an early NEEDS_REWORK
  # with no run is refused. M27 the merge's call dropped, so a run-less PASS merges. M28 the serial
  # gate-1-base check dropped, so a seat-narrowed rework range acquits. M29 the conventions file not
  # handed to the serial check, so a declared path root refuses. M30 the no-run inversion reverted, so
  # 'N/A' reads as a run. M31 the record-dir code-suffix exclusion dropped (record-only-diff.sh). M32 the
  # serial LEGACY branch forced off. M33 the merge's on-disk qa.md read dropped.
  CS_ONLY=cr-filter-k mut_run M23 merge-review-shards.sh '  cg_rf_="$(mrs_sib "$RO" ro_main run-filter "$cg_run_" ${cg_c_:+"$cg_c_"})" \' '  cg_rf_="$(true)" \' \
    canon "cr-filter-k{" "a filtered canonical run accepted"
  CS_ONLY=cr-exempt-code mut_run M24 merge-review-shards.sh '    cg_ro_="$(mrs_sib "$RO" ro_main paths' '    cg_ro_="$(true' canon "cr-exempt-code{" \
    "the record-only exemption accepted whatever the diff"
  CS_ONLY=crm-legacy mut_run M25 merge-review-shards.sh '  if [ "$cr_held_" = 0 ]; then' '  if false; then' canon_merge "crm-legacy{" \
    "the merge's installed-qa.md LEGACY gate dropped"
  CS_ONLY=cr-nr-norun mut_run M26 merge-review-shards.sh '  [ "$WORST" = PASS ] || return 0' '  :' canon "cr-nr-norun{" \
    "a NEEDS_REWORK with no canonical run refused"
  CS_ONLY=crm-norun mut_run M27 merge-review-shards.sh '    canon_gate "$(awk' '    : "$(awk' canon_merge "crm-norun{" \
    "the merge's canonical-run call removed"
  CS_ONLY=cr-exempt-narrow mut_run M28 merge-review-shards.sh '      cg_sb_="$(mrs_sib "$RO" ro_main story-base' '      cg_sb_="$(true' canon "cr-exempt-narrow{" \
    "the serial exemption decided over a seat-narrowed range"
  CS_ONLY=cr-path-conv mut_run M29 merge-review-shards.sh '      canon_gate "$SERIAL" serial "$sr_repo_" "$R_BASE" "$R_FROZEN" "$sr_conv_"' '      canon_gate "$SERIAL" serial "$sr_repo_" "$R_BASE" "$R_FROZEN" ""' \
    canon "cr-path-conv{" "the consumer's declared canonical path refused"
  CS_ONLY=cr-norun-na mut_run M30 merge-review-shards.sh '  if ! mrs_sib "$RO" ro_main run-shape "$cg_run_" ${cg_c_:+"$cg_c_"}; then' '  if mrs_sib "$RO" ro_main none-reason "$cg_run_" 2>/dev/null; [ $? -ne 2 ]; then' \
    canon "cr-norun-na{" "a no-run claim spelled other than none read as a run"
  CS_ONLY=cr-exempt-evil mut_run M31 record-only-diff.sh '            *.py|*.sh|*.toml|*.cfg|conftest.py|pytest.ini) first="$p" ;;' '            NEVER-A-SUFFIX) first="$p" ;;' \
    canon "cr-exempt-evil{" "a collectable module under a record directory classed record-only"
  CS_ONLY=cr-serial-legacy mut_run M32 merge-review-shards.sh '      *) sr_held_=0; sr_leg_="$SR_QA_AT" ;;' '      *) : ;;' canon "cr-serial-legacy{" \
    "the --check-serial LEGACY branch forced off"
  CS_ONLY=crm-disk-legacy mut_run M33 merge-review-shards.sh '  if [ -z "$cr_inst_" ]; then' '  if false; then' canon_merge "crm-disk-legacy{" \
    "the merge's on-disk qa.md read dropped"
  # BL-769 fold, all in record-only-diff.sh's RUN-FILTER and RUN-SHAPE. M34 the test-file suffixes
  # dropped, so a vitest file argument reads as a path. M35 go's -run dropped. M36 --lf dropped. M37
  # the `--` hand-off dropped. M38 the superset clause dropped, so a root containing the declared one
  # refuses. M39 the none no longer read before the run shape.
  CS_ONLY=cr-filter-suffix mut_run M34 record-only-diff.sh '          *::*|*.py|*.test.*|*.spec.*|*_test.go)' '          *::*|*.py)' \
    canon "cr-filter-suffix{" "a test-file argument to a non-pytest runner accepted as a path"
  CS_ONLY=cr-filter-gorun mut_run M35 record-only-diff.sh '|--testNamePattern=*|-run|-run=*)' '|--testNamePattern=*)' \
    canon "cr-filter-gorun{" "go test -run accepted"
  CS_ONLY=cr-filter-lf mut_run M36 record-only-diff.sh '          --lf|--last-failed) printf' '          --NEVER-lf) printf' \
    canon "cr-filter-lf{" "a last-failed re-run accepted"
  CS_ONLY=cr-filter-dd mut_run M37 record-only-diff.sh '          [ "$w" = -- ] && dd=1' '          :' \
    canon "cr-filter-dd{" "a path handed to the runner after -- accepted"
  CS_ONLY=cr-path-super mut_run M38 record-only-diff.sh ' || substr($2, 1, length(v) + 1) == v "/")' ')' \
    canon "cr-path-super{" "a path root containing the declared one refused"
  CS_ONLY=cr-norun-nonebt mut_run M39 record-only-diff.sh '    (ro_none_reason none-reason "$2") >/dev/null 2>&1; [ $? -eq 2 ] || exit 1' '    :' \
    canon "cr-norun-nonebt{" "a none carrying a runner span read as a run"
  # M40 the conventions' declared canonical command no longer read as a runner, so `tox -e all` is a no-run claim.
  CS_ONLY=cr-conv-runner mut_run M40 record-only-diff.sh '        rs_rn="$rs_rn|$(printf' '        : "$(printf' \
    canon "cr-conv-runner{" "a runner the conventions declare canonical read as a no-run claim"
  # BL-885, both in record-only-diff.sh's ro_story_rel. M49 the helper reverted to the old `${1#./}` strip, so an
  # absolute --story names no blob at the base or at the frozen sha and a genuinely record-only range is REFUSED end
  # to end (the receipt's absolute and `.//` cells fail too; cr-exempt-abs, the empty range, refuses either way).
  # M50 an absolute path outside the repository passed through as itself. Its kill is the paths mode's hosts cell: since
  # BL-904 story-base's history walk refuses a path outside the repository itself (rev-list fails, exit 2).
  CS_ONLY=cr-exempt-abs-rec mut_run M49 record-only-diff.sh '    local rs_repo="$1" rs_p="$2" rs_top rs_dir rs_base' \
    '    printf '"'"'%s\n'"'"' "${2#./}"; return 0; local rs_repo="$1" rs_p="$2" rs_top rs_dir rs_base' \
    canon "cr-exempt-abs-rec{rc=2" "the story path stripped of a leading ./ only, so an absolute --story over a record-only range is refused"
  CS_ONLY=story-path mut_run M50 record-only-diff.sh '*) echo "$ME: UNEVALUABLE — story path is outside the repository: $2" >&2; return 2 ;;' \
    '*) printf '"'"'%s\n'"'"' "$rs_p" ;;' story_path "FAIL paths-hosts:" "an absolute story path outside the repository passed through"
  # BL-885, record-only-diff.sh's ro_story_base. M51 the <frozen> operand ignored, so a story absent at the base exits
  # 0 unconditionally (the frozen-blob and non-blob checks both gone): story-base's own typo cell reads 0. BL-895's
  # binding refuses a typo --story before story-base runs, so the kill is asked of story-base directly (D4).
  CS_ONLY=story-frozen mut_run M51 record-only-diff.sh '    if [ $# -eq 3 ]; then' '    if false; then' \
    story_frozen "FAIL sf-typo:" "a story that is no file at the base or at the frozen sha read as a gate-1 base"
  # BL-904, record-only-diff.sh's ro_story_never. M58 drops --full-history, so default history simplification follows
  # the merge's TREESAME side and the deletion behind it reads as no history (sh-merge reads 0). M59 drops the history
  # test itself, so a story `git rm`'d before the base and re-added reads as created after it (sh-ldel reads 0).
  CS_ONLY=story-hist mut_run M58 record-only-diff.sh 'rev-list -1 --full-history "$1"' 'rev-list -1 "$1"' \
    story_hist "FAIL sh-merge:" "a deletion hidden behind a merge read as a story that was never in the base's history"
  CS_ONLY=story-hist mut_run M59 record-only-diff.sh '    [ -z "$sn_h" ] || { printf' '    true || { printf' \
    story_hist "FAIL sh-ldel:" "a story deleted before the base and re-added read as created after it"
  # M66 restores the unanchored pathspec, so under -C a subdirectory the walk names a cwd-relative path that never
  # existed and the deleted-and-re-added story reads as created after the base (sh-subdir reads 0).
  CS_ONLY=story-hist mut_run M66 record-only-diff.sh '-- ":(top,literal)$sb_rel"' '-- "$sb_rel"' \
    story_hist "FAIL sh-subdir:" "the story history walked a pathspec relative to the -C directory, not the repository top"
  # BL-895, canon_gate's STORY-BIND. m-row-exit keys the row binding on story-status's EXIT (it exits 0 on a path no
  # entry names), so the review-like seed passes. m-no-index drops the basename-index check, so a listed sibling story
  # listed by a key-only row (no history pair for the re-key check) passes for the wrong review. m-worktree reads the row at the checked-out HEAD instead of the frozen sha, so a story
  # whose row exists only at the frozen sha is refused. m-serial-only lets the merge's owner past every STORY-BIND
  # refusal, so the merge acquits a non-story --story.
  CS_ONLY=cr-bind-seed mut_run m-row-exit merge-review-shards.sh '    [ "$cg_rw_" = ok ] \' \
    '    mrs_sib "$cg_ss_" ss_main story-status --ref "$cg_z_" --root "$cg_r_" "$cg_sr_" > /dev/null 2>&1 < /dev/null \' \
    canon "cr-bind-seed{rc=0 SERIAL-OK:" "the row binding keyed on story-status's exit code"
  CS_ONLY=cr-bind-sibling-pre mut_run m-no-index merge-review-shards.sh '    if ! story_idx_ok "${cg_sr_##*/}" "$cg_i_"; then' '    if false; then' \
    canon "cr-bind-sibling-pre{rc=0 SERIAL-OK:" "the basename index check dropped"
  # WV955, canon_gate's waiver. m-wv-skip never asks the waiver test (it reads NOT-WAIVED), so a base-time waiver over a
  # code range is refused. m-wv-frozen reads the story at <frozen>, so an entry added inside the range waives the run.
  # m-wv-seat honours the waiver whoever wrote the base, so the seat's own --range acquits its own story text.
  CS_ONLY=wv955-accepted mut_run m-wv-skip merge-review-shards.sh '    cg_wv_="$(mrs_sib "$RO" ro_main waiver' '    cg_wv_="$(false' \
    wv955 "wv955-accepted{rc=2" "the waiver test never asked"
  CS_ONLY=wv955-inrange mut_run m-wv-frozen merge-review-shards.sh '"$STORY_F" "$cg_b_" "$cg_run_"' '"$STORY_F" "$cg_z_" "$cg_run_"' \
    wv955 "wv955-inrange{rc=0" "the waiver read at the frozen sha"
  CS_ONLY=wv955-seat mut_run m-wv-seat merge-review-shards.sh '        if [ "$cg_lw_" != lead ]; then' '        if false; then' \
    wv955 "wv955-seat[range]{rc=0" "the waiver honoured over a seat-supplied base"
  # BL-895 B1 and D1. m-single-file drops the one-story-per-index refusal, so a fresh story the view lists under another
  # key passes beside the real one; since b1 the view's history refuses that world too, so the mutant is scored on
  # cr-bind-xdir, whose second index-1-5 entry declares a file: in another directory, which the history skips as another
  # sprint's. m-digit-slug drops the digit rule from the single-sourced index predicate (the
  # --story check and the candidate filter both), so index 2 names story-2-1-y.md.
  CS_ONLY=cr-bind-xdir mut_run m-single-file merge-review-shards.sh \
    '        refuse_to "$cg_o_" "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and --story $STORY_F is not the only story under that index: the implementation' \
    '        : "STORY-BIND: $cg_f_ claims the record-only exemption for story index $cg_i_, and --story $STORY_F is not the only story under that index: the implementation' \
    canon "cr-bind-xdir{rc=0 SERIAL-OK:" "the one-story-per-index refusal dropped"
  # BL-895 R1 and R2. m-status-skip restores the skip of a view entry with no status:, so the laundered base whose x row
  # carries none reads as nothing listed; it is scored on cr-bind-xdir-nostat, the other-directory entry without a status:,
  # which the view's history cannot see. m-index-grammar drops the review-index grammar, so a review named for a slug
  # (1-1-z-qa-validation.md) carries index 1-1-z and acquits the fresh story-1-1-z.md under it.
  CS_ONLY=cr-bind-xdir-nostat mut_run m-status-skip merge-review-shards.sh "      while IFS=\$'\\t' read -r cg_k_ cg_s_ cg_d_ cg_p_; do" \
    "      while IFS=\$'\\t' read -r cg_k_ cg_s_ cg_d_ cg_p_; do [ \"\$cg_s_\" != - ] || continue" \
    canon "cr-bind-xdir-nostat{rc=0 SERIAL-OK:" "a view entry with no status: skipped by the one-story-per-index check"
  CS_ONLY=cr-bind-longidx mut_run m-index-grammar merge-review-shards.sh '    [ -n "$cg_i_" ] && idx_ok "$cg_i_" \' '    [ -n "$cg_i_" ] \' \
    canon "cr-bind-longidx{rc=0 SERIAL-OK:" "the review-index grammar dropped"
  # BL-895 b1. m-endpoint-only feeds the history check only view-history's `since` marker, so the walk still runs and
  # passes its fail-closed test but names nothing: the base whose record-only commit deleted x's row reads as clean.
  CS_ONLY=cr-launder-rowdel mut_run m-endpoint-only merge-review-shards.sh '    done <<<"$cg_vh_"' "    done <<<\"\${cg_vh_%%\$'\\n'*}\"" \
    canon "cr-launder-rowdel{rc=0 SERIAL-OK:" "the view's history walk reduced to its endpoint marker"
  # BL-895, THE HISTORY'S OWN TRUST (sprint-status.sh view_history). m-date-born picks the creation commit by date (the
  # oldest-dated adder), so a backdated side commit merged --no-ff moves the walk past the launder. m-shallow-ok drops the
  # shallow refusal, so a boundary at the base reads as the root; it is scored on hist-shallow-blob, where z is a blob at
  # the base, because story-base's own shallow refusal (BL-904) also refuses hist-shallow. m-replace drops GIT_NO_REPLACE_OBJECTS from ss_main's
  # python line, so a replace ref rewrites the base's view. m-story-dir keys the stories directory on --story's own
  # directory again, so a story in a directory created in the range starts the walk there. m-crlf reads a ref's view with
  # its \r kept, so a CRLF view gives no `sprint:`. m-sprint drops the base-versus-frozen sprint check.
  CS_ONLY=cr-hist-merge mut_run m-date-born sprint-status.sh '        born = [c for c in adds.split() if obj("%s^1:%s" % (c, sdir))[0] is None]' \
    '        born = adds.split()[-1:]' canon "cr-hist-merge{rc=0 SERIAL-OK:" "the stories directory's creation chosen by date, not ancestry"
  CS_ONLY=cr-hist-shallow-blob mut_run m-shallow-ok sprint-status.sh '    if head[0] != "false":' '    if False:' \
    canon "cr-hist-shallow-blob{rc=0 SERIAL-OK:" "a shallow repository's boundary read as the root"
  CS_ONLY=cr-hist-replace mut_run m-replace sprint-status.sh "GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts python3 -I - <<'PY'" \
    "GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts python3 -I - <<'PY'" canon "cr-hist-replace{rc=0 SERIAL-OK:" "a replace ref honoured by the view's readers"
  CS_ONLY=cr-hist-dir mut_run m-story-dir sprint-status.sh '        sdir = os.path.normpath(stories_dir(sprint))' '        sdir = os.path.dirname(story)' \
    canon "cr-hist-dir{rc=0 SERIAL-OK:" "the walk keyed on --story's own directory, not the sprint's stories directory"
  CS_ONLY=cr-hist-crlf mut_run m-crlf sprint-status.sh '    return text.replace("\r\n", "\n").replace("\r", "\n")' '    return text' \
    canon "cr-hist-crlf{rc=2" "a CRLF view read with its carriage returns"
  # U1h: m-sprint drops the check that the view reads the review's sprint at the base and the frozen sha; its deciding
  # cell is cr-sprint-view, whose story sits in the review's own sprint directory, so nothing else refuses it.
  CS_ONLY=cr-sprint-view mut_run m-sprint sprint-status.sh '            if vsprint != sprint:' '            if False:' \
    canon "cr-sprint-view{rc=0 SERIAL-OK:" "the view's sprint not compared with the review's"
  # BL-895 U1h. m-view-sprint takes the sprint from the frozen view, not the review's path (0889420fd's shape), so the
  # faked roll moves the stories directory and the walk starts after the launder. m-schema-env lets the seat's
  # AI_DLC_SPRINT_STATUS_SCHEMA through to STORY-BIND's sprint-status calls. m-gwt drops the merge's entry scrub of git's
  # GIT_DIR / GIT_WORK_TREE family. m-roll-drop-off removes the creation commit's drop of an earlier sprint's retired
  # value, so a real roll whose old row spelled `stories/...` refuses. m-roll-drop-every widens that drop to every commit
  # of the walk, so an intermediate commit's sprint launders a value.
  CS_ONLY=cr-sprint-roll1 mut_run m-view-sprint sprint-status.sh '        sprint = want' \
    '        sprint = parse(obj("%s:%s" % (full, view_rel))[1] or "")[0]' \
    canon "cr-sprint-roll1{rc=0 SERIAL-OK:" "the sprint read from the frozen view, not the review's path"
  CS_ONLY=cr-schema-env mut_run m-schema-env merge-review-shards.sh 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA AI_DLC_PROJECT_ROOT; ' 'ss_bound() { ( unset AI_DLC_PROJECT_ROOT; ' \
    canon "cr-schema-env{rc=0 SERIAL-OK:" "the seat's schema override honoured by STORY-BIND"
  CS_ONLY=cr-root-env mut_run m-root-env merge-review-shards.sh 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA AI_DLC_PROJECT_ROOT; ' 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA; ' \
    canon "cr-root-env{rc=0 SERIAL-OK:" "the seat's AI_DLC_PROJECT_ROOT honoured by STORY-BIND's schema lookup"
  CS_ONLY=cr-sprint-relpath mut_run m-relpath merge-review-shards.sh '      sr_n_="$(cd "$(dirname "$SERIAL")" 2> /dev/null && review_sprint "$(pwd)")" || sr_n_=""' \
    '      sr_n_="$(review_sprint "$(dirname "$SERIAL")")" || sr_n_=""' \
    canon "cr-sprint-relpath{rc=2" "the sprint parsed from a relative review path's literal dirname"
  CS_ONLY=cr-gwt mut_run m-gwt merge-review-shards.sh 'unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES' ':' \
    canon "cr-gwt{rc=0 SERIAL-OK:" "a GIT_WORK_TREE in the seat's environment honoured"
  CS_ONLY=cr-roll-ok mut_run m-roll-drop-off sprint-status.sh '                delta -= prior_sprint(c, prev - cur)' '                pass' \
    canon "cr-roll-ok{rc=2" "an earlier sprint's retired row, spelled stories/..., kept at the roll"
  CS_ONLY=cr-roll-mid mut_run m-roll-drop-every sprint-status.sh '            if c == born:' '            if True:' \
    canon "cr-roll-mid{rc=0 SERIAL-OK:" "the earlier-sprint drop applied at every commit of the walk"
  # U1i. m-legacy-env drops the checked repository's own qa.md from the --check-serial LEGACY decision, so the qa.md under
  # the seat-chosen AI_DLC_PROJECT_ROOT acquits alone and a redirect skips the whole canonical-run rule, STORY-BIND included.
  # The merge path has no row: it reads qa.md at the manifest's frozen sha in the manifest's worktree and never ROOT.
  CS_ONLY=cr-serial-redirect mut_run m-legacy-env merge-review-shards.sh '      base) grep -qF -- "$CANON_SENTINEL" "$ROLE_MD" ||' '      base) sr_held_=0; sr_leg_="$ROLE_MD"; grep -qF -- "$CANON_SENTINEL" "$ROLE_MD" ||' \
    canon "cr-serial-redirect{rc=0" "the seat's project root alone deciding the canonical-run LEGACY skip"
  # U1g. The same six history mutants scored on the MERGE path: a second row each, with its own id, deciding on the
  # canon_merge cell of the same refusal, because the matrix scores a mutant on the cells of its own predicate only.
  CS_ONLY=crm-hist-merge mut_run m-date-born-merge sprint-status.sh '        born = [c for c in adds.split() if obj("%s^1:%s" % (c, sdir))[0] is None]' \
    '        born = adds.split()[-1:]' \
    canon_merge "crm-hist-merge{rc=0" "the stories directory's creation chosen by date, not ancestry, on the merge path"
  CS_ONLY=crm-hist-shallow mut_run m-shallow-ok-merge sprint-status.sh '    if head[0] != "false":' \
    '    if False:' \
    canon_merge "crm-hist-shallow{rc=0" "a shallow repository's boundary read as the root, on the merge path"
  CS_ONLY=crm-hist-replace mut_run m-replace-merge sprint-status.sh "GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts python3 -I - <<'PY'" \
    "GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts python3 -I - <<'PY'" \
    canon_merge "crm-hist-replace{rc=0" "a replace ref honoured by the view's readers, on the merge path"
  CS_ONLY=crm-hist-dir mut_run m-story-dir-merge sprint-status.sh '        sdir = os.path.normpath(stories_dir(sprint))' \
    '        sdir = os.path.dirname(story)' \
    canon_merge "crm-hist-dir{rc=0" "the walk keyed on --story's own directory, not the sprint's stories directory, on the merge path"
  CS_ONLY=crm-sprint-view mut_run m-sprint-merge sprint-status.sh '            if vsprint != sprint:' \
    '            if False:' \
    canon_merge "crm-sprint-view{rc=0" "the view's sprint not compared with the review's, on the merge path"
  CS_ONLY=crm-sprint-roll mut_run m-view-sprint-merge sprint-status.sh '        sprint = want' \
    '        sprint = parse(obj("%s:%s" % (full, view_rel))[1] or "")[0]' \
    canon_merge "crm-sprint-roll{rc=0" "the sprint read from the frozen view, not the shard directory's s<N>, on the merge path"
  CS_ONLY=crm-schema-env mut_run m-schema-env-merge merge-review-shards.sh 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA AI_DLC_PROJECT_ROOT; ' 'ss_bound() { ( unset AI_DLC_PROJECT_ROOT; ' \
    canon_merge "crm-schema-env{rc=0" "the lead's schema override honoured by STORY-BIND, on the merge path"
  CS_ONLY=crm-root-env mut_run m-root-env-merge merge-review-shards.sh 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA AI_DLC_PROJECT_ROOT; ' 'ss_bound() { ( unset AI_DLC_SPRINT_STATUS_SCHEMA; ' \
    canon_merge "crm-root-env{rc=0" "the lead's AI_DLC_PROJECT_ROOT honoured by STORY-BIND's schema lookup, on the merge path"
  CS_ONLY=crm-bind-hist mut_run m-endpoint-only-merge merge-review-shards.sh '    done <<<"$cg_vh_"' \
    "    done <<<\"\${cg_vh_%%\$'\\n'*}\"" \
    canon_merge "crm-bind-hist{rc=0" "the view's history walk reduced to its endpoint marker, on the merge path"
  CS_ONLY=cr-bind-trunc mut_run m-digit-slug merge-review-shards.sh '  case "$si_r_" in [0-9]*) return 1 ;; esac' '  case "$si_r_" in NEVER-A-NAME) return 1 ;; esac' \
    canon "cr-bind-trunc{rc=0 SERIAL-OK:" "the slug-opens-with-a-digit rule dropped"
  # A3b. m-letter-idx reverts STORY-BIND's index grammar to the numeric-only one, so the letter-led B1 carries no index;
  # m-idx-pattern turns story_idx_ok's literal prefix comparison into an unquoted case pattern built from the index text,
  # so index `B?` matches story-B1-x.md.
  CS_ONLY=cr-b1-right mut_run m-letter-idx merge-review-shards.sh \
    '  case "$ix_s_" in [ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz]*) case "$ix_s_" in */* | *.* | *[[:space:]]*) return 1 ;; esac; return 0 ;; esac' '  :' \
    canon "cr-b1-right{rc=2" "STORY-BIND's index grammar reverted to digits only, so B1 is refused"
  CS_ONLY=cr-glob-literal mut_run m-idx-pattern merge-review-shards.sh '  [ "${1:0:${#si_p_}+1}" = "$si_p_-" ] || return 1' \
    '  case "$1" in story-$2-*) ;; *) return 1 ;; esac' \
    canon "cr-glob-literal{rc=0 " "the index matched as a pattern, so B? names story-B1-x.md"
  CS_ONLY=cr-bind-ok mut_run m-worktree merge-review-shards.sh 'ss_bound story-status --ref "$cg_z_" --root' 'ss_bound story-status --ref HEAD --root' \
    canon "cr-bind-ok{rc=2" "the row read at the checked-out HEAD, not the frozen sha"
  CS_ONLY=crm-bind mut_run m-serial-only merge-review-shards.sh '    # STORY-BIND (header: THE EXEMPTION): --story is the story file the implementation view lists at <frozen>.' \
    '    refuse_to() { case "$1:$2" in serial:*) ;; *:STORY-BIND*) return 0 ;; esac; OWNER="$1"; shift; refuse "$*${CG_NOTE:-}"; }' \
    canon_merge "crm-bind{rc=0" "the binding held only when the owner is serial"
  # BL-956, THE ROW STEM RULE (merge-review-shards.sh stem_rows), one mutant per site, each keeping only the literal
  # story_idx_ok rule there. m956-1102: the index binding by the frozen row's key dropped, so the bare index refuses
  # the story its row names. m956-1132: the one-story loop's key disjunct dropped, so a second entry keyed under the
  # index in another directory passes. m956-1145: the history's key disjunct dropped, so a historic row keyed under the
  # index naming another file passes.
  CS_ONLY=bind956-binds mut_run m956-1102 merge-review-shards.sh '      { [ -n "$cg_rk_" ] && cg_sk_="$(stem_rows "$cg_rk_")" && [ "$cg_sk_" = "$cg_rk_" ]; } \' '      false \' \
    bind956 "bind956-binds{rc=2" "the bare index no longer binds through the frozen row's key"
  CS_ONLY=bind956-onestory mut_run m956-1132 merge-review-shards.sh '          || { [ "$cg_p_" != "$STORY_F" ] && [ "${cg_d_##*/}" != "${STORY_F##*/}" ] && [ -n "$cg_k_" ] && case' '          || { false && case' \
    bind956 "bind956-onestory{rc=0 SERIAL-OK:" "the one-story loop counts an entry by its literal basename only"
  CS_ONLY=bind956-hist mut_run m956-1145 merge-review-shards.sh '        || { [ -n "$cg_hk_" ] && case' '        || { false && case' \
    bind956 "bind956-hist{rc=0 SERIAL-OK:" "the view's history counts a value by its literal basename only"
  # m956-rekey (the pair skipped), m956-rekey-ko (the pair read as an index-named one): the history's re-key refusal
  # dropped, so --story bound by a frozen row the range re-keyed passes with story 6 absent (rekey) and key-only
  # (rekey-ko) at the base; two distinct edits, so neither shares the other's copy. m956-stem:
  # stem-names reads the key with story_key_stem, every sprint-equal component stripped, so in sprint 3 story-3-3 names
  # no index and story-3-1-3 names 1.
  CS_ONLY=bind956-rekey mut_run m956-rekey merge-review-shards.sh '        cg_rx_=rekey' '        continue' \
    bind956 "bind956-rekey{rc=0 SERIAL-OK:" "the view's history no longer holds --story's own rows to the index"
  CS_ONLY=bind956-rekey-ko mut_run m956-rekey-ko merge-review-shards.sh '        cg_rx_=rekey' '        cg_rx_=""' \
    bind956 "bind956-rekey-ko{rc=0 SERIAL-OK:" "the view's history no longer holds --story's own rows to the index (key-only base)"
  # m956-window: the re-key check reads --story's pairs from the creation (the `file` lines) instead of from --base to
  # frozen (the `window` lines), so a re-key the lead made in planning, before the base, refuses.
  CS_ONLY=bind956-prebase mut_run m956-window merge-review-shards.sh '        [ "$cg_k_" = window ] || continue' '        :' \
    bind956 "bind956-prebase{rc=2" "the re-key check reads --story's pairs from before --base"
  CS_ONLY=bind956-stem mut_run m956-stem sprint-status.sh '        if _k and story_key_index_stem(_k, _sp) == "story-" + _ix:' '        if _k and story_key_stem(_k, _sp) == "story-" + _ix:' \
    bind956 "bind956-stem{3=[]" "stem-names strips every sprint-equal key component"
  # BL-790. M41 the advisor absence refusal deleted, so a sentinel-era shard with no line merges. M42 the
  # era check deleted, so the absence is refused in the legacy world too.
  CS_ONLY=ad-q-present-absent mut_run M41 merge-review-shards.sh "  else refuse \"\$1 carries no column-0 'advisor:' line" "  else : \"\$1 carries no column-0 'advisor:' line" \
    adv_qa "ad-q-present-absent{" "the advisor absence refusal deleted"
  CS_ONLY=ad-q-legacy-absent mut_run M42 merge-review-shards.sh '  if [ "$ADV_AT" = legacy ]; then' '  if false; then' \
    adv_qa "ad-q-legacy-absent{" "the advisor era check deleted, so a legacy shard's absence is refused"
  # BL-808. M43 the flag parsed but the exclusion not applied. M44 the captures dropped from the FILE
  # SET as well as the count, so the flagged map differs from the merge's flagless re-run -- killed
  # through the merge's own map-cmp refusal. M45 the list's LENGTH subtracted, not its intersection.
  # M46 the one-counted-file SERIAL rule (C8) removed.
  CS_ONLY=xc-flip mut_run M43 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' '  :' xc_flip "xc-flip{" \
    "the --exclude-captures list parsed but not subtracted from the count"
  CS_ONLY=xc-merge mut_run M44 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' \
    '  NF_REV=$((NF_REV - XC)); awk -F'"'"'\t'"'"' '"'"'FNR == NR { sub(/\r$/, ""); L[$0] = 1; next } !($2 in L)'"'"' "$XCAP" "$T/files" > "$T/files.x" && mv "$T/files.x" "$T/files"' \
    xc_merge "differs from the map it records" "the cited captures dropped from the file set, not only from the count"
  CS_ONLY=xc-count mut_run M45 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' '  XC="$(grep -c . "$XCAP")"; NF_REV=$((NF_REV - XC))' \
    xc_count "xc-count{" "the list length subtracted instead of its intersection with the counted files"
  CS_ONLY=xc-one mut_run M46 partition-review-diff.sh '  if [ "$NF_REV" -le 1 ]; then' '  if false; then' xc_one "xc-one{" \
    "the one-counted-file SERIAL rule removed"
  # BL-811. m-k2only restores the K=2-only rule (a lone cross.md refused wherever the table has more
  # than one row), so the lone-cross cell goes red on its own refusal text. m-nomix drops the mixed
  # refusal, so cross.md beside cross-1..3 is no longer refused as a mix.
  CS_ONLY=x-lone-k8 mut_run m-k2only merge-review-shards.sh 'if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi' \
    '[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] && refuse "$SDIR holds cross.md, but the part map has $K parts, whose cross groups are $XTABLE_KEYS; a single cross shard is owed only at K=2"; if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi' \
    x_lone "owed only at K=2" "the K=2-only lone-cross rule restored"
  CS_ONLY=x-mix mut_run m-nomix merge-review-shards.sh '[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \' 'false \' \
    x_mix "x-mix{" "the mixed cross.md + cross-<g>.md refusal dropped"
  # BL-844. M47 the Class lift restored to code review only, so a qa shard's FOO merges. M48 the empty-set
  # guard dropped, so a qa.md with no template refuses every Class value (the legacy fail-open lost).
  CS_ONLY=qc-foo mut_run M47 merge-review-shards.sh 'CLASS_SET="$(awk "$CLASS_SET_AWK" "$ROLE_MD"' 'CLASS_SET=""; [ "$GATE" != code-review ] || CLASS_SET="$(awk "$CLASS_SET_AWK" "$ROLE_MD"' \
    qclass "qc-foo{" "the Class lift restored to --gate code-review only"
  CS_ONLY=qc-none mut_run M48 merge-review-shards.sh '  [ -n "$CLASS_SET" ] || return 0' '  :' \
    qclass "qc-none{" "the empty-set guard dropped, so a role file with no template checks every Class value"
  # BL-809 item 2, THE FILES LINE. M52 a Files: line on an EVIDENCE finding accepted. M53 the frozen-sha
  # path check removed. M54 a backtick allowed in an entry. M55 a second Files: line accepted. M56 an
  # empty list accepted.
  CS_ONLY=fl-nc mut_run M52 merge-review-shards.sh '      FNC) refuse "' '      FNC) : "' \
    files "fl-nc{" "a Files: line on a non-CODE/TEST finding accepted"
  CS_ONLY=fl-gone mut_run M53 merge-review-shards.sh '    grep -qxF -- "$cg_v_" "$T/files-known" \' '    true \' \
    files "fl-gone{" "the frozen-sha path check removed"
  CS_ONLY=fl-tick mut_run M54 merge-review-shards.sh 'e ~ /[`:,[:blank:]]/' 'e ~ /[:,[:blank:]]/' \
    files "fl-tick{" "a backtick allowed inside a Files: entry"
  CS_ONLY=fl-dup mut_run M55 merge-review-shards.sh 'if (inf && nfl > 1) print "FDUP\t" fln2' 'if (0) print "FDUP\t" fln2' \
    files "fl-dup{" "a second Files: line in one finding accepted"
  CS_ONLY=fl-empty mut_run M56 merge-review-shards.sh 'else if (fv == "") print "FEMPTY\t" fln1' 'else if (0) print "FEMPTY\t" fln1' \
    files "fl-empty{" "an empty Files: list accepted"
  # M57 the range's diff-name-only allowance dropped, so a Files: entry naming a file the rework DELETED is refused.
  CS_ONLY=fl-del mut_run M57 merge-review-shards.sh ' && git -C "$M_WT" -c core.quotePath=false diff --name-only --no-renames "${M_BASE}..${M_SHA}"; }' '; }' \
    files "fl-del{" "a Files: entry naming a file the range deleted refused"
  # BL-895 F1, THE LEAD'S RE-RUN (lib.sh p_lead). m-lead-anc drops the dispatch-to-go-signal ancestry (a3's orphan pair
  # passes). m-record-key writes the record under another key, so --lead-range finds no `dispatch:` and the written
  # record reads as absent (LEGACY-UNRECORDED). m-record-path writes it beside the common dir's stories/ directory. m-unrec-
  # refuse turns an absent record into a refusal; m-unrec-silent drops its LEGACY-UNRECORDED line. m-record-ignored takes the
  # base from the seat even when a record exists. m-rsha-eq drops the value comparison. m-rsha-always holds the line
  # whatever qa.md says (the legacy dispatch refused); m-rsha-off never holds it. m-live-ref reads qa.md at the live sprint
  # ref, not the recorded dispatch sha. m-qa-at-F reads it at the go-signal sha (a strip inside the range reaches LEGACY);
  # m-disk-qa reads the working tree. m-slot-loose restores the leading-digits slot parse (s1x reads sprint 1);
  # m-lead-slot drops the physical-slot check.
  CS_ONLY=lr-orphan mut_run m-lead-anc merge-review-shards.sh \
    '        GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/ai-dlc-no-grafts git -C "$sr_repo_" merge-base --is-ancestor "$sr_b_" "$sr_f_" 2> /dev/null < /dev/null \' \
    '        true \' lead "lr-orphan{rc=0" "the go-signal's descent from the dispatch sha unchecked"
  CS_ONLY=lr-record mut_run m-record-key merge-review-shards.sh '  lead_record_put . "$RD_NAME" dispatch "$rd_sha_"' '  lead_record_put . "$RD_NAME" dispatched "$rd_sha_"' \
    lead "lr-record{" "the dispatch record written under another key"
  CS_ONLY=lr-record mut_run m-record-path merge-review-shards.sh "  printf '%s/ai-dlc/stories/%s' \"\$lr_c_\" \"\$2\"" "  printf '%s/ai-dlc/%s' \"\$lr_c_\" \"\$2\"" \
    lead "lr-record{" "the dispatch record written beside the stories directory"
  CS_ONLY=lr-norecord mut_run m-unrec-refuse merge-review-shards.sh '        sr_b_=""' '        refuse "no dispatch record at $sr_rp_"; sr_b_=""' \
    lead "lr-norecord{rc=2" "an absent dispatch record refused instead of LEGACY-UNRECORDED"
  CS_ONLY=lr-norecord mut_run m-unrec-silent merge-review-shards.sh "        printf 'LEGACY-UNRECORDED: " "        : 'LEGACY-UNRECORDED: " \
    lead "lr-norecord{LEGACY-UNRECORDED line: 0" "the LEGACY-UNRECORDED line dropped"
  CS_ONLY=lr-seatbase mut_run m-record-ignored merge-review-shards.sh '      if sr_rd_="$(lead_record_get "$sr_repo_" "$sr_rn_" dispatch)" \' \
    '      if false && sr_rd_="$(lead_record_get "$sr_repo_" "$sr_rn_" dispatch)" \' lead "lr-seatbase{rc=0" "the seat base used though a dispatch record exists"
  CS_ONLY=lr-rsha-ne mut_run m-rsha-eq merge-review-shards.sh '        [ "$sr_rv_" = "$sr_f_" ] \' '        true \' \
    lead "lr-rsha-ne{rc=0" "the reviewed-sha value not compared with the go-signal sha"
  CS_ONLY=lr-rsha-legacy mut_run m-rsha-always merge-review-shards.sh '      if [ -n "$SR_QA_AT" ] && grep -qF -- "$RSHA_SENTINEL" "$T/qa-at-b"; then' \
    '      if true; then' lead "lr-rsha-legacy{rc=2" "the reviewed-sha line held whatever qa.md at the dispatch sha prescribes"
  CS_ONLY=lr-rewind mut_run m-rsha-off merge-review-shards.sh '      if [ -n "$SR_QA_AT" ] && grep -qF -- "$RSHA_SENTINEL" "$T/qa-at-b"; then' \
    '      if false; then' lead "lr-rewind{rc=0" "the reviewed-sha gate dropped"
  CS_ONLY=lr-rewind mut_run m-live-ref merge-review-shards.sh '    sr_qa_at "$sr_repo_" "$sr_b_" || SR_QA_AT=""' \
    '    sr_qa_at "$sr_repo_" "$(git -C "$sr_repo_" rev-parse -q --verify refs/heads/sprint 2> /dev/null || printf %s "$sr_b_")" || SR_QA_AT=""' \
    lead "lr-rewind{rc=0" "qa.md read at the live sprint ref, not the recorded dispatch sha"
  CS_ONLY=lr-rsha-strip mut_run m-qa-at-F merge-review-shards.sh '    sr_qa_at "$sr_repo_" "$sr_b_" || SR_QA_AT=""' '    sr_qa_at "$sr_repo_" "$sr_f_" || SR_QA_AT=""' \
    lead "lr-rsha-strip{rc=0" "qa.md read at the go-signal sha, so a strip inside the range reaches LEGACY"
  CS_ONLY=lr-disk-qa mut_run m-disk-qa merge-review-shards.sh '    sr_qa_at "$sr_repo_" "$sr_b_" || SR_QA_AT=""' '    sr_qa_at "$sr_repo_" "" || SR_QA_AT=""' \
    lead "lr-disk-qa{rc=0" "qa.md read off the review repository's working tree"
  CS_ONLY=cr-slot-suffix mut_run m-slot-loose merge-review-shards.sh '  case "$rs_n_" in *[!0-9]*) return 1 ;; esac' '  rs_n_="${rs_n_%%[!0-9]*}"' \
    lead "cr-slot-suffix{rc=0" "the slot parse reading the leading digits, so s1x is sprint 1"
  CS_ONLY=lr-slot mut_run m-lead-slot merge-review-shards.sh \
    '        && sr_ln_="$(review_sprint "$(dirname "$SERIAL")")" && [ "$sr_pd_" = "$sr_top_/docs/reviews/s$sr_ln_" ] \' '        && sr_ln_="$(review_sprint "$(dirname "$SERIAL")")" \' \
    lead "lr-slot[" "the lead's physical-slot check dropped"
  # BL-895 A3. m-rec-idx reverts the lead record's name grammar to idx_ok, so a digit-led slug index (5-browser-smoke) is
  # refused. idx_ok takes a letter-led index since A3b, so a3-letter (B1) cannot decide it; a3-slug does.
  CS_ONLY=a3-slug mut_run m-rec-idx merge-review-shards.sh '  rec_idx_ok "$lr_i_" || return 1' '  idx_ok "$lr_i_" || return 1' \
    lead "a3-slug{" "the lead record's name keyed on idx_ok, so 5-browser-smoke is refused"
  # BL-895 U1k. m-py-isolated runs sprint-status.sh's python without -I again, so a json.py in the seat's cwd answers
  # story-status and view-history; m-one-sprint drops the logical/physical one-sprint check, so a link naming s2 over an
  # s1 directory chooses the sprint. Each is scored on the serial cell and again, as a -merge row, on the merge's.
  CS_ONLY=cr-py-cwd mut_run m-py-isolated sprint-status.sh "ai-dlc-no-grafts python3 -I - <<'PY'" "ai-dlc-no-grafts python3 - <<'PY'" \
    canon "cr-py-cwd{rc=0 SERIAL-OK:" "sprint-status.sh's python reading modules from the caller's cwd"
  CS_ONLY=crm-py-cwd mut_run m-py-isolated-merge sprint-status.sh "ai-dlc-no-grafts python3 -I - <<'PY'" "ai-dlc-no-grafts python3 - <<'PY'" \
    canon_merge "crm-py-cwd{rc=0" "sprint-status.sh's python reading modules from the caller's cwd, on the merge path"
  CS_ONLY=cr-sprint-link mut_run m-one-sprint merge-review-shards.sh '  [ "$os_l_" = "$os_p_" ] \' '  true \' \
    canon "cr-sprint-link{rc=0 SERIAL-OK:" "the review's logical and physical sprints not compared"
  CS_ONLY=crm-sprint-link-check mut_run m-one-sprint-merge merge-review-shards.sh '  [ "$os_l_" = "$os_p_" ] \' '  true \' \
    canon_merge "crm-sprint-link-check{" "the shard directory's logical and physical sprints not compared, under --check-shard (where shard_slot does not run)"
  # BL-895 U1k (adversary 5a). m-ro-mode stops record-only-diff.sh's paths mode reading an entry's mode, so a range that
  # commits docs/reviews/s1 as a symlink to s2 reads RECORD-ONLY and the exemption accepts it.
  CS_ONLY=cr-exempt-link mut_run m-ro-mode record-only-diff.sh '          case "$rp_m" in 120000|160000) first=' '          case "$rp_m" in NEVER-A-MODE) first=' \
    canon "cr-exempt-link{rc=0 SERIAL-OK:" "a symlink committed under a record class classed record-only"
  # U1l. m-rec-write writes the manifest's base as the recorded sha, so the read-back refuses the real partition.
  # m-rec-base and m-rec-sha drop the record-versus-.manifest checks. m-rec-era drops the recorded era from the LEGACY
  # decision, so a range that strips qa.md's sentinel acquits. m-unrec refuses an unrecorded partition instead of
  # merging it as 0.994.0. m-run-bind keeps STORY-BIND on the no-run branch only (serial and -merge rows).
  CS_ONLY=lr-ok mut_run m-rec-write merge-review-shards.sh '&& lead_record_put "$pr_d_" "$pr_nm_" "partition-sha.$pr_sb_" "$pr_s_" \' \
    '&& lead_record_put "$pr_d_" "$pr_nm_" "partition-sha.$pr_sb_" "$pr_b_" \' lead_rec "lr-ok{" "--record-partition writes the base as the sha"
  # m-rec-unkeyed keys the merge's read on the story alone (the newest recorded pass), not this shard directory, so a
  # re-partition merged before it is recorded is compared with the earlier pass and refused.
  CS_ONLY=lr-repass mut_run m-rec-unkeyed merge-review-shards.sh '  pr_k_="$SB"' \
    '  pr_k_="$(awk -F": " '"'"'$1 ~ /^partition-sha\./ { k = substr($1, 15) } END { print k }'"'"' "$(lead_record_path "$SDIR" "s${pr_n_:-?}-$IDX")" 2> /dev/null)"' \
    lead_rec "lr-repass{" "the record read for the story's last recorded pass, not this shard directory"
  CS_ONLY=lr-move mut_run m-rec-base merge-review-shards.sh '    [ "$pr_b_" = "$M_BASE" ] \' '    true \' \
    lead_rec "lr-move{" "the record's base not compared with .manifest's"
  CS_ONLY=lr-sha mut_run m-rec-sha merge-review-shards.sh '    [ "$pr_s_" = "$M_SHA" ] \' '    true \' \
    lead_rec "lr-sha{" "the record's sha not compared with .manifest's"
  CS_ONLY=lr-9a mut_run m-rec-era merge-review-shards.sh '  [ "$PR_ERA" != held ] || cr_held_=1' '  :' \
    lead_rec "lr-9a{" "the recorded era dropped from the LEGACY decision"
  CS_ONLY=lr-unrec mut_run m-unrec merge-review-shards.sh '    PR_ERA=""' '    refuse "no partition record"' \
    lead_rec "lr-unrec{" "an unrecorded partition refused instead of merged as before"
  CS_ONLY=lr-run-bind-serial mut_run m-run-bind merge-review-shards.sh '  if [ "$cg_x_" = 1 ] || { [ -n "$STORY_F" ] && [ -n "$cg_z_" ]; }; then' \
    '  if [ "$cg_x_" = 1 ]; then' lead_rec "lr-run-bind-serial{" "STORY-BIND held on the no-run branch only, in --check-serial"
  CS_ONLY=lr-run-bind mut_run m-run-bind-merge merge-review-shards.sh '  if [ "$cg_x_" = 1 ] || { [ -n "$STORY_F" ] && [ -n "$cg_z_" ]; }; then' \
    '  if [ "$cg_x_" = 1 ]; then' lead_rec "lr-run-bind{" "STORY-BIND held on the no-run branch only, on the merge"
  # THE LEAD CHECKOUT (tip adversary 5, A1 and A2), one mutant per site: m-lc-serial drops the --lead-range check, so a
  # redirected gitfile reads no record and checks the seat's base; m-lc-record drops --record-partition's, so the record
  # is written under the seat's clone; m-lc-merge drops the merge's, so a redirected shard directory reads no record and
  # merges LEGACY-UNRECORDED over a seat's manifest. Each site is on one path only, so none carries a -merge row.
  CS_ONLY=a1-redirect mut_run m-lc-serial merge-review-shards.sh '      lead_checkout_only "$sr_repo_" "--lead-range: the review'"'"'s repository"' '      :' \
    lead "a1-redirect{" "the lead's re-run not held to the lead checkout's git common dir"
  CS_ONLY=a2-record mut_run m-lc-record merge-review-shards.sh '  lead_checkout_only "$pr_d_" "--record-partition: the shard directory"' '  :' \
    lead_rec "a2-record{" "--record-partition not held to the lead checkout's git common dir"
  CS_ONLY=a2-redirect mut_run m-lc-merge merge-review-shards.sh '  lead_checkout_only "$SDIR" "the qa merge: the shard directory"' '  :' \
    lead_rec "a2-redirect{" "the qa merge not held to the lead checkout's git common dir"
  # D1 (delta adversary), THE SHARD DIRECTORY'S SLOT (shard_slot), one mutant per site: m-d1-merge hands the merge's
  # check the physical path, so logical and physical cannot differ and a symlinked shard directory reads another slot's
  # (absent) record, LEGACY-UNRECORDED; m-d1-record does the same to --record-partition, which then records under s5;
  # m-d1-name drops the refusal of a path naming no slot, so a directory outside shards/ merges `s-<idx>` unrecorded;
  # m-d1-abs compares the two spellings as absolute paths, so a checkout under a symlinked prefix is refused.
  CS_ONLY=d1-symlink-sprint mut_run m-d1-merge merge-review-shards.sh '  shard_slot "$SDIR_IN" "the qa merge: the shard directory"; pr_n_="$SS_N"' \
    '  shard_slot "$SDIR" "the qa merge: the shard directory"; pr_n_="$SS_N"' lead_rec "d1-symlink-sprint{" "the qa merge's shard directory not compared as given and physically"
  CS_ONLY=d1-record-link mut_run m-d1-record merge-review-shards.sh '  shard_slot "$pr_l_" "--record-partition: the shard directory"; pr_n_="$SS_N"' \
    '  shard_slot "$pr_d_" "--record-partition: the shard directory"; pr_n_="$SS_N"' lead_rec "d1-record-link{" "--record-partition's shard directory not compared as given and physically"
  CS_ONLY=d1-outside mut_run m-d1-name merge-review-shards.sh '  [ "$ss_t_" != "$ss_r_" ] && [ -n "$SS_N" ] \' '  true \' \
    lead_rec "d1-outside{" "a shard directory naming no s<N> slot merged as an unrecorded partition"
  CS_ONLY=d1-prefix-alias mut_run m-d1-abs merge-review-shards.sh '    case "$sl_l_" in */"$sl_r_") ;; *) exit 1 ;; esac' \
    '    [ "$sl_l_" = "$sl_p_" ] || exit 1' lead_rec "d1-prefix-alias{" "the shard directory's two spellings compared as absolute paths"
  # BL-905, THE RUN RECORD. M60 skips the binding, so a typed pair merges in a held era. M61 drops the sha from the
  # lookup, so this pass's run recorded at another sha binds. M62 reads a story with no recorded run as LEGACY. M63
  # restricts the lookup to this pass's own key, so an earlier pass's run at the same sha is refused. M64 skips the
  # record-only predicate, so an earlier pass's run over a code change is reused.
  CS_ONLY=rr-fab mut_run M60 merge-review-shards.sh '  run_bind "$cg_f_" "$cg_o_" "$cg_res_" "$cg_c_"' '  :' \
    run_rec "rr-fab{rc=0" "the canonical result not bound to a recorded run"
  CS_ONLY=rr-stale mut_run M61 merge-review-shards.sh '$1 == k && $2 == s { print $1; f = 1; exit }' '$1 == k { print $1; f = 1; exit }' \
    run_rec "rr-stale{rc=0" "this pass's run accepted at another sha"
  CS_ONLY=rr-fab mut_run M62 merge-review-shards.sh '  [ -n "$rb_all_" ] || refuse_to' '  [ -n "$rb_all_" ] || return 0 || refuse_to' \
    run_rec "rr-fab{rc=0" "a story with no recorded run read as LEGACY in a held era"
  CS_ONLY=rr-earlier-eq mut_run M63 merge-review-shards.sh '$2 == s && e == "" { e = $1 }' '$2 == s && e == "" && 0 { e = $1 }' \
    run_rec "rr-earlier-eq{rc=2" "the lookup restricted to this pass's own key"
  CS_ONLY=rr-cross-code mut_run M64 merge-review-shards.sh 'rb_po_="$(mrs_sib "$RO" ro_main paths -C "$RB_WT" "$STORY_F" "$rb_es_" "$RB_SHA" 2>&1 < /dev/null)"' 'rb_po_=""' \
    run_rec "rr-cross-code{rc=0" "an earlier pass's run reused without the record-only predicate"
  # M65 drops the installed qa.md (ROLE_MD) from the serial era, so a review repository's stripped qa.md acquits.
  CS_ONLY=rr-s-lead mut_run M65 merge-review-shards.sh '      case "$SR_ERA" in role|base) RB_ERA=held ;; esac' '      case "$SR_ERA" in base) RB_ERA=held ;; esac' \
    run_rec "rr-s-lead{rc=0" "the serial run-record era acquitted by the review repository's own qa.md"
  # M67 reads the serial form's frozen sha off the worktree's own HEAD again, so the HEAD check compares HEAD with HEAD
  # and a run in a worktree checked out at another sha than --frozen is recorded.
  CS_ONLY=rr-s-head mut_run M67 merge-review-shards.sh '    rr_s_="$rr_fz_"; rr_rp_="$rr_wt_"' \
    '    rr_s_="$(git --no-replace-objects -C "$rr_wt_" rev-parse -q --verify HEAD 2> /dev/null < /dev/null)"; rr_rp_="$rr_wt_"' \
    run_rec "rr-s-head{rc=0" "the serial --record-run's frozen sha read off the worktree's own HEAD"
  # M68 drops the compare of the `Canonical run:` invocation with the recorded one, so a recorded replay merges behind a
  # review naming the canonical command. M69 drops the recorded invocation's RUN-FILTER, so a `-m=unit` run recorded
  # under a declaration since removed merges behind a `Canonical run:` line (`-munit`) that RUN-FILTER passes and that
  # normalises to the recorded invocation (rr-rbind; BL-988's pre-check now refuses rr-rfilter's run before it runs).
  CS_ONLY=rr-replay mut_run M68 merge-review-shards.sh '  [ "$(rr_norm "$rb_rs_")" = "$(rr_norm "$rb_ri_")" ] \' '  true \' \
    run_rec "rr-replay{rc=0" "the Canonical run: invocation not compared with the recorded invocation"
  CS_ONLY=rr-rbind mut_run M69 merge-review-shards.sh '  rb_rf_="$(mrs_sib "$RO" ro_main run-filter "\`$rb_ri_\`" ${4:+"$4"})" \' '  rb_rf_="" \' \
    run_rec "rr-rbind{rc=0" "the recorded invocation not held to RUN-FILTER"
  # M70 restores the generic last-count-line rule over per-test lines, so a cut-off verbose run records `test_case_3
  # PASSED [ 99%]` as its summary. M71 drops the pytest session line's preference, so a log line after it is recorded.
  CS_ONLY=rr-sum-cut mut_run M70 merge-review-shards.sh ' && $0 !~ /::/ && $0 !~ /( PASSED| FAILED).*\[ *[0-9]+%\]/) c = NR' ') c = NR' \
    run_rec "rr-sum-cut{rc=0" "a per-test progress line recorded as the run's summary"
  CS_ONLY=rr-sum-log mut_run M71 merge-review-shards.sh '          else if (ps) s = trim(l[ps])' '          else if (0) s = trim(l[ps])' \
    run_rec "rr-sum-log{got 'INFO cleaned 2 errors'" "a log line after pytest's session line recorded as the run's summary"
  # M72 restores the installed qa.md's (ROLE_MD's) hold under --lead-range, so after a pull a serial story whose base
  # qa.md prescribes no --record-run is refused where the merge reads the same base LEGACY.
  CS_ONLY=rr-s-lrl mut_run M72 merge-review-shards.sh '      sr_era "$RUN_SENTINEL" "$sr_bd_"' '      sr_era "$RUN_SENTINEL" 0' \
    run_rec "rr-s-lrl{rc=2" "the lead's re-run era held by the installed qa.md over the tracked base blob"
  # M75 restores the installed qa.md's hold for the canonical lines under --lead-range (sr_era's base flag dropped at
  # that call alone), so a PASS with no run line over a base whose qa.md predates the label is refused.
  CS_ONLY=rr-c-lrl mut_run M75 merge-review-shards.sh 'sr_era "$CANON_SENTINEL" "$sr_bd_"' 'sr_era "$CANON_SENTINEL" 0' \
    run_rec "rr-c-lrl{rc=2" "the lead's re-run canonical-lines era held by the installed qa.md over the tracked base blob"
  # M76 lets the tracked base blob decide the era whether or not the story's dispatch is recorded, so a LEGACY-UNRECORDED
  # story's seat chooses its own era by choosing an old base, and a typed pair the installed qa.md holds reads SERIAL-OK.
  CS_ONLY=rr-s-lru mut_run M76 merge-review-shards.sh '] && [ "${sr_rec_:-0}" = 1 ]; then sr_bd_=1; fi' ']; then sr_bd_=1; fi' \
    run_rec "rr-s-lru{rc=0" "the seat-supplied base of an unrecorded story deciding the lead's re-run era"
  # M74 records the invocation as `$*` again, so a quoted multi-word marker (`-m 'a and b'`) is recorded as `-m a and b`,
  # which RUN-FILTER reads as the marker `a`, and a run the conventions declare canonical cannot merge.
  CS_ONLY=rr-mq mut_run M74 merge-review-shards.sh 'rr_quote "$@"; rr_inv_="${RR_Q' 'rr_inv_="$*"; rr_inv_="${rr_inv_' \
    run_rec "rr-mq{" "the recorded invocation joined with \$*, its quoting dropped"
  # BL-988, THE DECLARED WRAPPER and RECORD = CHECK. m988-w2 matches any program to a declaration (W2), so an undeclared
  # wrapper is recorded, its sentinel written. m988-w3 reads only the `-*` tokens before the bare -- (W3), so a positional
  # there passes. m988-w4 reads a wrapper's payload flags-only, as the no-pytest branch reads every token (W4), so an
  # undeclared payload sub-path passes. m988-quote drops the quote guard, so `'--junitxml=x>y'` reads as a redirect and
  # the test file after it is never read. m988-loop advances the conventions line AFTER decl(), whose own match() reset
  # RSTART and RLENGTH: the non-consuming loop an earlier draft shipped, scored only through wr_bounded's kill switch.
  # m988-n2 restores RUN-SHAPE's refusal of a declared wrapper outside its declaration, so --prelude beside a count is
  # no run. m988-w6 removes --record-run's pre-check (its RUN-FILTER ask answers 0 unasked), so a -k run is recorded;
  # m988-w6s adds RUN-SHAPE to it, so a program only RUN-SHAPE refuses, recorded at base, is refused. m988-1041 deletes
  # the no-summary refusal after the run, so a run with no count is recorded.
  CS_ONLY=rr-w-undecl mut_run m988-w2 record-only-diff.sh 'for (d = 1; d <= nd; d++) { if (!pm(p, DP[d])) continue' 'for (d = 1; d <= nd; d++) { if (0) continue' \
    wrap "rr-w-undecl{rc=0 sentinel=present" "W2 matching any program to a declaration"
  CS_ONLY=wr-pos mut_run m988-w3 record-only-diff.sh '        if (t !~ /^-/) return "hands the declared wrapper "' '        if (t !~ /^-/) continue; if (0) return "hands the declared wrapper "' \
    wrap "wr-pos{rc=0" "W3 reading only the -* tokens before the bare --"
  CS_ONLY=wr-subpath mut_run m988-w4 record-only-diff.sh "        ok\$'\\n'*) rf_a=\"\${RW#ok\$'\\n'}\" ;;" \
    "        ok\$'\\n'*) rf_a=\"\$(printf '%s' \"\${RW#ok\$'\\n'}\" | awk '/^-/ && \$0 != \"-m\" && \$0 != \"-c\"')\" ;;" \
    wrap "wr-subpath{rc=0" "W4 reading a wrapper's payload flags-only, as the all-branch reads"
  CS_ONLY=wr-d4 mut_run m988-quote record-only-diff.sh "        case \"\$w\" in \\'*|\\\"*) ;; '|'|" "        case \"\$w\" in '|'|" \
    wrap "wr-d4{rc=0" "rf_args reading a quoted token as a shell operator"
  CS_ONLY=wr-term mut_run m988-loop record-only-diff.sh 'line = substr(line, RSTART + RLENGTH); decl(sp) }' 'decl(sp); line = substr(line, RSTART + RLENGTH) }' \
    wrap "wr-term{rc=1 [" "the conventions-line loop advancing after decl() clobbered RSTART and RLENGTH"
  CS_ONLY=wr-prelude mut_run m988-n2 record-only-diff.sh "      case \"\$RW\" in ok|ok\$'\\n'*) exit 0 ;; esac" "      case \"\$RW\" in ok|ok\$'\\n'*) exit 0 ;; x*) exit 1 ;; esac" \
    wrap "wr-prelude{rc=1" "RUN-SHAPE refusing a declared wrapper outside its declaration whatever count it carries"
  CS_ONLY=rr-w-kfoo mut_run m988-w6 merge-review-shards.sh '  rr_pf_="$(mrs_sib "$rr_ro_" ro_main run-filter' '  rr_pf_="$(true "$rr_ro_" ro_main run-filter' \
    wrap "rr-w-kfoo{rc=0 sentinel=present" "--record-run's RUN-FILTER pre-check removed"
  CS_ONLY=rr-w-shape mut_run m988-w6s merge-review-shards.sh '  rr_t_="$(mktemp -d "${TMPDIR:-/tmp}/record-run.XXXXXX")"' \
    '  mrs_sib "$rr_ro_" ro_main run-shape "\`$rr_inv_\`" ${rr_cv_:+"$rr_cv_"} > /dev/null 2>&1 < /dev/null || refuse "--record-run: RUN-SHAPE reads no run; nothing was run or recorded"; rr_t_="$(mktemp -d "${TMPDIR:-/tmp}/record-run.XXXXXX")"' \
    wrap "rr-w-shape{rc=2 sentinel=absent" "--record-run's pre-check also applying RUN-SHAPE"
  # m988-d3 drops the rule that a declaration's placeholders after -- name pytest, so `git checkout -- <file>` declares
  # git. m988-fb removes the plain reading's claim on a span with a pytest token before the payload, so a filtered
  # pytest run ahead of a wrapper run on one line passes. m988-prefix matches an option by prefix, so `--pyth` is --python.
  CS_ONLY=wr-d3git mut_run m988-d3 record-only-diff.sh 'if (!nt || !py) return' 'if (!nt) return' \
    wrap "wr-d3git{rc=0" "a placeholder-only span declaring a wrapper whether or not a placeholder names pytest"
  CS_ONLY=wr-fallback mut_run m988-fb record-only-diff.sh '        if (st == 0 && t ~ /^(.*\/)?(pytest|py\.test)$/) { print "none"; exit 0 }' \
    '        if (0 && st == 0 && t ~ /^(.*\/)?(pytest|py\.test)$/) { print "none"; exit 0 }' \
    wrap "wr-fallback{rc=0" "a pytest token before the payload left to the wrapper reading"
  # m988-st2 widens that claim to every token before the payload (`st < 2`, the shipped defect), so a declared option's
  # VALUE ending in pytest (`--artifact /x/pytest`) hands the span to the plain reading and the undeclared option passes.
  CS_ONLY=wr-artpy1 mut_run m988-st2 record-only-diff.sh '        if (st == 0 && t ~ /^(.*\/)?(pytest|py\.test)$/) { print "none"; exit 0 }' \
    '        if (st < 2 && t ~ /^(.*\/)?(pytest|py\.test)$/) { print "none"; exit 0 }' \
    wrap "wr-artpy1{rc=0" "a declared option's value ending in pytest read as a pytest run"
  CS_ONLY=wr-prefix mut_run m988-prefix record-only-diff.sh '        if (index(os, "|" o "=1|")) { if (i < nw && W[i + 1] !~ /^-/) i++; continue }' \
    '        if (index(os, "|" o)) { if (i < nw && W[i + 1] !~ /^-/) i++; continue }' \
    wrap "wr-prefix{rc=0" "a wrapper option matched by prefix"
  # m988-arity gives every declared option a value, so the positional after the no-value --quiet is swallowed as one.
  # m988-ph drops the rule that every token after a declaration's -- is a placeholder, so `-- --watch <pytest args>`
  # declares scripts/w2.py. m988-slash matches an absolute program by a bare suffix, so /x/evilscripts/w.py is
  # scripts/w.py. m988-oper drops the quote guard of the wrapper reader's own operator test, so a wrapper payload's
  # `'--junitxml=x>y'` ends the payload and the test file after it is never read.
  CS_ONLY=wr-arity mut_run m988-arity record-only-diff.sh '        o = t; ar = 0' '        o = t; ar = 1' \
    wrap "wr-arity{rc=0" "every declared wrapper option read as taking a value"
  CS_ONLY=wr-ph mut_run m988-ph record-only-diff.sh 'nt++; if (!ph(t)) return;' 'nt++;' \
    wrap "wr-ph{rc=0" "a declaration's tokens after -- not held to placeholders"
  CS_ONLY=wr-slash mut_run m988-slash record-only-diff.sh 'substr(r, length(r) - length(d)) == "/" d' 'substr(r, length(r) - length(d) + 1) == d' \
    wrap "wr-slash{rc=0" "an absolute wrapper program matched by a bare suffix, not by path components"
  CS_ONLY=wr-d4w mut_run m988-oper record-only-diff.sh 'function oper(t) { if (quoted(t)) return 0; return' 'function oper(t) { return' \
    wrap "wr-d4w{rc=0" "the wrapper reader taking a quoted token for a shell operator"
  CS_ONLY=rr-nosum mut_run m988-1041 merge-review-shards.sh '    || refuse "--record-run: the run exited $rr_rc_ and its output' '    || : "--record-run: the run exited $rr_rc_ and its output' \
    run_rec "rr-nosum{rc=0" "a run whose output carries no summary line recorded"
  # BL-918, THE FOUR CLAIMS (header: WHAT IS AT STAKE), one mutant each in the merge. M77 the last shard's verdict
  # wins, not the worst (W_disc's cross is APPROVED). M78 the part set read off the shard directory, not the
  # re-derived map, so a missing part is never named. M79 Check 1's exactly-once test widened to at least once, so a
  # shard body's '## Verdict' merges. M80 the Check-1 refusal writes the staged review at --out before refusing.
  CS_ONLY=w-disc mut_run M77 merge-review-shards.sh '  if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi' \
    '  WORST_R="$r"; WORST="$v"' worst "w-disc{" "the last shard's verdict merged, not the worst"
  CS_ONLY=miss-ord mut_run M78 merge-review-shards.sh 'ORDINALS="$(cut -f1 "$T/map" | tr '"'"'\n'"'"' '"'"' '"'"')"' \
    'ORDINALS="$(for f in "$SDIR"/[0-9]*.md; do [ -e "$f" ] && basename "$f" .md; done | tr '"'"'\n'"'"' '"'"' '"'"')"' \
    miss_ord "miss-ord{" "the part set read off the shard directory, not re-derived from the manifest"
  CS_ONLY=a3-two mut_run M79 merge-review-shards.sh '[ "$n1" = "1" ] || refuse_to "$(pat_owners)"' '[ "$n1" -ge 1 ] || refuse_to "$(pat_owners)"' \
    a3 "a3-two{" "Check 1's pattern matched at least once, not exactly once"
  CS_ONLY=a3-two mut_run M80 merge-review-shards.sh '[ "$n1" = "1" ] || refuse_to "$(pat_owners)"' \
    '[ "$n1" = "1" ] || cp "$T/out" "$OUT"; [ "$n1" = "1" ] || refuse_to "$(pat_owners)"' \
    a3 "a3-two{" "a refusal that writes the staged review at --out"
  # The matrix, or the twins. A plain run scores no matrix cell and runs at least one twin per mutant; a
  # --matrix run scores the matrix and runs no twin. Either way the count below is the mode's own.
  _mx_n="$(grep -c . "$MX_ROWS")" || _mx_n=0
  if [ "$RSM_MATRIX" = 1 ]; then
    : > "$WORK/mx-log"; matrix_score
    ip_load "$SRCDIR/merge-review-shards.sh" || bad "MX1: FIXTURE ERROR -- SRCDIR's merge was not loaded back after the matrix"
    reuse_proof
    if [ -n "$RSM_SLICE_N" ]; then
      # A slice records all 177 rows, scores exactly the cells of the rows its k/n selects among the rows this run is
      # dealt (all 177 with no --group; the shard's with one), their populations read off the full record, and runs no twin.
      _mx_want=0; [ "$RSM_SLICE_K" -ge "$MUT_MINE_N" ] || _mx_want=$(( (MUT_MINE_N - 1 - RSM_SLICE_K) / RSM_SLICE_N + 1 ))
      if [ "$_mx_n" = 177 ] && [ "$MX_SROWS" = "$_mx_want" ] && [ "$MX_CELLS" = "$MX_SPOP" ] && [ "$TWIN_N" = 0 ]; then
        ok "MX1: --matrix slice $RSM_SLICE_K/$RSM_SLICE_N scored $MX_CELLS mutant x cell pairs, the populations of its $MX_SROWS of $_mx_n recorded mutants ($MX_TPOP pairs in all), and ran no twin"
      else bad "MX1: --matrix slice $RSM_SLICE_K/$RSM_SLICE_N scored $MX_CELLS pairs over $MX_SROWS rows (want $_mx_want rows and $MX_SPOP pairs, of $MX_TPOP), $_mx_n recorded mutants (want 177), twins run $TWIN_N"; fi
    elif [ "$MX_CELLS" -gt "$_mx_n" ] && [ "$TWIN_N" = 0 ] && [ "$_mx_n" = 177 ]; then
      ok "MX1: --matrix scored $MX_CELLS mutant x cell pairs over $_mx_n mutants and ran no twin"
    else bad "MX1: --matrix scored $MX_CELLS pairs over $_mx_n recorded mutants, twins run $TWIN_N"; fi
  else
    if [ "$MX_CELLS" = 0 ] && [ "$_mx_n" = 0 ] && [ "$TWIN_N" -ge "$MUT_MINE_N" ] && [ "$MUT_MINE_N" -gt 0 ]; then
      ok "MX1: a plain run scored no matrix cell and ran $TWIN_N twin cells, at least one per mutant of the $MUT_MINE_N this shard is dealt, each passing over its mutant copy"
    else bad "MX1: a plain run scored $MX_CELLS matrix cells ($_mx_n recorded mutants) and ran $TWIN_N twins, want 0, 0 and at least $MUT_MINE_N (this shard's deal)"; fi
  fi
  # VBCTL: every mutant's own cell passed over the unmutated derived copy first (mut_run), one per mutant.
  # The count is the shard's DEAL, derived by J0 from the mut_run calls before any mutant ran; under --matrix every unit
  # records all 177, each control first (J0 refuses any other total).
  if { [ "$RSM_MATRIX" = 0 ] && [ "$VB_CTL_N" = "$MUT_MINE_N" ]; } || { [ "$RSM_MATRIX" = 1 ] && [ "$VB_CTL_N" = 177 ]; }; then ok "VBCTL: CONTROL -- this shard's dealt mutants among each of M1-M72, M74-M80, m-k2only, m-nomix, m-row-exit, m-no-index, m-worktree, m-single-file, m-digit-slug, m-serial-only, m-status-skip, m-index-grammar, m-endpoint-only, m-date-born, m-shallow-ok, m-replace, m-story-dir, m-crlf, m-sprint, m-view-sprint, m-schema-env, m-root-env, m-relpath, m-gwt, m-roll-drop-off, m-roll-drop-every, m-legacy-env, m-py-isolated, m-one-sprint, m-ro-mode, m-lead-anc, m-record-key, m-record-path, m-unrec-refuse, m-unrec-silent, m-record-ignored, m-rsha-eq, m-rsha-always, m-rsha-off, m-live-ref, m-qa-at-F, m-disk-qa, m-slot-loose, m-lead-slot, m-rec-write, m-rec-unkeyed, m-rec-base, m-rec-sha, m-rec-era, m-unrec, m-run-bind, m-rec-idx, m-letter-idx, m-idx-pattern, m-lc-serial, m-lc-record, m-lc-merge, m-d1-merge, m-d1-record, m-d1-name, m-d1-abs, m-wv-skip, m-wv-frozen, m-wv-seat, m956-1102, m956-1132, m956-1145, m956-rekey, m956-rekey-ko, m956-window and m956-stem's selected cells, and the twelve -merge rows, passed unmutated ($VB_CTL_N of the $MUT_MINE_N dealt here, 177 in all): by the same run's passing arm over the byte-identical source set, else over the unmutated copy of the derived sibling set every mutant is built from"
  else bad "VBCTL: FIXTURE ERROR -- $VB_CTL_N of the $MUT_MINE_N mutants dealt to this shard had their cells pass over the unmutated copy, so the other verdicts are not evidence"; fi
  # MS1 (BL-906): the twelve byte-identical pairs share one copy each; every other mutant built its own.
  # The pairs dealt here: J0 counts, per shard, each mutant whose (file, old, new) an earlier mutant of the same shard made.
  # Under --matrix every mutant is recorded, so the whole fixture's 12 pairs share and 165 copies are built.
  if { [ "$RSM_MATRIX" = 0 ] && [ "$MUT_SHARED" = "$MUT_MINE_SHARED" ] && [ "$MUT_KN" = $((MUT_MINE_N - MUT_MINE_SHARED)) ] && [ "$MUT_SHARED" -ge 1 ]; } \
     || { [ "$RSM_MATRIX" = 1 ] && [ "$MUT_SHARED" = 12 ] && [ "$MUT_KN" = 165 ]; }; then ok "MS1: the $MUT_SHARED byte-identical mutant pair(s) dealt here drove one shared copy each ($MUT_KN copies built for $([ "$RSM_MATRIX" = 1 ] && echo 177 || echo "$MUT_MINE_N") mutants)"
  else bad "MS1: $MUT_SHARED mutants drove a shared copy and $MUT_KN copies were built, want $MUT_MINE_SHARED and $((MUT_MINE_N - MUT_MINE_SHARED))"; fi
  # KS1 (BL-906): the KILL SET of a plain run is exactly the shard's deal -- every mutant J0 dealt here was killed
  # through mutant_killed in THIS run, once, and nothing else was. J0 proves the deal covers the fixture; KS1 proves the
  # shard killed what it was dealt, so a deal that skips a mutant at run time cannot read as coverage. The join is
  # rsm_partition_ok, whose self-probe ran in J0. --matrix records rows and kills nothing, so KS1 is a plain-run arm.
  # ks1_judge is KS1's whole verdict (receipt-bl906.sh check (4) extracts and runs it); KS1_N counts its runs here.
  KS1_N=0
  ks1_judge() { # reads MUT_MINE MUT_MINE_N MUT_SCORED WORK -> one KS1 ok or FAIL line
    KS1_N=$((KS1_N + 1))
    printf '%s\n' $MUT_MINE > "$WORK/ks-dealt"; printf '%s' "$MUT_SCORED" > "$WORK/ks-scored"
    if _ks="$(rsm_partition_ok "$WORK/ks-dealt" "$WORK/ks-scored")" && [ "$MUT_MINE_N" -gt 0 ]; then
      ok "KS1: every one of the $MUT_MINE_N mutants dealt to this shard scored its kill here through mutant_killed, once, and no other did"
    else bad "KS1: this shard's kill set is not its deal of $MUT_MINE_N -- scored twice / dealt but not scored / scored but not dealt: $_ks"; fi
  }
  if [ "$RSM_MATRIX" = 0 ]; then
    ks1_judge
  fi
  # KS1-CTL (BL-906): KS1 must be able to fail. On every plain run it hands ks1_judge, in a subshell, THIS run's kill
  # set less its first id, and asserts the FAIL line naming exactly that id as dealt to no shard -- so a ks-scored that
  # is not MUT_SCORED (K2) or a verdict that cannot fail (K3) breaks it. It also asserts KS1 itself ran once (K1).
  # Its guard is spelled apart from KS1's so one edit cannot switch both off. K1-K3 are hand-scored mutants of this
  # file, like M73, with no mut_run call:
  #   K1: the RSM_MATRIX test guarding the ks1_judge call compares with 1, not 0 -- KS1 never runs on a plain run.
  #   K2: ks1_judge writes ks-scored from MUT_MINE, one id per line, not from MUT_SCORED -- the deal joins itself.
  #   K3: ks1_judge's else branch calls ok, not bad -- KS1 cannot fail.
  case "$RSM_MATRIX" in 0)
    _ks_nl=$'\n'; _ks_drop="${MUT_SCORED%%"$_ks_nl"*}"; _ks_rest="${MUT_SCORED#*"$_ks_nl"}"
    _ks_ctl="$(MUT_SCORED="$_ks_rest"; ks1_judge)"
    _ks_want="dealt twice: {} dealt to no shard: {$_ks_drop} dealt but not declared: {}"
    if [ "$KS1_N" = 1 ] && [ -n "$_ks_drop" ] && [ "$_ks_rest" != "$MUT_SCORED" ] \
       && case "$_ks_ctl" in "  FAIL  KS1: "*"$_ks_want") true ;; *) false ;; esac \
       && [ "$(printf '%s\n' "$_ks_ctl" | grep -c .)" = 1 ]; then
      ok "KS1-CTL: KS1 ran once, and refused this run's kill set less $_ks_drop, naming it as dealt to no shard"
    else bad "KS1-CTL: KS1 ran $KS1_N time(s) (want 1), and over this run's kill set less '$_ks_drop' it printed: ${_ks_ctl:-nothing}"; fi
    ;;
  esac
else
  echo "  (BL-737 mutants M1-M6, and BL-740's CONTROL and M7-M11, not run: $SRCDIR is the consumer layout, whose scripts the consumer cannot edit)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
