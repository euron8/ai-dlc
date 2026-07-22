#!/usr/bin/env node
/*
 * audit-machinery-efficacy.js — ai-dlc maintainer tool
 *
 * Measures EFFICACY (did it ever catch a real defect) vs COST (resident tokens)
 * for every gate check + non-check machinery unit, using a real consumer's
 * multi-sprint fire-history. Implements the v0.10.0 "0 true catches -> hold"
 * methodology as a repeatable report. Distinct from retro Step-4's STRUCTURAL
 * dormancy scans (wiring/anchors) — this measures whether machinery earns its
 * per-gate token cost.
 *
 * Usage:  node scripts/audit-machinery-efficacy.js [--graph /path/to/consumer]
 *
 * Fire-attribution note (see docs/ audit): gate-log per-check VERDICT tokens are
 * PASS-dominated (a naive `grep FAIL` over-counts on check descriptions). The
 * real "caught something" signals are the escalation archive's inline Check-N
 * references and the retro corpus's Check-N / H-catalog citations. Consumer
 * check NUMBERING has drifted from the distribution's for high IDs, so checks
 * are aligned by TITLE (word-Jaccard), not by number.
 */
'use strict';
const fs = require('fs');
const cp = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const DIST = path.resolve(__dirname, '..');
const gi = args.indexOf('--graph');
const GRAPH = gi >= 0 ? args[gi + 1] : '/Users/n8/git/graph';

// --- real tokenizer (tiktoken cl100k proxy; ~15% off Claude's but far better
//     than chars/4 and consistent across runs). Falls back to chars/4. ---
let enc = null, tokBasis = 'chars/4';
try { enc = require('tiktoken').get_encoding('cl100k_base'); tokBasis = 'tiktoken cl100k'; } catch (e) {}
const ntok = s => enc ? enc.encode(s).length : Math.round(s.length / 4);

const STOP = new Set(['the', 'and', 'for', 'gate', 'check', 'per', 'via', 'all', 'any']);
// light stemmer: fold plurals/verb forms so "placeholders"≈"placeholder", "tests"≈"test"
const stem = w => w.replace(/(ies)$/, 'y').replace(/(es|s)$/, '').replace(/(ing|ed)$/, '');
const words = s => new Set((s.toLowerCase().match(/[a-z0-9]+/g) || []).filter(w => w.length > 2 && !STOP.has(w)).map(stem));
function jaccard(a, b) {
  const A = words(a), B = words(b); if (!A.size || !B.size) return 0;
  let inter = 0; for (const w of A) if (B.has(w)) inter++;
  return inter / (A.size + B.size - inter);
}

