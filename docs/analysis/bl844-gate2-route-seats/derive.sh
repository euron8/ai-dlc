#!/usr/bin/env bash
# BL-844: QA seats per gate-2 re-validation (pass M >= 2), graph s320 (before) against s321 and
# s322 (after), read ONLY from committed graph refs (git ls-tree / git show; no fetch, no checkout).
#
# Usage: bash derive.sh [<graph repo path>] [<ref>]     (defaults: /Users/n8/git/graph main)
# Runs from any cwd: every read is `git -C <graph>` against "${REF}:<path>".
#
# ROUTE SOURCE.
#   s321, s322: the gate plan `_bmad-output/implementation-artifacts/s<N>/gate-transition/<idx>-g2-p<M>.plan`,
#     written by core/scripts/gate-transition.sh (0.1006.0 and later). Its `route:` line is the route;
#     `partitioned` dispatches one QA seat per shard line (`<n><TAB>...`) plus one cross seat, so
#     seats = shard lines + 1; `record-only` and `serial` dispatch one seat. Any other route value is
#     printed and counted UNKNOWN (no seat figure is invented for it).
#     AGREEMENT: a partitioned plan must have a committed shard dir
#     `docs/reviews/s<N>/shards/*-qa-validation-<plan sha12>-p<M>/` holding exactly seats .md files,
#     and a record-only or serial plan must have none. Each plan is also joined to its review file
#     `docs/reviews/s<N>/*-qa-validation-p<M>.md` by `reviewed-sha:` == the plan's `sha:`.
#   s320: no gate plan exists (gate-transition.sh did not). A re-validation is a review file
#     `docs/reviews/s320/<story>-qa-validation-p<M>.md`, M >= 2. FANOUT = a committed shard dir
#     `<story>-qa-validation-<hash>-p<M>/` with its .md count as seats; SERIAL = the review file's
#     title line says `serial` (1 seat); SINGLE = no shard dir, no `Merged by merge-review-shards.sh`
#     line and no `serial` title: one unmerged file, its seat count NOT declared anywhere, so it is
#     bounded (1 if one seat wrote it, 5 if a fan-out left no shard dir) and both bounds are printed.
set -u
GRAPH="${1:-/Users/n8/git/graph}"
REF="${2:-main}"
GREP=/usr/bin/grep
P=_bmad-output/implementation-artifacts
NEG=ZZNOPE-8f3a1q

SHA="$(git -C "$GRAPH" rev-parse --verify -q "${REF}^{commit}")" || { echo "derive.sh: cannot resolve ${REF} in ${GRAPH}" >&2; exit 2; }
echo "graph ${GRAPH} ref ${REF} = ${SHA}"
TREE="$(git -C "$GRAPH" ls-tree -r --name-only "$SHA" -- "$P" docs/reviews)"
NT="$(printf '%s\n' "$TREE" | $GREP -c .)"
[ "$NT" -gt 0 ] || { echo "derive.sh: empty listing under ${P} and docs/reviews at ${SHA}" >&2; exit 2; }
echo "listing: ${NT} paths under ${P} and docs/reviews"

# NEGATIVE CONTROL, verified absent first: the token must occur in no path and in no file content at
# this ref, or it is not a control.
nneg_path="$(printf '%s\n' "$TREE" | $GREP -c -F -- "$NEG")" || nneg_path=0
nneg_body="$(git -C "$GRAPH" grep -c -F -- "$NEG" "$SHA" -- "$P" docs/reviews | $GREP -c .)" || nneg_body=0
npos_body="$(git -C "$GRAPH" grep -c -F -- "reviewed-sha:" "$SHA" -- "$P" docs/reviews | $GREP -c .)" || npos_body=0
echo "negative control ${NEG}: ${nneg_path} paths, ${nneg_body} files carrying it (both must be 0); the same content grep for reviewed-sha: reads ${npos_body} files (must be > 0)"
[ "$nneg_path" = 0 ] && [ "$nneg_body" = 0 ] || { echo "derive.sh: the negative-control token is present; pick another" >&2; exit 2; }
[ "$npos_body" -gt 0 ] || { echo "derive.sh: the content grep found no reviewed-sha: line; it cannot fire" >&2; exit 2; }
nneg_dir="$(printf '%s\n' "$TREE" | $GREP -c "^docs/reviews/${NEG}/shards/[^/]*qa-validation[^/]*/[^/]*\.md$")" || nneg_dir=0
echo "negative control shard-dir join on sprint ${NEG}: ${nneg_dir} .md files (must be 0)"
[ "$nneg_dir" = 0 ] || { echo "derive.sh: the shard-dir join matched an impossible sprint; it cannot discriminate" >&2; exit 2; }

