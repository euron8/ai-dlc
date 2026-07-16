#!/usr/bin/env node
/*
 * ab-lead-model.js — ai-dlc maintainer tool
 *
 * Answers the A/B that v0.62.0 deferred: is a Sonnet lead SAFE (does the Opus
 * gate-adjudicator escalation hold the gate?) and is it CHEAPER (what does the
 * arm actually cost)? Distinct from audit-machinery-efficacy.js, which measures
 * whether a CHECK earns its token cost and has no arm dimension at all.
 *
 * Usage:  node scripts/ab-lead-model.js [--graph /path/to/consumer] [--json]
 *
 * WHY THE LEAD SESSION IS THE WHOLE MEASUREMENT
 * ---------------------------------------------
 * Agent-spawned teammates are NOT persisted to disk — only top-level sessions
 * get a ~/.claude/projects transcript. That sounds like it blocks a cost A/B; it
 * does not. The arm changes exactly ONE model: the lead's. Every teammate is
 * pinned identically in both arms (adversary opus, analyst sonnet, ...), so
 * teammate cost is a constant that cancels in the delta. What a Sonnet lead can
 * still do is dispatch MORE (extra remediation loops) — that is second-order and
 * IS measurable, as a dispatch count, from the lead's own transcript.
 *
 * So: cost = lead session, measured, plus the same token volumes re-priced at
 * Opus rates. The two disagree only if a Sonnet lead burns different volume —
 * which is the question. Do not read the counterfactual as a prediction; it
 * assumes equal volume by construction.
 *
 * ARM PROVENANCE
 * --------------
 * No repo artifact records which model the lead ran on. The ONLY on-disk arm
 * record is the `model` field on each assistant turn in the transcript. That is
 * why this tool reads ~/.claude/projects and not the consumer tree alone, and it
 * is finding #3 of the report this tool feeds.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const args = process.argv.slice(2);
const gi = args.indexOf('--graph');
const GRAPH = gi >= 0 ? args[gi + 1] : '/Users/n8/git/graph';
const AS_JSON = args.includes('--json');

// Transcript dir is derived from the consumer path the same way Claude Code
// encodes it: absolute path with separators flattened to '-'.
const PROJ = path.join(os.homedir(), '.claude', 'projects', GRAPH.replace(/\//g, '-'));

// --- pricing, USD per Mtok (input, output). Cache read 0.1x input, write 1.25x.
// Cache read DOMINATES: a lead session runs ~200x more cache-read than output
// tokens. An output-only cost model is off by an order of magnitude.
const PRICE = {
  'claude-opus-4-8': [5, 25],
  'claude-opus-4-6': [5, 25],
  'claude-sonnet-5': [3, 15],
  'claude-sonnet-4-6': [3, 15],
};
const TIER = m => (/opus/.test(m || '') ? 'opus' : /sonnet/.test(m || '') ? 'sonnet' : 'other');

function cost(model, u) {
  const p = PRICE[model];
  if (!p) return null; // unknown model: refuse to invent a number
  const [pin, pout] = p;
  return (u.in / 1e6) * pin + (u.out / 1e6) * pout
       + (u.cacheRead / 1e6) * pin * 0.1 + (u.cacheWrite / 1e6) * pin * 1.25;
}
const zero = () => ({ in: 0, out: 0, cacheRead: 0, cacheWrite: 0, turns: 0 });

// ---------- role model pins, from the consumer's rendered role files ----------
// These are the DECLARED intent. The dispatch `model` param is the MECHANISM.
// Nothing binds them; comparing the two is the point.
function rolePins() {
  const dir = path.join(GRAPH, '.claude', 'team-roles');
  const pins = {};
  if (!fs.existsSync(dir)) return pins;
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.md'))) {
    const m = fs.readFileSync(path.join(dir, f), 'utf8')
      .match(/claude-(?:opus|sonnet)[a-z0-9.-]*\[1m\]/);
    pins[f.replace(/\.md$/, '')] = m ? m[0] : null;
  }
  return pins;
}

// ---------- scan transcripts ----------
// A LEAD session is one that dispatches ai-dlc teammates. Identify it by its own
// Agent tool_use calls, never by grepping role filenames: every session's
// context lists every role, so that grep matches everything.
const ROLE_RE = /^(gate-adjudicator|adversary|architect|remediator|analyst|dev|qa|code-reviewer|pm|sm|tea|ux|cis|party|protected-path-editor)/;

function scanSession(file) {
  const s = {
    id: path.basename(file).slice(0, 8), file,
    model: null, usage: zero(), dispatches: [], sprints: new Map(), isOperator: false,
    mtime: fs.statSync(file).mtimeMs,
  };
  let text;
  try { text = fs.readFileSync(file, 'utf8'); } catch { return null; }
  for (const line of text.split('\n')) {
    if (!line) continue;
    let d;
    try { d = JSON.parse(line); } catch { continue; }

    if (d.type === 'user') {
      // The Agent tool_result carries the teammate's model CONFIG. It is the
      // only record of what a spawn actually got — the teammate itself leaves no
      // transcript. Join it back onto the dispatch by tool_use_id.
      const tr = d.toolUseResult;
      if (tr && typeof tr === 'object' && tr.agent_id && Array.isArray(d.message && d.message.content)) {
        for (const b of d.message.content) {
          if (!b || b.type !== 'tool_result') continue;
          const disp = s.dispatches.find(x => x.id === b.tool_use_id);
          if (disp) disp.resolved = tr.model || null;
        }
      }
      const c = d.message && d.message.content;
      const str = typeof c === 'string' ? c
        : Array.isArray(c) ? c.map(x => (x && x.text) || '').join(' ') : '';
      // NOT a lead-vs-operator discriminator: the live S291 lead issues /clear
      // and /model at launch, exactly like an operator window. Dispatching an
      // ai-dlc role is the only reliable signal, and the lead filter already
      // uses it. Kept only as reportable context.
      if (/<command-name>\/(clear|model|compact|resume)\b/.test(str)) s.isOperator = true;
      for (const m of str.matchAll(/\bs(?:print[ -])?(\d{3})\b/gi)) {
        const n = +m[1]; s.sprints.set(n, (s.sprints.get(n) || 0) + 1);
      }
    }

    if (d.type !== 'assistant') continue;
    const msg = d.message || {};
    if (msg.model) s.model = s.model || msg.model;
    const u = msg.usage || {};
    s.usage.turns++;
    s.usage.in += u.input_tokens || 0;
    s.usage.out += u.output_tokens || 0;
    s.usage.cacheRead += u.cache_read_input_tokens || 0;
    s.usage.cacheWrite += u.cache_creation_input_tokens || 0;

    for (const b of msg.content || []) {
      if (!b || b.type !== 'tool_use') continue;
      if (b.name === 'Agent') {
        const inp = b.input || {};
        const name = inp.name || inp.description || '';
        const prompt = inp.prompt || '';
        // Role comes from the Rule 19 binding in the prompt, NOT the dispatch
        // name: the name is a convention the lead picks, the binding is the
        // contract. (`qa-s291-story4` binds tea.md — the name would lie.)
        const bound = (prompt.match(/team-roles\/([a-z][a-z-]*)\.md/) || [])[1];
        // `model` absent => NOT "inherits the lead's model". See resolvedModel
        // below: the record reports claude-opus-4-8 for every no-param spawn.
        s.dispatches.push({
          name,
          id: b.id,
          role: bound || (name.match(ROLE_RE) || [])[1] || 'unknown',
          requested: inp.model || null,
          resolved: null,          // filled from the tool_result below
          ts: d.timestamp || null,
        });
        const sm = name.match(/-s(\d{3})-/);
        if (sm) { const n = +sm[1]; s.sprints.set(n, (s.sprints.get(n) || 0) + 10); }
      }
    }
  }
  return s;
}

function dominantSprint(s) {
  let best = null, bestN = 0;
  for (const [k, v] of s.sprints) if (v > bestN) { best = k; bestN = v; }
  return best;
}

// ---------- gather ----------
if (!fs.existsSync(PROJ)) {
  console.error(`No transcript dir for ${GRAPH}\n  expected: ${PROJ}`);
  process.exit(2);
}
const files = fs.readdirSync(PROJ).filter(f => f.endsWith('.jsonl')).map(f => path.join(PROJ, f));
const sessions = files.map(scanSession).filter(s => s && s.usage.turns > 0);

// A lead is a session that dispatches ai-dlc roles. Do NOT also filter on slash
// commands: the live S291 lead runs /clear + /model at launch just like an
// operator window, and filtering on those deletes the very arm under test.
// Operator windows dispatch nothing, so this test already excludes them.
const leads = sessions
  .filter(s => s.dispatches.some(d => d.role !== 'unknown'))
  .sort((a, b) => a.mtime - b.mtime);

// ---------- verdict corpus (the Sonnet-arm evidence) ----------
function verdicts() {
  const dir = path.join(GRAPH, '_bmad-output', 'gate-adjudication');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.verdict.json')).map(f => {
    const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    return {
      nonce: j.gate_nonce, gate: j.gate_type,
      pass: (j.verdicts || []).filter(v => v.verdict === 'PASS').length,
      fail: (j.verdicts || []).filter(v => v.verdict === 'FAIL').length,
      fails: (j.verdicts || []).filter(v => v.verdict === 'FAIL').map(v => v.check_id),
      n: (j.verdicts || []).length,
    };
  }).sort((a, b) => String(a.nonce).localeCompare(String(b.nonce)));
}

// ---------- in-repo arm record (v0.70.0 D4) ----------
// Written from the transcript by ai-dlc-context-sensor.sh, never self-reported.
// Before this existed, "which arm ran" was answerable ONLY from ~/.claude/projects
// — outside the repo and outside every check — so a sprint's own artifacts could
// not falsify an arm claim. When present this is the authority; the transcript
// scan below stays as the cost source (the arm log carries identity, not usage).
function armLog() {
  const p = path.join(GRAPH, '_bmad-output', 'arm-log.jsonl');
  if (!fs.existsSync(p)) return null;
  const rows = fs.readFileSync(p, 'utf8').split('\n').filter(Boolean).map(l => {
    try { return JSON.parse(l); } catch { return null; }
  }).filter(Boolean);
  return rows.length ? rows : null;
}

// ---------- report ----------
const pins = rolePins();
const arm = armLog();
const out = { arms: [], dispatchDrift: [], verdicts: verdicts(), counterfactual: null, armLog: arm };

const usd = n => (n === null ? '   n/a' : '$' + n.toFixed(2).padStart(7));
const line = n => '─'.repeat(n);

if (!AS_JSON) {
  console.log('\nARM RECORD — _bmad-output/arm-log.jsonl (hook-written, transcript-sourced)');
  console.log(line(104));
  if (!arm) {
    console.log('  ABSENT — this consumer predates the v0.70.0 arm record, so the arm is not');
    console.log('  falsifiable from its own artifacts. Falling back to the transcript scan below,');
    console.log('  which reads outside the repo. (absent, NOT "single-arm")');
  } else {
    for (const r of arm) console.log(`  s${r.sprint ?? '?'}  ${r.ts}  lead_model=${r.lead_model}`);
  }
  console.log(line(104));
}

const rows = leads.map(s => {
  const sp = dominantSprint(s);
  const c = cost(s.model, s.usage);
  return { s, sprint: sp, tier: TIER(s.model), cost: c };
});

if (!AS_JSON) {
  console.log('\nARM ATTRIBUTION — lead sessions (teammates are not persisted; see header)');
  console.log(line(104));
  console.log('sprint  session   lead model         tier    turns    output    cache-read  dispatches      USD');
  console.log(line(104));
  for (const r of rows) {
    console.log(
      String(r.sprint ?? '?').padEnd(8) + r.s.id.padEnd(10) +
      String(r.s.model).padEnd(19) + r.tier.padEnd(8) +
      String(r.s.usage.turns).padStart(5) + String(r.s.usage.out).padStart(10) +
      String(r.s.usage.cacheRead).padStart(14) + String(r.s.dispatches.length).padStart(8) +
      usd(r.cost).padStart(12)
    );
  }
  console.log(line(104));
}
out.arms = rows.map(r => ({
  sprint: r.sprint, session: r.s.id, model: r.s.model, tier: r.tier,
  turns: r.s.usage.turns, output: r.s.usage.out, cacheRead: r.s.usage.cacheRead,
  dispatches: r.s.dispatches.length, usd: r.cost,
}));

// --- arms present? An absent arm must SAY so. An empty table reads as parity.
const sonnetArm = rows.filter(r => r.tier === 'sonnet');
const opusArm = rows.filter(r => r.tier === 'opus');
if (!AS_JSON) {
  console.log();
  if (!sonnetArm.length) console.log('NO SONNET ARM PRESENT — nothing to compare. (not parity: absence)');
  if (!opusArm.length) console.log('NO OPUS-LEAD ARM PRESENT in this transcript corpus — the measured baseline');
  if (!opusArm.length) console.log('  is unavailable; only the counterfactual re-price below is defined.');
}

// --- counterfactual re-price: same volumes, Opus rates.
//
// READ THIS BEFORE QUOTING THE NUMBER. Sonnet 5 ($3/$15) and Opus 4.8 ($5/$25)
// sit at a uniform 3/5 = 0.6 ratio on EVERY component — input, output, and both
// cache multipliers, which are defined as fractions of input. So re-pricing any
// token volume whatsoever returns exactly 40.0% cheaper. The counterfactual is
// arithmetically incapable of returning anything else: it cannot be wrong, and
// it therefore carries no information. It is a rate identity, not a finding.
//
// The only informative question is VOLUME: a Sonnet lead is cheaper only if it
// does not need >1/0.6 = 1.67x the tokens to do the same work. Nothing but the
// measured arms can answer that, which is what the normalized table below is
// for. Reporting the 40% alone would dress a tautology as a result.
if (sonnetArm.length) {
  const bySprint = new Map();
  for (const r of sonnetArm) {
    if (!bySprint.has(r.sprint)) bySprint.set(r.sprint, zero());
    const a = bySprint.get(r.sprint);
    for (const k of Object.keys(a)) a[k] += r.s.usage[k];
  }
  out.counterfactual = [];
  if (!AS_JSON) {
    console.log('\nCOST — Sonnet arm re-priced at Opus rates  [RATE IDENTITY: always exactly 40%]');
    console.log(line(104));
  }
  for (const [sp, agg] of [...bySprint].sort((a, b) => (a[0] || 0) - (b[0] || 0))) {
    const actual = cost('claude-sonnet-5', agg);
    const asOpus = cost('claude-opus-4-8', agg);
    out.counterfactual.push({ sprint: sp, actual, asOpus, pct: (1 - actual / asOpus) * 100 });
    if (!AS_JSON) {
      console.log(`  s${sp}  measured ${usd(actual)}   at opus rates ${usd(asOpus)}   ` +
        `delta ${usd(asOpus - actual)}  (${((1 - actual / asOpus) * 100).toFixed(1)}%)`);
    }
  }
  if (!AS_JSON) {
    console.log(line(104));
    console.log('  The 40% is a price-ratio identity (0.6 on every component), NOT evidence.');
    console.log('  It holds for any volume, including a volume that makes Sonnet cost MORE.');
    console.log(line(104));
  }
}

// --- the load-bearing comparison: VOLUME per unit of orchestration work.
// A dispatch is the unit — one teammate spawned is one unit of orchestration,
// countable from the lead's transcript even though the teammate is not persisted.
// If the Sonnet lead needed materially more turns/dispatch, the rate saving is
// eaten and the arm loses. This is the only table that can come out either way.
{
  const byTier = new Map();
  for (const r of rows) {
    if (r.cost === null || !r.s.dispatches.length) continue;
    if (!byTier.has(r.tier)) byTier.set(r.tier, { usd: 0, turns: 0, disp: 0, out: 0, sessions: 0 });
    const a = byTier.get(r.tier);
    a.usd += r.cost; a.turns += r.s.usage.turns; a.disp += r.s.dispatches.length;
    a.out += r.s.usage.out; a.sessions++;
  }
  out.normalized = [];
  if (!AS_JSON) {
    console.log('\nVOLUME PER DISPATCH — the comparison that can actually fail');
    console.log(line(104));
    console.log('tier      sessions  dispatches   turns    turns/disp    USD/disp     output/disp');
    console.log(line(104));
  }
  for (const [tier, a] of byTier) {
    const rec = {
      tier, sessions: a.sessions, dispatches: a.disp, turns: a.turns,
      turnsPerDispatch: a.turns / a.disp, usdPerDispatch: a.usd / a.disp,
      outputPerDispatch: a.out / a.disp,
    };
    out.normalized.push(rec);
    if (!AS_JSON) {
      console.log(tier.padEnd(10) + String(a.sessions).padStart(8) + String(a.disp).padStart(12) +
        String(a.turns).padStart(8) + (a.turns / a.disp).toFixed(1).padStart(14) +
        ('$' + (a.usd / a.disp).toFixed(2)).padStart(12) +
        Math.round(a.out / a.disp).toLocaleString().padStart(16));
    }
  }
  if (!AS_JSON) {
    console.log(line(104));
    console.log('  CONFOUND, do not skip: sprint PHASE MIX differs. An implementation dispatch is');
    console.log('  heavier than a planning dispatch, and the arms are not phase-matched. Treat this');
    console.log('  as a measurement with n=1 sprint on the sonnet side, not a controlled result.');
    console.log(line(104));
  }
}

// --- dispatch model drift: requested vs the role file's declared pin.
// ONLY the current sprint. The pins are read from the consumer's role files as
// they are TODAY; a sprint-257 dispatch predates them by months, so comparing it
// against today's pin manufactures drift that never happened.
const curSprint = rows.reduce((m, r) => Math.max(m, r.sprint || 0), 0);
if (!AS_JSON) {
  console.log(`\nDISPATCH MODEL BINDING — requested param vs role-file pin (sprint ${curSprint} only;`);
  console.log('  pins are read as-of-now, so earlier sprints cannot be compared against them)');
  console.log(line(104));
}
for (const r of rows.filter(r => r.sprint === curSprint)) {
  for (const d of r.s.dispatches) {
    const pin = pins[d.role];
    const pinTier = TIER(pin);
    // The EFFECTIVE model is what the tool_result reports, never an assumption.
    //
    // I first assumed a missing `model` param meant "inherits the lead's model"
    // and reported it as such. The record says otherwise: all four no-param
    // S291 spawns report `claude-opus-4-8`, not the lead's sonnet. That inverted
    // the direction of the defect (a no-param spawn is UPGRADED to opus, not
    // downgraded) and made me over-count drift 5 vs the real 3.
    //
    // Residual ambiguity, deliberately preserved: for a spawn that PASSES a
    // param the field echoes the alias verbatim ("opus"), while a no-param spawn
    // shows a full string ("claude-opus-4-8") — so the field reports the model
    // CONFIG, and the Agent tool's contract ("uses the agent definition's model,
    // or inherits from the parent") disagrees with it. No subagent transcript
    // exists to break the tie. So a no-param spawn is UNDETERMINED, which is
    // itself the argument for the guard: you cannot know what you got.
    const effective = d.resolved || (d.requested ? d.requested : null);
    const effTier = TIER(effective);
    const drift = pin && pinTier !== 'other' && effTier !== 'other' && effTier !== pinTier;
    if (drift || !d.requested) {
      const rec = {
        sprint: r.sprint, name: d.name, role: d.role, pin,
        requested: d.requested, resolved: d.resolved, effective, drift: !!drift,
      };
      out.dispatchDrift.push(rec);
      if (!AS_JSON) {
        const tag = drift ? 'DRIFT  ' : 'NOPARAM';
        console.log(`  ${tag} ${String(d.name).padEnd(32)} pin=${String(pin).padEnd(20)} requested=${String(d.requested ?? '<none>').padEnd(8)} resolved=${String(d.resolved ?? '?')}`);
      }
    }
  }
}
if (!AS_JSON && !out.dispatchDrift.length) console.log('  none — every dispatch names a model matching its role pin');
if (!AS_JSON) console.log(line(104));

// --- adjudicator catches: did the escalated Opus judge catch anything?
if (!AS_JSON) {
  console.log('\nESCALATION CATCHES — gate-adjudicator verdicts (the Sonnet arm\'s safety evidence)');
  console.log(line(104));
  if (!out.verdicts.length) {
    console.log('  NO VERDICT CORPUS — the escalation left no record for this consumer.');
    console.log('  (not "clean": absent. A sprint predating v0.62.0 cannot have one.)');
  } else {
    for (const v of out.verdicts) {
      console.log(`  ${String(v.nonce).padEnd(36)} ${String(v.gate).padEnd(14)} ${v.n} checks  ${v.pass} PASS  ${v.fail} FAIL` +
        (v.fail ? `  <- caught: check ${v.fails.join(', ')}` : ''));
    }
    const tf = out.verdicts.reduce((a, v) => a + v.fail, 0);
    console.log(line(104));
    console.log(`  ${tf} FAIL${tf === 1 ? '' : 's'} caught by the escalated Opus adjudicator across ${out.verdicts.length} gates.`);
  }
  console.log(line(104));
  console.log();
}

if (AS_JSON) console.log(JSON.stringify(out, null, 2));

// ---------- --self-test: the 3-step proof ----------
// A tool that reports on a live tree must prove it fails on the real bug, not
// merely that it runs. Facts 1-2 are ground truth established by hand from
// graph's S291 transcripts; fact 3 is the vacuity guard.
if (args.includes('--self-test')) {
  let pass = 0, fail = 0;
  const t = (name, cond, detail) => {
    if (cond) { pass++; console.log(`  PASS  ${name}`); }
    else { fail++; console.log(`  FAIL  ${name}\n        ${detail}`); }
  };
  console.log('\nSELF-TEST — 3-step proof');
  console.log(line(104));

  // 1. Arm attribution is correct, and survives a lead that runs /clear + /model.
  const s291 = rows.find(r => r.sprint === 291);
  t('1a. S291 lead attributed, and to claude-sonnet-5',
    !!s291 && s291.s.model === 'claude-sonnet-5',
    `got ${s291 ? s291.s.model : 'NO S291 LEAD ROW — the isOperator filter regression is back'}`);
  const adj = s291 ? s291.s.dispatches.filter(d => d.role === 'gate-adjudicator') : [];
  t('1b. every S291 gate-adjudicator dispatch requested opus',
    adj.length >= 6 && adj.every(d => d.requested === 'opus'),
    `${adj.length} dispatches; requested=${JSON.stringify(adj.map(d => d.requested))}`);

  // 2. It FAILS ON THE REAL BUG — and this assertion is the corrected one.
  //
  //    The original asserted the no-param remediator was "inherited sonnet, NOT
  //    its opus pin". That was MY assumption, not the record, and it was false:
  //    the tool_result reports claude-opus-4-8, which MATCHES remediator.md's
  //    pin. The self-test enshrined the wrong ground truth and passed — the
  //    exact defect class this tool exists to find. Assert the RECORD now.
  const remNo = out.dispatchDrift.find(d => d.name === 'remediator-s291-stories-p1');
  t('2a. no-param remediator reported from the RECORD (opus), not an assumed inherit',
    !!remNo && remNo.requested === null && /opus/.test(String(remNo.resolved)) && remNo.drift === false,
    remNo ? JSON.stringify(remNo) : 'remediator-s291-stories-p1 not surfaced at all');

  //    The drift that IS real: an EXPLICIT sonnet request against an opus pin.
  //    Two of these happened, and they are the strongest defect the A/B found.
  const remExplicit = out.dispatchDrift.filter(d =>
    d.role === 'remediator' && d.requested === 'sonnet' && d.drift === true);
  t('2b. explicit sonnet-against-opus-pin remediators are flagged (the real drift)',
    remExplicit.length === 2,
    `expected 2, got ${remExplicit.length}: ${JSON.stringify(remExplicit.map(d => d.name))}`);

  //    And the count must not re-inflate: exactly 3 real drifts in S291.
  const realDrift = out.dispatchDrift.filter(d => d.drift);
  t('2c. real drift count is 3 (over-counting means the inherit assumption is back)',
    realDrift.length === 3,
    `expected 3, got ${realDrift.length}: ${JSON.stringify(realDrift.map(d => d.name))}`);

  // 3. Vacuity: absence must announce itself. An empty table reads as parity.
  const emptyDir = path.join(os.tmpdir(), 'ab-lead-model-vacuity-probe');
  fs.rmSync(emptyDir, { recursive: true, force: true });
  fs.mkdirSync(path.join(emptyDir, '_bmad-output', 'gate-adjudication'), { recursive: true });
  const probe = (function (g) {
    const dir = path.join(g, '_bmad-output', 'gate-adjudication');
    return fs.readdirSync(dir).filter(f => f.endsWith('.verdict.json'));
  })(emptyDir);
  t('3. a consumer with no verdict corpus yields zero rows (renderer says ABSENT, not clean)',
    probe.length === 0, `got ${probe.length} rows`);
  fs.rmSync(emptyDir, { recursive: true, force: true });

  console.log(line(104));
  console.log(`  ${pass} passed, ${fail} failed`);
  console.log(line(104) + '\n');
  process.exit(fail ? 1 : 0);
}
