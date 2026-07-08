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
const hdrRe = /^### ([0-9]+[a-z]?|H[0-9]+|Core-layer[\w\s]*)\.?\s*(.*)$/;
const hdrs = [];
glines.forEach((l, i) => { const m = l.match(hdrRe); if (m) hdrs.push({ id: m[1].trim(), title: (m[2] || '').replace(/[—(].*$/, '').replace(/[.?]/g, '').trim(), line: i }); });
const dist = {};
hdrs.forEach((h, i) => {
  const end = i + 1 < hdrs.length ? hdrs[i + 1].line : glines.length;
  dist[h.id] = { id: h.id, title: h.title, tok: ntok(glines.slice(h.line, end).join('\n')) };
});

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
  const catch_ = (escRefs[id] || 0) + (retroRefs[id] || 0);   // per-number narrative catches
  const lastFire = Math.max(cc ? cc.last : 0, lastRetro[id] || 0);
  rows.push({
    id, tok: d.tok, title: d.title,
    align: shown.id ? `C${shown.id}` : '—', alignScore: shown.score,
    expo: cc ? cc.count : 0, nonpass: cc ? cc.nonpass : 0,
    escR: escRefs[id] || 0, retroR: retroRefs[id] || 0,
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
console.log('| id | tok | align→ | score | expo | nonPASS | escRef | retroRef | lastFire | stale | class |');
console.log('|----|-----|--------|-------|------|---------|--------|----------|----------|-------|-------|');
rows.sort((a, b) => b.tok - a.tok).forEach(r =>
  console.log(`| ${r.id} | ${r.tok} | ${r.align} | ${r.alignScore} | ${r.expo} | ${r.nonpass} | ${r.escR} | ${r.retroR} | ${r.lastFire || '-'} | ${r.stale ?? '-'} | ${classify(r)} |`));

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
  ['scripts/validate-ci-gates.sh', 'core/scripts/validate-ci-gates.sh'],
  ['scripts/validate-mandatory-rules.sh', 'core/scripts/validate-mandatory-rules.sh'],
  ['scripts/validate-provenance-block.sh', 'core/scripts/validate-provenance-block.sh'],
  ['scripts/validate-retro-evidence.sh', 'core/scripts/validate-retro-evidence.sh'],
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