# POSITIVE CONTROL: the same .md count over a known full fan-out dir (s320 4-2 p2) must read 5.
POS=docs/reviews/s320/shards/4-2-qa-validation-39921dda7498-p2
npos="$(printf '%s\n' "$TREE" | $GREP -c "^${POS}/[^/]*\.md$")" || npos=0
echo "positive control ${POS}: ${npos} .md files (must be 5)"
[ "$npos" = 5 ] || { echo "derive.sh: positive control did not read 5" >&2; exit 2; }

mdcount() { local n; n="$(printf '%s\n' "$TREE" | $GREP -c "^${1}/[^/]*\.md$")" || n=0; echo "$n"; }

for S in s321 s322; do
  echo "== ${S} (after): route source = gate plan"
  plans="$(printf '%s\n' "$TREE" | $GREP -E "^${P}/${S}/gate-transition/[^/]*-g2-p[0-9]+\.plan$")" || plans=""
  revs="$(printf '%s\n' "$TREE" | $GREP -E "^docs/reviews/${S}/[^/]*qa-validation-p[0-9]+\.md$")" || revs=""
  n=0; seats=0; unk=0; agree=0; dis=0; rp=0; rs=0; rr=0; matched=""
  for f in $plans; do
    b="${f##*/}"; pass="${b##*-p}"; pass="${pass%.plan}"
    [ "$pass" -ge 2 ] || continue
    body="$(git -C "$GRAPH" show "${SHA}:${f}")"
    route="$(printf '%s\n' "$body" | sed -n 's/^route: \([a-z0-9-]*\).*/\1/p' | head -1)"
    psha="$(printf '%s\n' "$body" | sed -n 's/^sha: \([0-9a-f]*\).*/\1/p' | head -1)"
    sha12="$(printf '%.12s' "$psha")"
    nsh="$(printf '%s\n' "$body" | $GREP -cE '^[0-9]+	')" || nsh=0
    case "$route" in
      partitioned) st=$((nsh + 1)); rp=$((rp + 1)) ;;
      record-only) st=1; rr=$((rr + 1)) ;;
      serial) st=1; rs=$((rs + 1)) ;;
      *) st="?"; unk=$((unk + 1)) ;;
    esac
    dir="$(printf '%s\n' "$TREE" | $GREP "^docs/reviews/${S}/shards/[^/]*qa-validation-${sha12}-p${pass}/" | sed 's#/[^/]*$##' | sort -u | head -1)"
    nmd=0; [ -n "$dir" ] && nmd="$(mdcount "$dir")"
    if [ "$route" = partitioned ]; then
      [ -n "$dir" ] && [ "$nmd" = "$st" ] && ok=AGREE || ok=DISAGREE
    else
      [ -z "$dir" ] && ok=AGREE || ok=DISAGREE
    fi
    [ "$ok" = AGREE ] && agree=$((agree + 1)) || dis=$((dis + 1))
    rev=""
    for r in $revs; do
      rb="${r##*-p}"; rb="${rb%.md}"; [ "$rb" = "$pass" ] || continue
      rsha="$(git -C "$GRAPH" show "${SHA}:${r}" | sed -n 's/^reviewed-sha: *`\{0,1\}\([0-9a-f]*\).*/\1/p' | head -1)"
      [ -n "$rsha" ] && [ "$rsha" = "$psha" ] && { rev="${rev}${rev:+,}${r##*/}"; matched="${matched} ${r}"; }
    done
    [ "$st" != "?" ] && seats=$((seats + st))
    n=$((n + 1))
    dn=none; [ -n "$dir" ] && dn="${dir##*/}"
    printf '  %s p%s route=%s shard_lines=%s seats=%s shard_dir=%s md=%s %s review=%s\n' \
      "${b%-g2-p*}" "$pass" "${route:-NONE}" "$nsh" "$st" "$dn" "$nmd" "$ok" "${rev:-NONE}"
  done
  nrev=0; unrev=""
  for r in $revs; do
    rb="${r##*-p}"; rb="${rb%.md}"; [ "$rb" -ge 2 ] || continue
    nrev=$((nrev + 1))
    case " ${matched} " in *" ${r} "*) ;; *) unrev="${unrev} ${r##*/}"
      # Not joined by sha: print the review file's own seat and route text beside its reviewed-sha.
      git -C "$GRAPH" show "${SHA}:${r}" | $GREP -m3 -E 'shard: |route: |^reviewed-sha:' | sed "s#^#    unjoined ${r##*/}: #" ;;
    esac
  done
  # A .captures with no .plan: first map a dotted index (2.4) onto its hyphenated plan (2-4).
  capo=""; capd=0
  for c in $(printf '%s\n' "$TREE" | $GREP -E "^${P}/${S}/gate-transition/[^/]*-g2-p[0-9]+\.captures$"); do
    cb="${c##*-p}"; cb="${cb%.captures}"; [ "$cb" -ge 2 ] || continue
    printf '%s\n' "$plans" | $GREP -qxF -- "${c%.captures}.plan" && continue
    cn="${c##*/}"; hy="$(printf '%s' "${cn%-g2-p*}" | tr . -)-g2-p${cb}.plan"
    printf '%s\n' "$plans" | $GREP -qxF -- "${c%/*}/${hy}" && { capd=$((capd + 1)); continue; }
    capo="${capo} ${cn}"
  done
  ns=$((n - unk))
  echo "  ${S}: ${n} re-validations from plans: partitioned ${rp}, record-only ${rr}, serial ${rs}, unknown ${unk}; seats ${seats}"
  [ "$ns" -gt 0 ] && awk -v s="$seats" -v n="$ns" 'BEGIN { printf "  seats per re-validation: %.2f (%d seats / %d classified)\n", s / n, s, n }'
  echo "  plan/shard-dir agreement: ${agree} AGREE, ${dis} DISAGREE"
  echo "  review files at pass >= 2: ${nrev}; joined to a plan by reviewed-sha: $((nrev - $(printf '%s\n' $unrev | $GREP -c .)))"
  echo "  review files with no plan of that sha:${unrev:- none}"
  echo "  .captures at pass >= 2: ${capd} under a dotted name of a hyphenated plan; with no plan at all (no route recorded, not counted):${capo:- none}"
  TS=$((${TS:-0} + seats)); TN=$((${TN:-0} + ns))
