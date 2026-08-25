#!/usr/bin/env node
// versions.mjs — the version stamper for corp-sdd assets. Zero dependencies.
// Assets = commands (*.md), skills (SKILL.md), scripts (*.sh, *.mjs) in en/ and ru/.
// Every asset carries a semver marker in its own header, so an installed copy states
// its version without any external index:
//   .md   -> `version: X.Y.Z` inside the YAML frontmatter
//   .sh   -> `# corp-sdd-version: X.Y.Z` right after the shebang
//   .mjs  -> `// corp-sdd-version: X.Y.Z` right after the shebang
// Modes:
//   node tools/versions.mjs --stamp [files...]   add the marker where missing (init at 1.0.0)
//   node tools/versions.mjs --bump  <files...>   bump the patch level of those assets
//                                                (only those whose body really changed vs HEAD)
//   node tools/versions.mjs --minor <files...>   bump the minor level (patch -> 0)
//   node tools/versions.mjs --major <files...>   bump the major level (minor/patch -> 0)
//   node tools/versions.mjs --manifest           rewrite VERSIONS.md from the markers
//   node tools/versions.mjs --check              fail if any asset lacks a marker or VERSIONS.md is stale
import { readFileSync, writeFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, resolve, relative, basename, sep } from 'node:path';

const ROOT = resolve(new URL('..', import.meta.url).pathname);
const LANGS = ['en', 'ru'];
const INITIAL = '1.0.0';
const MANIFEST = join(ROOT, 'VERSIONS.md');

function walk(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}

// ---- the asset inventory: one place that decides what is versioned.
export function assets() {
  const out = [];
  for (const lang of LANGS) {
    for (const f of walk(join(ROOT, lang, 'commands'))) {
      if (f.endsWith('.md')) out.push({ path: f, kind: 'command', lang, name: basename(f, '.md') });
    }
    for (const f of walk(join(ROOT, lang, 'skills'))) {
      if (basename(f) === 'SKILL.md') out.push({ path: f, kind: 'skill', lang, name: basename(f.slice(0, f.lastIndexOf(sep))) });
    }
    for (const f of walk(join(ROOT, lang, 'scripts'))) {
      if (f.endsWith('.sh') || f.endsWith('.mjs')) out.push({ path: f, kind: 'script', lang, name: basename(f) });
    }
  }
  return out.sort((a, b) => (a.path < b.path ? -1 : 1));
}

const isAsset = p => assets().some(a => a.path === resolve(p));

function marker(path) {
  return path.endsWith('.md') ? 'yaml' : path.endsWith('.mjs') ? '//' : '#';
}

