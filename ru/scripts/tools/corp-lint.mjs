#!/usr/bin/env node
// corp-sdd-version: 1.0.0
// corp-lint.mjs — deterministic disposer for agent-written docs. Zero dependencies.
// Scope: openspec/, docs/, .qwen/ only (never lints build output or source code docs).
// Checks: hard file caps, index<->spec bijection + index schema, relative links + anchors,
// embedded snippets vs source, tasks.md state header, delta-spec sections.
// Every ERROR carries a remediation hint. Exit 1 on any ERROR; WARNs never block.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative, sep } from 'node:path';

const ROOT = resolve(process.argv[2] ?? '.');
const SCOPES = ['openspec', 'docs', '.qwen'].map(d => join(ROOT, d)).filter(existsSync);

// ---- hardcoded caps (lines). The write-boundary contract: exceed => rejected, never trimmed.
const CAPS = [
  [/(^|\/)openspec\/index\.md$/, 300],
  [/(^|\/)openspec\/specs\/.+\/spec\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/tasks\.md$/, 200],
  [/(^|\/)openspec\/changes\/.+\/research\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/proposal\.md$/, 200],
  [/(^|\/)\.qwen\/skills\/.+\.md$/, 250],
];

const errors = [], warns = [];
const err = (f, m, hint) => errors.push(`  ✗ ${f}: ${m}\n     ↳ ${hint}`);
const warn = (f, m, hint) => warns.push(`  • ${f}: ${m}\n     ↳ ${hint}`);

function* walk(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'node_modules') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else yield p;
  }
}
const rel = p => relative(ROOT, p).split(sep).join('/');
const mdFiles = SCOPES.flatMap(s => [...walk(s)]).filter(p => p.endsWith('.md'));

// GitHub-style anchor slug (basic: covers latin headings; extend for cyrillic if needed)
const slug = h => h.toLowerCase().trim().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-');
const headingSlugs = txt => new Set(
  [...txt.matchAll(/^#{1,6}\s+(.+?)\s*$/gm)].map(m => slug(m[1]))
);
// strip fenced code (``` and ~~~), inline code, and HTML comments before link checks
const stripCode = txt => txt
  .replace(/```[\s\S]*?```/g, '').replace(/~~~[\s\S]*?~~~/g, '')
  .replace(/`[^`\n]*`/g, '').replace(/<!--[\s\S]*?-->/g, '');
// per-line fence tracking for the embed scanner
const fenceMask = lines => {
  const mask = []; let open = null;
  for (const l of lines) {
    const f = l.match(/^(```|~~~)/)?.[1];
    if (f && !open) { open = f; mask.push(true); continue; }
    if (f && open === f) { open = null; mask.push(true); continue; }
    mask.push(!!open);
  }
  return mask;
};

// ---- 1. caps
for (const p of mdFiles) {
  const r = rel(p);
  for (const [re, cap] of CAPS) {
    if (re.test(r)) {
      const lines = readFileSync(p, 'utf8').split('\n').length;
      if (lines > cap) err(r, `${lines} lines (hard cap ${cap})`,
        `split content into references/ subfiles or tighten; caps are rejected-not-trimmed by design`);
    }
  }
}

// ---- 2. index.json schema + bijection with openspec/specs/ (a capability = a dir WITH spec.md)
const idxPath = join(ROOT, 'openspec', 'index.json');
const specsDir = join(ROOT, 'openspec', 'specs');
let capDirs = [];
if (existsSync(specsDir)) {
  for (const d of readdirSync(specsDir, { withFileTypes: true }).filter(d => d.isDirectory())) {
    if (existsSync(join(specsDir, d.name, 'spec.md'))) capDirs.push(d.name);
    else err(`openspec/specs/${d.name}/`, 'capability dir has no spec.md',
      'add spec.md (a capability IS its spec) or delete the dir');
  }
}
if (existsSync(idxPath)) {
  let idx;
  try { idx = JSON.parse(readFileSync(idxPath, 'utf8')); }
  catch (e) { err('openspec/index.json', `invalid JSON: ${e.message}`, 'regenerate: node tools/gen-index.mjs'); }
  if (idx) {
    const allowed = new Set(['schema_version', 'repo', 'source_digest', 'capabilities', 'modules']);
    for (const k of Object.keys(idx)) if (!allowed.has(k))
      err('openspec/index.json', `unknown key "${k}"`, 'schema forbids extra keys (pollution gate); regenerate');
    for (const k of ['schema_version', 'repo', 'source_digest', 'capabilities']) if (!(k in idx))
      err('openspec/index.json', `missing required key "${k}"`, 'regenerate: node tools/gen-index.mjs');
    if (typeof idx.repo === 'string' && idx.repo.length > 80)
      err('openspec/index.json', 'repo name >80 chars', 'shorten openspec/repo.txt');
    const ids = new Set();
    for (const c of idx.capabilities ?? []) {
      for (const k of ['id', 'title', 'path', 'summary']) if (!(k in c))
        err('openspec/index.json', `capability missing "${k}"`, 'regenerate');
      if (c.id && !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(c.id))
        err('openspec/index.json', `capability id "${c.id}" not kebab-case`, 'rename the spec dir to kebab-case');
      if (c.summary && c.summary.length > 200)
        err('openspec/index.json', `summary for "${c.id}" >200 chars`, 'first paragraph of the spec is the summary; shorten it');
      ids.add(c.id);
    }
    for (const d of capDirs) if (!ids.has(d))
      err('openspec/index.json', `spec dir "${d}" missing from index`, 'regenerate: node tools/gen-index.mjs && git add openspec/index.*');
    for (const id of ids) if (!capDirs.includes(id))
      err('openspec/index.json', `index lists "${id}" but openspec/specs/${id}/spec.md does not exist`, 'regenerate the index');
  }
} else if (capDirs.length) {
  err('openspec/index.json', 'missing but specs exist', 'generate: node tools/gen-index.mjs');
}