done
awk -v s="$TS" -v n="$TN" 'BEGIN { if (n > 0) printf "== s321+s322 pooled (after): %d seats / %d re-validations = %.2f seats per re-validation\n", s, n, s / n }'

echo "== s320 (before): route source = shard dir and review file (no gate plan exists)"
S=s320
n=0; fan=0; ser=0; sgl=0; seats=0; merged_nodir=0; dir_nomerge=0
for r in $(printf '%s\n' "$TREE" | $GREP -E "^docs/reviews/${S}/[^/]*-qa-validation-p[0-9]+\.md$"); do
  b="${r##*/}"; pass="${b##*-p}"; pass="${pass%.md}"; [ "$pass" -ge 2 ] || continue
  story="${b%-qa-validation-p*}"
  dir="$(printf '%s\n' "$TREE" | $GREP -E "^docs/reviews/${S}/shards/${story}-qa-validation-[0-9a-f]+-p${pass}/" | sed 's#/[^/]*$##' | sort -u | head -1)"
  body="$(git -C "$GRAPH" show "${SHA}:${r}")"
  mg=0; printf '%s\n' "$body" | $GREP -q 'Merged by merge-review-shards.sh' && mg=1
  title="$(printf '%s\n' "$body" | $GREP -m1 '^# ')"
  if [ -n "$dir" ]; then
    k=FANOUT; st="$(mdcount "$dir")"; fan=$((fan + 1)); seats=$((seats + st))
    [ "$mg" = 1 ] || dir_nomerge=$((dir_nomerge + 1))
  else
    [ "$mg" = 1 ] && merged_nodir=$((merged_nodir + 1))
    case "$title" in
      *serial*) k=SERIAL; st=1; ser=$((ser + 1)); seats=$((seats + 1)) ;;
      *) k=SINGLE; st="1..5"; sgl=$((sgl + 1)) ;;
    esac
  fi
  n=$((n + 1))
  dn=none; [ -n "$dir" ] && dn="${dir##*/}"
  printf '  %s p%s %s seats=%s shard_dir=%s merged_header=%s\n' "$story" "$pass" "$k" "$st" "$dn" "$mg"
done
echo "  s320: ${n} re-validations: FANOUT ${fan}, SERIAL ${ser}, SINGLE (seat count undeclared) ${sgl}"
echo "  merged-header/shard-dir agreement: ${dir_nomerge} shard dirs without a merged review file, ${merged_nodir} merged review files without a shard dir (both must be 0)"
awk -v s="$seats" -v n="$n" -v u="$sgl" 'BEGIN { if (n > 0) printf "  seats per re-validation: %.2f (SINGLE as 1 seat) .. %.2f (SINGLE as 5 seats); %d seats on the %d classified\n", (s + u) / n, (s + 5 * u) / n, s, n - u }'