export function readVersion(path) {
  const text = readFileSync(path, 'utf8');
  const m = marker(path) === 'yaml'
    ? text.match(/^---\r?\n[\s\S]*?^version:[ \t]*([0-9]+\.[0-9]+\.[0-9]+)[ \t]*$/m)
    : text.match(/^(?:#|\/\/) corp-sdd-version:[ \t]*([0-9]+\.[0-9]+\.[0-9]+)[ \t]*$/m);
  return m ? m[1] : null;
}

function setVersion(path, version) {
  const text = readFileSync(path, 'utf8');
  const cur = readVersion(path);
  let next;
  if (cur !== null) {
    next = marker(path) === 'yaml'
      ? text.replace(/^version:[ \t]*[0-9]+\.[0-9]+\.[0-9]+[ \t]*$/m, `version: ${version}`)
      : text.replace(/^((?:#|\/\/) corp-sdd-version:)[ \t]*[0-9]+\.[0-9]+\.[0-9]+[ \t]*$/m, `$1 ${version}`);
  } else if (marker(path) === 'yaml') {
    if (!/^---\r?\n/.test(text)) throw new Error(`${relative(ROOT, path)}: no frontmatter to stamp`);
    const end = text.indexOf('\n---', 3);
    if (end < 0) throw new Error(`${relative(ROOT, path)}: unterminated frontmatter`);
    next = text.slice(0, end) + `\nversion: ${version}` + text.slice(end);
  } else {
    const line = `${marker(path) === '//' ? '//' : '#'} corp-sdd-version: ${version}`;
    const nl = text.indexOf('\n');
    next = text.startsWith('#!')
      ? text.slice(0, nl + 1) + line + '\n' + text.slice(nl + 1)
      : line + '\n' + text;
  }
  if (next !== text) writeFileSync(path, next);
  return version;
}

function bump(path, level) {
  const cur = readVersion(path) ?? INITIAL;
  let [ma, mi, pa] = cur.split('.').map(Number);
  if (level === 'major') { ma += 1; mi = 0; pa = 0; }
  else if (level === 'minor') { mi += 1; pa = 0; }
  else pa += 1;
  return setVersion(path, `${ma}.${mi}.${pa}`);
}

// ---- "really changed" test: the body, with the version marker line removed, must differ
// from the committed one. A file whose only difference IS the marker never bumps again,
// so re-commits, amends, and rebases cannot inflate versions.
function stripMarker(text, path) {
  return marker(path) === 'yaml'
    ? text.replace(/^version:[ \t]*[0-9]+\.[0-9]+\.[0-9]+[ \t]*\r?\n/m, '')
    : text.replace(/^(?:#|\/\/) corp-sdd-version:[ \t]*[0-9]+\.[0-9]+\.[0-9]+[ \t]*\r?\n/m, '');
}

function committedText(path) {
  const rel = relative(ROOT, path).split(sep).join('/');
  try {
    return execFileSync('git', ['show', `HEAD:${rel}`], { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  } catch {
    return null; // new file, or no HEAD yet
  }
}

export function bodyChanged(path) {
  const old = committedText(path);
  if (old === null) return true; // a brand-new asset is a change
  return stripMarker(old, path) !== stripMarker(readFileSync(path, 'utf8'), path);
}

function manifestText() {
  const rows = assets().map(a => ({ ...a, version: readVersion(a.path) ?? '(unstamped)' }));
  const lines = [
    '# Installed asset versions',
    '',
    'Generated by `node tools/versions.mjs --manifest`. Do not edit by hand.',
    'Every command, skill, and script carries the same version inside its own header,',
    'so an installed copy can be identified without this file:',
    '`version:` in Markdown frontmatter, `corp-sdd-version:` in scripts.',
    '',
  ];
  for (const lang of LANGS) {
    lines.push(`## ${lang}`, '');
    for (const kind of ['command', 'skill', 'script']) {
      const group = rows.filter(r => r.lang === lang && r.kind === kind);
      if (!group.length) continue;
      lines.push(`### ${kind}s`, '', '| Asset | Version | Path |', '|---|---|---|');
      for (const r of group) lines.push(`| ${r.name} | ${r.version} | \`${relative(ROOT, r.path)}\` |`);
      lines.push('');
    }
  }
  return lines.join('\n');
}

// ---- CLI
const argv = process.argv.slice(2);
const mode = argv[0] ?? '--check';
const files = argv.slice(1).map(p => resolve(ROOT, p)).filter(p => existsSync(p) && statSync(p).isFile());

if (mode === '--manifest') {
  writeFileSync(MANIFEST, manifestText());
  console.log(`✓ VERSIONS.md written (${assets().length} assets)`);
} else if (mode === '--check') {
  let fail = 0;
  for (const a of assets()) {
    if (!readVersion(a.path)) { console.error(`✗ ${relative(ROOT, a.path)}: no version marker — run: node tools/versions.mjs --stamp`); fail = 1; }
  }
  const want = manifestText();
  const have = existsSync(MANIFEST) ? readFileSync(MANIFEST, 'utf8') : '';
  if (want !== have) { console.error('✗ VERSIONS.md is stale — run: node tools/versions.mjs --manifest'); fail = 1; }
  if (fail) process.exit(1);
  console.log(`✓ versions consistent (${assets().length} assets)`);
} else if (mode === '--stamp') {
  const targets = files.length ? files.filter(isAsset) : assets().map(a => a.path);
  for (const p of targets) {
    if (!readVersion(p)) console.log(`+ ${relative(ROOT, p)} -> ${setVersion(p, INITIAL)}`);
  }
  writeFileSync(MANIFEST, manifestText());
} else if (mode === '--bump' || mode === '--minor' || mode === '--major') {
  const level = mode === '--bump' ? 'patch' : mode.slice(2);
  const candidates = files.filter(isAsset);
  const force = process.env.CORP_SDD_FORCE_BUMP === '1';
  const targets = force ? candidates : candidates.filter(bodyChanged);
  for (const p of targets) console.log(`↑ ${relative(ROOT, p)} -> ${bump(p, level)}`);
  const skipped = candidates.length - targets.length;
  if (skipped) console.log(`= ${skipped} asset(s) unchanged — version kept`);
  writeFileSync(MANIFEST, manifestText());
  if (!candidates.length) console.log('no versioned assets in the given file list');
} else {
  console.error('usage: versions.mjs [--check|--stamp|--bump|--minor|--major|--manifest] [files...]');
  process.exit(2);
}