// ---------- 1. Distribution check catalog: id, title, token cost ----------
const gvPath = path.join(DIST, 'core/skills/ai-dlc/steps/gate-validation.md');
const gv = fs.readFileSync(gvPath, 'utf8');
const glines = gv.split('\n');
// The `Check ` prefix is optional on purpose. Core briefly wrote one heading as
// `### Check 24.` while every other check is `### 24.`, and a prefix-intolerant
// regex does not merely SKIP that check — a check's token span runs to the next
// MATCHED header, so check 23 silently absorbed check 24's whole body and 24 got
// no cost row at all. The tool that decides whether a check earns its cost was
// reporting inflated cost for one check and none for the next.
const hdrRe = /^### (?:Check\s+)?([0-9]+[a-z]?|H[0-9]+|Core-layer[\w\s]*)\.?\s*(.*)$/;
const hdrs = [];
glines.forEach((l, i) => { const m = l.match(hdrRe); if (m) hdrs.push({ id: m[1].trim(), title: (m[2] || '').replace(/[—(].*$/, '').replace(/[.?]/g, '').trim(), line: i }); });
const dist = {};
hdrs.forEach((h, i) => {
  const end = i + 1 < hdrs.length ? hdrs[i + 1].line : glines.length;
  dist[h.id] = { id: h.id, title: h.title, tok: ntok(glines.slice(h.line, end).join('\n')) };
});

// ---------- 1b. Enforcement map: catalog check -> enforcement binding ----------
// Line-oriented parse (no yaml dep), same posture as validate-enforcement-map.sh.
// Surfaces WHICH checks have a machine enforcer vs are LLM/project-adjudicated —
// the binding the v0.27.0 audit found unmapped.
const emPath = path.join(DIST, 'core/skills/ai-dlc/enforcement-map.yaml');
const enfMap = {};
if (fs.existsSync(emPath)) {
  let inChecks = false, cur = null;
  for (const raw of fs.readFileSync(emPath, 'utf8').split('\n')) {
    if (/^checks:/.test(raw)) { inChecks = true; continue; }
    if (/^non_catalog_units:/.test(raw)) { inChecks = false; cur = null; continue; }
    if (!inChecks) continue;
    let m;
    if ((m = raw.match(/^  - id:\s*"?([^"\n]+?)"?\s*$/))) { cur = m[1]; enfMap[cur] = { adj: 'llm', enf: [] }; }
    else if (cur && (m = raw.match(/^    adjudication:\s*(\w+)/))) enfMap[cur].adj = m[1];
    else if (cur && (m = raw.match(/^      - (core\/\S+\.(?:sh|yml))/))) enfMap[cur].enf.push(m[1]);
  }
}
const enfCell = id => {
  // catalog-header ids differ in shape from map ids for the word-titled check
  // ("Core-layer immutability" vs "core-layer-immutability") — normalize.
  const e = enfMap[id] || enfMap[id.toLowerCase().replace(/\s+/g, '-')];
  if (!e) return '—';
  return e.adj === 'script' ? `script:${e.enf.length}` : e.adj;
};

// ---------- 2. Consumer fire evidence ----------
function ls(glob) { try { return cp.execSync(`ls ${glob} 2>/dev/null || true`).toString().trim().split('\n').filter(Boolean); } catch (e) { return []; } }
const glFiles = ls(`${GRAPH}/_bmad-output/implementation-artifacts/gate-log*.md`);
const retroFiles = ls(`${GRAPH}/docs/retro/sprint-*.md`);
const escPath = path.join(GRAPH, 'docs/escalations/pending-archive.md');
const esc = fs.existsSync(escPath) ? fs.readFileSync(escPath, 'utf8') : '';

// consumer catalog by number: dominant title, exposure count, non-pass, last sprint
const pairRe = /^\s*[-*]\s*Check[\s-]?([0-9]+[a-z]?|H[0-9]+)\s*(?:\(([^)]+)\))?\s*:\s*([A-Za-z\/_-]+)?/i;
const cons = {};
for (const f of glFiles) {
  const t = fs.readFileSync(f, 'utf8');
  for (const blk of t.split(/(?=^## Gate:)/m)) {
    const sp = +((blk.match(/S(\d+)/) || [])[1]) || null;
    for (const ln of blk.split('\n')) {
      const m = ln.match(pairRe); if (!m) continue;
      const id = m[1], title = (m[2] || '').trim().toLowerCase(), v = (m[3] || '').toUpperCase();
      const c = cons[id] || (cons[id] = { titles: {}, count: 0, nonpass: 0, last: 0 });
      if (title) c.titles[title] = (c.titles[title] || 0) + 1;
      c.count++; if (sp) c.last = Math.max(c.last, sp);
      if (v && !/PASS/.test(v) && !/^NA$|N\/A/.test(v)) c.nonpass++;
    }
  }
}
const consDom = id => { const t = cons[id] && cons[id].titles; if (!t) return ''; const e = Object.entries(t).sort((a, b) => b[1] - a[1])[0]; return e ? e[0] : ''; };

// per-number reference counts in escalation archive + retro corpus (+ last retro sprint)
function refCounts(text) { const c = {}; for (const m of text.matchAll(/\bCheck[\s-]?([0-9]+[a-z]?|H[0-9]+)\b/gi)) { const id = m[1]; c[id] = (c[id] || 0) + 1; } return c; }
const escRefs = refCounts(esc);
const retroRefs = {}, lastRetro = {};
for (const f of retroFiles) {
  const t = fs.readFileSync(f, 'utf8'); const sp = +((f.match(/sprint-(\d+)/) || [])[1]) || null;
  for (const m of t.matchAll(/\bCheck[\s-]?([0-9]+[a-z]?|H[0-9]+)\b/gi)) { const id = m[1]; retroRefs[id] = (retroRefs[id] || 0) + 1; if (sp) lastRetro[id] = Math.max(lastRetro[id] || 0, sp); }
}

// ---------- 3. Title-aligned crosswalk + per-dist-check evidence ----------
const SPRINT_NOW = Math.max(0, ...retroFiles.map(f => +((f.match(/sprint-(\d+)/) || [])[1]) || 0));
function alignByTitle(distTitle) {
  let best = null, bestScore = 0;
  for (const id of Object.keys(cons)) { const s = jaccard(distTitle, consDom(id)); if (s > bestScore) { bestScore = s; best = id; } }
  return { id: best, score: +bestScore.toFixed(2) };
}
const rows = [];
for (const id of Object.keys(dist)) {
  const d = dist[id];
  const byNum = cons[id];
  const numTitleMatch = byNum ? jaccard(d.title, consDom(id)) : 0;
  const al = alignByTitle(d.title);
  // trust number alignment when the same-number consumer title matches well
  const aligned = numTitleMatch >= 0.34 ? { id, score: +numTitleMatch.toFixed(2) } : al;
  // suppress sub-threshold auto-alignments — a <0.3 word-Jaccard is noise, not a mapping
  const shown = aligned.score >= 0.30 ? aligned : { id: null, score: aligned.score };
  const cc = shown.id ? cons[shown.id] : null;
  // Narrative "Check N" references in the consumer's retros and escalations are in
  // the CONSUMER's namespace, so they must be counted against the TITLE-ALIGNED
  // consumer number — never against this distribution check's own number. Keying
  // them by `id` is the exact mis-attribution the Consumer-catalog crosswalk rule
  // forbids, and it was live: distribution Check 24 (adversarial convergence,
  // shipped in v0.48.0) inherited 15 escalation + 35 retro references belonging to
  // the consumer's Check 24 (financial-display live-verify) and was classified
  // EARNED — a check born this release, credited with a fire history that is
  // someone else's. With no aligned counterpart, a check has NO consumer trace,
  // and that is the honest answer.
  const cid = shown.id;
  const escR = cid ? (escRefs[cid] || 0) : 0;
  const retroR = cid ? (retroRefs[cid] || 0) : 0;
  const lastFire = Math.max(cc ? cc.last : 0, cid ? (lastRetro[cid] || 0) : 0);
  rows.push({
    id, tok: d.tok, title: d.title,
    align: shown.id ? `C${shown.id}` : '—', alignScore: shown.score,
    expo: cc ? cc.count : 0, nonpass: cc ? cc.nonpass : 0,
    escR, retroR,
    lastFire: lastFire || null,
    stale: lastFire ? SPRINT_NOW - lastFire : null,
  });
}

// classification heuristic (advisory — author makes final call)
function classify(r) {
  if (r.expo === 0 && r.escR === 0 && r.retroR === 0) return r.align === '—' ? 'NO-CONSUMER-TRACE' : 'ZERO-FIRE';
  if (r.escR + r.retroR === 0 && r.nonpass === 0) return 'EXPOSED-NEVER-CAUGHT';
  if (r.stale != null && r.stale >= 40) return 'STALE(' + r.stale + 'sp)';
  return 'EARNED';
}

// ---------- output ----------
console.log(`# machinery-efficacy audit — token basis: ${tokBasis}, consumer sprint≈${SPRINT_NOW}\n`);
console.log('## gate checks (distribution catalog)  [sorted by token cost desc]\n');
console.log('| id | enf | tok | align→ | score | expo | nonPASS | escRef | retroRef | lastFire | stale | class |');
console.log('|----|-----|-----|--------|-------|------|---------|--------|----------|----------|-------|-------|');
rows.sort((a, b) => b.tok - a.tok).forEach(r =>
  console.log(`| ${r.id} | ${enfCell(r.id)} | ${r.tok} | ${r.align} | ${r.alignScore} | ${r.expo} | ${r.nonpass} | ${r.escR} | ${r.retroR} | ${r.lastFire || '-'} | ${r.stale ?? '-'} | ${classify(r)} |`));
const _scriptEnf = Object.values(enfMap).filter(e => e.adj === 'script').length;
console.log(`\n_enforcement (enf col): ${_scriptEnf}/${Object.keys(enfMap).length} catalog checks script-adjudicated, rest LLM/project. Source: core/skills/ai-dlc/enforcement-map.yaml (validated by scripts/validate-enforcement-map.sh)._`);

// consumer-local checks the distribution never absorbed (drift, other direction)
const distIds = new Set(Object.keys(dist));
const local = Object.keys(cons).filter(id => !distIds.has(id) && cons[id].count > 0)
  .sort((a, b) => cons[b].count - cons[a].count)
  .map(id => `C${id}(${cons[id].count},s${cons[id].last}: ${consDom(id).slice(0, 28)})`);
console.log('\n## consumer-LOCAL checks not in distribution catalog (absorption gap):');
console.log(local.join('  '));

// ---------- non-check units: token cost + consumer-usage evidence ----------
console.log('\n## non-check units (token/line cost + consumer usage)\n');
const hasWorkflows = fs.existsSync(path.join(GRAPH, '.github/workflows'));
const units = [
  ['scripts/ai-dlc/validate-ci-gates.sh', 'core/scripts/validate-ci-gates.sh'],
  ['scripts/ai-dlc/validate-mandatory-rules.sh', 'core/scripts/validate-mandatory-rules.sh'],
  ['scripts/ai-dlc/validate-provenance-block.sh', 'core/scripts/validate-provenance-block.sh'],
  ['scripts/ai-dlc/validate-retro-evidence.sh', 'core/scripts/validate-retro-evidence.sh'],
  ['ci/validate-ci-gates.yml', 'core/ci-templates/validate-ci-gates.yml'],
  ['ci/validate-retro-compliance.yml', 'core/ci-templates/validate-retro-compliance.yml'],
];
console.log('| unit | lines | tok | consumer signal |');
console.log('|------|-------|-----|-----------------|');
for (const [name, rel] of units) {
  const p = path.join(DIST, rel); if (!fs.existsSync(p)) { console.log(`| ${name} | MISSING | - | - |`); continue; }
  const t = fs.readFileSync(p, 'utf8');
  const base = path.basename(rel);
  let signal = '-';
  try { signal = cp.execSync(`grep -rl "${base}" ${GRAPH}/docs ${GRAPH}/_bmad-output 2>/dev/null | wc -l`).toString().trim() + ' files ref'; } catch (e) {}
  if (name.startsWith('ci/')) signal += hasWorkflows ? ' | .github/workflows PRESENT' : ' | NO .github/workflows in consumer';
  console.log(`| ${name} | ${t.split('\n').length} | ${ntok(t)} | ${signal} |`);
}
console.log(`\nconsumer has .github/workflows: ${hasWorkflows}`);

// ---------- structured metrics (GATE_METRIC v1) — decisive path, preferred when present ----------
// v0.28.0: when the consumer emits gate-metrics.jsonl, efficacy is machine-countable
// and catalog-namespaced (no prose parsing, no cross-catalog confound). Falls back
// to the prose-derived table above for pre-v0.28.0 sprints that lack the file.
const metricFiles = ls(`${GRAPH}/_bmad-output/implementation-artifacts/gate-metrics*.jsonl`);
console.log('\n## structured metrics (GATE_METRIC v1)\n');
if (!metricFiles.length) {
  console.log('_No `gate-metrics.jsonl` in consumer yet — using prose-derived signals above (pre-v0.28.0). '
    + 'Once the Check-12 emission clause ships, this section supersedes the prose estimates._');
} else {
  const agg = {}; // key `${catalog}\t${check}` -> {expo, fails, defects:{}, last, tok}
  let bad = 0, noTok = 0;
  for (const f of metricFiles) for (const ln of fs.readFileSync(f, 'utf8').split('\n')) {
    if (!ln.trim()) continue;
    let r; try { r = JSON.parse(ln); } catch (e) { bad++; continue; }
    const k = `${r.catalog || '?'}\t${r.check}`;
    const a = agg[k] || (agg[k] = { expo: 0, fails: 0, defects: {}, last: 0, tok: null });
    a.expo++; if (r.sprint) a.last = Math.max(a.last, r.sprint);
    if (typeof r.tok_slice === 'number') a.tok = r.tok_slice; else noTok++;  // required as of v0.28.1
    if (r.verdict === 'FAIL') { a.fails++; if (r.defect_class) a.defects[r.defect_class] = (a.defects[r.defect_class] || 0) + 1; }
  }
  const total = Object.values(agg).reduce((s, a) => s + a.expo, 0);
  console.log(`records: ${total} across ${metricFiles.length} file(s)${bad ? `, ${bad} unparseable` : ''}`
    + `${noTok ? ` — ⚠ ${noTok} record(s) missing required tok_slice (v0.28.1)` : ''}\n`);
  // cost-vs-catch: tok_slice spent per real catch (∞ = cost with zero catches → dormancy signal)
  console.log('| catalog | check | exposures | real FAILs | defect classes | tok/gate | tok÷catch | lastFire |');
  console.log('|---------|-------|-----------|-----------|----------------|----------|-----------|----------|');
  for (const [k, a] of Object.entries(agg).sort((x, y) => y[1].fails - x[1].fails || y[1].expo - x[1].expo)) {
    const [cat, chk] = k.split('\t');
    const cls = Object.entries(a.defects).map(([d, n]) => `${d}:${n}`).join(', ') || '—';
    const perCatch = a.tok == null ? '?' : (a.fails ? Math.round(a.tok * a.expo / a.fails) : '∞');
    console.log(`| ${cat} | ${chk} | ${a.expo} | ${a.fails} | ${cls} | ${a.tok ?? '?'} | ${perCatch} | ${a.last || '-'} |`);
  }
}
