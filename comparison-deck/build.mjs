#!/usr/bin/env node
// Build the standalone Corp SDD vs OpenSpec prospect deck without changing the main deck.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = join(HERE, '..')
const TEMPLATE = join(ROOT, 'ru', 'slides', 'src', 'deck-template.html')
const CONTENT = join(HERE, 'content.json')
const OUTPUT = join(ROOT, 'docs', 'comparison', 'index.html')

const theme = {
  light: {
    bg: '#E7ECEF', stage: '#FCFDFD', ink: '#132026', muted: '#56676F', faint: '#89979D',
    line: '#DDE5E8', accent: '#087E8B', accent2: '#075E68', accentSoft: 'rgba(8,126,139,0.10)',
    accentInk: '#ffffff',
  },
  dark: {
    bg: '#070C0E', stage: '#10171A', ink: '#EAF0F1', muted: '#95A5AB', faint: '#5F7279',
    line: '#223036', accent: '#49CBD8', accent2: '#83DAE2', accentSoft: 'rgba(73,203,216,0.15)',
    accentInk: '#061014',
  },
}

const meta = {
  title: 'Corp SDD × OpenSpec',
  deckLabel: 'Сравнение',
  docTitle: 'Corp SDD vs OpenSpec — prospect deck',
}

function variables(tokens) {
  return [
    `--bg:${tokens.bg}`, `--stage:${tokens.stage}`, `--ink:${tokens.ink}`,
    `--muted:${tokens.muted}`, `--faint:${tokens.faint}`, `--line:${tokens.line}`,
    `--accent:${tokens.accent}`, `--accent-2:${tokens.accent2}`,
    `--accent-soft:${tokens.accentSoft}`, `--accent-ink:${tokens.accentInk}`,
  ].join(';') + ';'
}

function tokenCss() {
  const light = variables(theme.light)
  const dark = variables(theme.dark)
  return [
    `:root{${light}}`,
    `@media (prefers-color-scheme:dark){:root{${dark}}}`,
    `:root[data-theme="light"]{${light}}`,
    `:root[data-theme="dark"]{${dark}}`,
  ].join('\n')
}

function safeJson(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c').replace(/>/g, '\\u003e')
}

const slides = JSON.parse(readFileSync(CONTENT, 'utf8'))
const body = readFileSync(TEMPLATE, 'utf8')
  .replace('/*__TOKENS_CSS__*/', tokenCss())
  .replace('/*__META_JSON__*/{}', safeJson(meta))
  .replace('/*__SLIDES_JSON__*/[]', safeJson(slides))

for (const marker of ['__TOKENS_CSS__', '__META_JSON__', '__SLIDES_JSON__']) {
  if (body.includes(marker)) throw new Error(`unreplaced template marker: ${marker}`)
}

const html = `<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>${meta.docTitle}</title>
</head>
<body>
${body}
</body>
</html>
`

mkdirSync(dirname(OUTPUT), { recursive: true })
writeFileSync(OUTPUT, html)
console.log(`built ${slides.length} slides -> ${OUTPUT}`)