// ---- 3. relative links + anchors (skip external, skip code/comments)
for (const p of mdFiles) {
  const r = rel(p);
  const txt = stripCode(readFileSync(p, 'utf8'));
  for (const m of txt.matchAll(/\[[^\]]*\]\(([^)\s]+)\)/g)) {
    const target = m[1];
    if (/^(https?:|mailto:|#)/.test(target)) continue;
    const [fp, anchor] = target.split('#');
    const abs = resolve(dirname(p), fp);
    if (!existsSync(abs)) {
      err(r, `broken link → ${target}`, 'fix the path or create the target');
      continue;
    }
    if (anchor && abs.endsWith('.md')) {
      const slugs = headingSlugs(readFileSync(abs, 'utf8'));
      if (!slugs.has(anchor)) err(r, `broken anchor → ${target}`, `no heading "#${anchor}" in ${rel(abs)}`);
    }
  }
}

// ---- 4. embedded snippets: <!-- embed: path#L3-L5 --> followed by a fence whose body must equal those lines
for (const p of mdFiles) {
  const r = rel(p);
  const lines = readFileSync(p, 'utf8').split('\n');
  const inFence = fenceMask(lines);
  for (let i = 0; i < lines.length; i++) {
    if (inFence[i]) continue; // fenced examples are not directives
    const line = lines[i].trimEnd(); // trailing whitespace must not disable the check
    const m = line.match(/^<!--\s*embed:\s*(\S+?)#L(\d+)-L(\d+)\s*-->$/);
    if (!m) {
      if (/<!--.*embed:/.test(line)) warn(r, `line ${i + 1} looks like an embed directive but does not parse`,
        'expected exactly: <!-- embed: relative/path#Lstart-Lend -->');
      continue;
    }
    const [, src, a, b] = m;
    const srcAbs = resolve(dirname(p), src);
    if (!existsSync(srcAbs)) { err(r, `embed source missing: ${src}`, 'fix the path'); continue; }
    let j = i + 1;
    while (j < lines.length && lines[j].trim() === '') j++;
    if (!lines[j]?.startsWith('```')) { err(r, `embed directive at line ${i + 1} not followed by a code fence`, 'add ``` fence right after the directive'); continue; }
    const fenceStart = j + 1;
    let k = fenceStart;
    while (k < lines.length && !lines[k].startsWith('```')) k++;
    const body = lines.slice(fenceStart, k).join('\n');
    const want = readFileSync(srcAbs, 'utf8').split('\n').slice(a - 1, +b).join('\n');
    if (body !== want) err(r, `embed drift at line ${i + 1} (${src}#L${a}-L${b})`,
      'source changed — re-copy the lines (or update the range); specs must embed live truth');
  }
}

// ---- 5. tasks.md state header + checkbox shape (nesting allowed)
for (const p of mdFiles.filter(p => /(^|\/)openspec\/changes\/[^/]+\/tasks\.md$/.test(rel(p)))) {
  const r = rel(p);
  const head = readFileSync(p, 'utf8').split('\n').slice(0, 5).join('\n');
  if (!/^As of \d{4}-\d{2}-\d{2} — .+/m.test(head))
    err(r, 'missing state header in first 5 lines', 'add a line: "As of YYYY-MM-DD — stage N, next: <action>" (overwrite it each session)');
  const bad = readFileSync(p, 'utf8').split('\n')
    .map((l, i) => [l, i + 1]).filter(([l]) => /^\s*-\s*\[/.test(l) && !/^\s*- \[( |x)\] \S/.test(l));
  for (const [, n] of bad) err(r, `malformed checkbox at line ${n}`, 'use "- [ ] task" or "- [x] task" (indentation for sub-tasks is fine)');
}

// ---- 6. delta specs must use delta sections
for (const p of mdFiles.filter(p => /(^|\/)openspec\/changes\/[^/]+\/specs\/.+\.md$/.test(rel(p)))) {
  const r = rel(p);
  const txt = readFileSync(p, 'utf8');
  if (!/^## (ADDED|MODIFIED|REMOVED) Requirements$/m.test(txt))
    err(r, 'no ADDED/MODIFIED/REMOVED section', 'delta specs describe changes, not full state — use the delta sections');
}

// ---- report
if (warns.length) console.log(`warnings (${warns.length}):\n${warns.join('\n')}\n`);
if (errors.length) {
  console.log(`errors (${errors.length}):\n${errors.join('\n')}\n\n✗ corp-lint failed`);
  process.exit(1);
}
console.log('✓ corp-lint passed');
