# Corporate SDD — пошаговое руководство по внедрению

**Дополнение к:** [2026-07-17-corp-sdd-transition-design.md](../specs/2026-07-17-corp-sdd-transition-design.md) (APPROVED) · **Дата:** 2026-07-18
**Передача:** реализующий агент начинает с [2026-07-18-corp-sdd-handoff-to-coder-agent.md](2026-07-18-corp-sdd-handoff-to-coder-agent.md). **Руководство для команды:** [2026-07-18-corp-sdd-team-playbook.md](2026-07-18-corp-sdd-team-playbook.md) — раздайте каждой роли её раздел во время онбординга фазы 1.

> **⚠ ХАРНЕСС — ЭТО ПОРТ.** Организация использует **корпоративный порт агентского CLI, а не ванильную (апстрим) версию**. Каждая механика уровня харнесса в этом руководстве, взятая из апстрим-документации агента — каталог конфигурации `.agent/`, расположение/формат кастомных команд, поддержка Agent-Skills, подключение MCP, headless-флаги, имя контекстного файла — это **допущение по умолчанию, которое нужно ПРОВЕРИТЬ на порте** (§0a), а не факт. Пять скриптов из §10 не зависят от харнесса (чистый Node/bash поверх файлов) и не затронуты, за исключением двух строк в `corp-lint.mjs`, которые называют каталог конфигурации: запись `.agent` в `SCOPES` и регулярное выражение `\.agent\/skills\/` в `CAPS` — переименуйте обе в каталог конфигурации порта, если он отличается (эти две строки — единственные санкционированные правки скриптов).

**Статус проверки:** каждый скрипт из §10 был выполнен на синтетическом пилотном репозитории + сторе, затем **независимый состязательный ревьюер заново выполнил всё руководство с нуля** и подал 11 замечаний (1 блокер, 4 серьёзных) — все исправлены и повторно доказаны. Полная матрица в §11 (T0–T18). Пункты, помеченные **TEMPLATE**, *не* выполнялись (нужны ваши реальные self-hosted CI/трекер/агентский CLI) — прогоните на них дымовой тест, прежде чем полагаться на них.

**Заявленные отклонения от проектного документа** (все ради детерминизма без зависимостей):
1. Машинный индекс — это **`index.json`** (не yaml) — нативный парсинг, канонический вывод. То же для **`repos.json`**.
2. Штамп свежести на уровне репозитория — это **контентный `source_digest` + закоммиченный `openspec/repo.txt`** вместо git SHA (SHA не может ссылаться на собственный коммит; дайджест самосогласован и не зависит от машины). Проектная проверка свежести «сравнить штамп с HEAD» живёт на уровне **стора**: записи каталога несут HEAD SHA каждого клона.
3. Агрегатор реализует **keep-last-good**: предыдущая запись красного репозитория переносится, помечается `stale` и никогда молча не отбрасывается.
4. Внешние проверяльщики из проекта (lychee, embedmd, check-jsonschema) **встроены в corp-lint нативно** (проверки ссылок/якорей, встраиваний, схемы — протестировано T2/T3/T13): меньше бинарников для распространения, те же гарантии. lefthook остаётся единственным сторонним бинарником.

## 0a. Обследование порта — сделайте это ПЕРВЫМ ДЕЛОМ (полдня)

Установите, что корпоративный порт на самом деле поддерживает. Записывайте каждый ответ в **`port-facts.md` в системном сторе** (закоммиченный — он параметризует остальную часть этого руководства). Для каждого пункта: запустите пробу, вставьте доказательство.

| # | Вопрос | Проба | Ванильное значение по умолчанию (только допущение) |
|---|---|---|---|
| P1 | Имя каталога конфигурации проекта? | создайте локальный для репозитория файл settings/config там, где указывает документация порта; подтвердите, что порт его читает | `.agent/` |
| P2 | Поддерживаются ли кастомные slash-команды? Расположение + формат? | положите тривиальную команду `hello` (Markdown, затем TOML если нужно); вызовите её; отметьте точный синтаксис в палитре | `.agent/commands/*.md` (TOML legacy); `/name` или `name` |
| P3 | Поддерживаются ли Agent Skills (вызываемый моделью SKILL.md)? | разместите маркерный скилл («когда спрашивают POLO, отвечай MARCO»); протестируйте и авто-триггер, и явный вызов | `.agent/skills/<name>/SKILL.md`; авто-триггер ненадёжен — планируйте явный вызов |
| P4 | Поверхность конфигурации MCP? Достижимы ли из порта MCP трекера/вики/JVM LSP? | зарегистрируйте один заведомо рабочий MCP-сервер; выведите список инструментов из сессии | `mcpServers` в settings.json (stdio/HTTP/SSE) |
| P5 | Headless-режим для CI? | запустите порт неинтерактивно с промптом; зафиксируйте формат вывода + код выхода | `-p`, `--yolo`, `--approval-mode`, `--output-format json` |
| P6 | Env-маршрут шлюза? | направьте порт на self-hosted шлюз модели через env; подтвердите завершение | `OPENAI_BASE_URL/_API_KEY/_MODEL` |
| P7 | Контекстный файл, который порт читает автоматически? | маркерная строка в файлах-кандидатах (`AGENT.md`, `AGENTS.md`, специфичный для порта); посмотрите, какой попадает в контекст | `AGENT.md`/`AGENTS.md` |
| P8 | Попадает ли вывод `openspec init --tools <your-agent>` туда, где смотрит порт? | запустите его; если нет — попробуйте другие адаптеры OpenSpec или вручную разместите сгенерированные файлы согласно ответам P1/P2 | адаптер целится в `.agent/` |

Если P2 **и** P3 оба провалились: порт не может разместить поверхность команд — ОСТАНОВИТЕСЬ и эскалируйте оператору (резервный дизайн: обычные файлы-промпты, которые команда вставляет, или обёрточные shell-алиасы, вызывающие headless-режим — реальная деградация, достойная человеческого решения).

## 0b. Предпосылки (однократно)

- [ ] Node ≥ 20 на машинах разработчиков и агентах CI (диспозер — Node + bash без зависимостей).
- [ ] **OpenSpec зеркалирован во внутреннем npm-реестре** (ограниченная сеть — `npx openspec` должен резолвиться внутренне) и версия зафиксирована.
- [ ] Корпоративный порт агентского CLI установлен по стандарту команды; настройки шлюза распространены (согласно **P6**).
- [ ] MCP-серверы для вашего трекера + вики достижимы **из порта** (согласно **P4**); подтвердите имя развёрнутого **JVM LSP MCP** и его конфигурацию подключения.
- [ ] Бинарник `lefthook` доступен через ваш внутренний канал пакетов (единый Go-бинарник; по ОС).
- [ ] Выберите 2–3 пилотных репозитория (микс: один многомодульный JVM-репозиторий, один попроще — команды 20/60/20 евангелисты/представительные/скептики).
- [ ] Снимите **базовые метрики до любого раскатывания** (§7).

## 1. Создайте системный стор (30 мин)

```bash
git init system-store && cd system-store
mkdir -p tools contracts conventions
cat > repos.json <<'EOF'
{ "clones_dir": "../clones", "repos": [
  { "name": "pilot-repo-a", "url": "ssh://git@your-forge/org/pilot-repo-a.git" },
  { "name": "pilot-repo-b", "url": "ssh://git@your-forge/org/pilot-repo-b.git" }
] }
EOF
# add tools/aggregate-index.mjs and tools/sync-repos.sh from §10
chmod +x tools/sync-repos.sh
bash tools/sync-repos.sh              # materialize local clones (exit 1 on any failure)
node tools/aggregate-index.mjs       # builds catalog.json + catalog.md (RED entries are loud)
git add -A && git commit -m "system store: skeleton + first catalog"
```

Имена репозиториев в `repos.json` ограничены на входе (`[a-z0-9._-]`, уникальны) — оба инструмента отвергают невалидную конфигурацию с кодом выхода 2. Также заложите: `helicopter.md` (одна страница: системы, границы интеграции), `conventions/` (правила организации, на которые ссылаются команды), `contracts/` (пустой до первого кросс-репозиторного изменения). Стройте реестр владения, когда появится первая коллизия — не раньше.

## 2. Онбординг каждого пилотного репозитория (~1 час на каждый)

```bash
cd pilot-repo-a
npx openspec init --tools <your-agent>  # pin the version; verify output lands per P8 —
                                        # if the port reads a different dir, move/symlink the
                                        # generated command+skill files to the P1/P2 locations
mkdir -p tools
# add tools/corp-lint.mjs, tools/gen-index.mjs, tools/verify-docs.sh from §10
chmod +x tools/verify-docs.sh
node tools/gen-index.mjs                # first index; ALSO writes openspec/repo.txt (committed identity —
                                        # never depend on the checkout folder name; CI renames it)
cat > lefthook.yml <<'EOF'
pre-commit:
  parallel: true
  commands:
    docs-disposer:
      run: bash tools/verify-docs.sh
EOF
lefthook install
bash tools/verify-docs.sh               # must print: ✓ verify-docs passed
git add -A && git commit -m "SDD onboarding: openspec + disposer + index (incl. openspec/repo.txt)"
```

Многомодульные JVM-репозитории: также подключите список модулей в индекс — добавьте шаг сборки, который пишет по одному модулю на строку в `build/modules.txt` (Maven: плагин depgraph; Gradle: `./gradlew -q projects | grep -oP "':\K[^']+"`), затем перегенерируйте. `gen-index.mjs` подхватывает файл автоматически. Линтер сканирует только `openspec/`, `docs/`, `.agent/` — вывод сборки (`target/`, `build/`) никогда не линтуется.

## 3. Подключение агентской самопроверки (15 мин на репозиторий)

Добавьте в контекстный файл агента репозитория (**файл, который проба P7 доказала как читаемый портом** — апстрим-кандидаты: `AGENT.md` / `AGENTS.md`):

```markdown
## HARD RULE — disposer self-check
After creating or editing ANY file under openspec/ or docs/, run:
    bash tools/verify-docs.sh
Fix every ✗ (each error carries a remediation hint) and re-run until green
BEFORE reporting work done or proposing a commit. Rejected writes are corrected
by regenerating the content — never by loosening caps or deleting checks.
CIRCUIT BREAKER: if the same error survives 3 fix attempts, STOP and ask a human —
do not keep looping.
```

Это контракт границы записи: один и тот же скрипт гейтит агента (после записи), человека (перед коммитом через lefthook) и CI (подстраховка) — один путь кода, три триггера.

## 4. Подстраховка CI (TEMPLATE — адаптируйте и прогоните дымовой тест)

```groovy
// определение CI-пайплайна — stage для spoke-репозиториев
stage('docs-disposer') { steps { sh 'bash tools/verify-docs.sh' } }

// пайплайн системного стора: ночной + по мержам spoke-репозиториев (webhook или cron)
stage('catalog') {
  steps {
    sh 'bash tools/sync-repos.sh'
    sh 'node tools/aggregate-index.mjs --strict'   // red repo fails the build, loudly
    sh 'git add catalog.json catalog.md && git diff --cached --quiet || git commit -m "catalog: refresh" && git push'
  }
}
```

Held-out гейты (фаза 2, согласно проекту §3): отдельные CI-задания с разделёнными по учётным данным правами для контрактных тестов / совместимости схем / линта миграций — задание, обращённое к агенту, не должно делить с ними учётные данные.

## 5. Вендоренные команды + скиллы (тела TEMPLATE — адаптируйте к порту согласно P1/P2)

**Полный набор живёт в [harness pack](2026-07-18-corp-sdd-harness-pack.md): все СЕМЬ тел команд (шесть глаголов, на которые ссылаемся ниже, + `corp-archive` для закрытия после слияния), все пять текстов скиллов (самодостаточные — во внутренней ограниченной сети не нужен внешний репозиторий) и каждый файл-шаблон (research.md, ADR, контракт стора, port-facts) плюс ручной кросс-репозиторный чек-лист.** Установка согласно §E пака. Два примера команд встроены здесь, чтобы задать паттерн:

**`<port-command-dir>/corp-spec.md`**
```markdown
---
description: Draft a delta spec from a tracker story via interview (analyst flow)
---
You are drafting a delta spec for story {{args}}.
1. Fetch the story and linked wiki pages via the tracker/wiki MCP tools.
2. Read openspec/index.md, then ONLY the living specs the story touches; follow skill
   corp-drill-down (central catalog → repo index → live files; repo wins; ≤3 hops).
3. Verify every contract fact against live code (embed with <!-- embed --> directives).
4. Interview the analyst — ONE question at a time, multiple-choice preferred — until
   requirements and Given/When/Then scenarios are unambiguous.
5. Create the OpenSpec change (proposal + delta spec) via the opsx workflow.
   Append every verified fact as a pointer line to research.md (path#Lx-Ly + finding).
6. Run: bash tools/verify-docs.sh — fix until green.
7. HANDOVER (do this yourself — the analyst never touches git): create/switch to the
   change branch, commit the change folder, push, and open (or update) the spec PR.
   Post the spec summary + PR link back to the tracker story. Do NOT create design.md
   or tasks.md (plan happens at pull time).
```

**`<port-command-dir>/corp-implement.md`**
```markdown
---
description: Implement the current change task-by-task under TDD discipline (dev flow)
---
Implement change {{args}}.
Discipline: follow skills corp-tdd (all coding), corp-verification (all done-claims),
corp-debugging (any unexpected failure), corp-drill-down (any fact about the system).
0. Read tasks.md state header + research.md FIRST — resume, never re-derive.
1. If design.md/tasks.md are missing or stale (index digest changed): regenerate them
   now against current code (plans are disposable, specs are durable).
2. Per task: write the failing test from the spec scenario (fast unit tier; slow
   integration tier only at task boundaries) → implement → run → record evidence in
   tasks.md → tick the checkbox → overwrite the state header.
3. On spec/code mismatch STOP and classify: (a) spec incomplete → draft amendment to
   the delta on this branch, notify analyst via tracker, wait; (b) code surprising but
   spec right → regenerate tasks, note in research.md; (c) unimplementable → halt, escalate.
4. After every file write under openspec/ or docs/: bash tools/verify-docs.sh.
5. Done = all boxes ticked + full test suite green + verify-docs green. Never claim
   done without pasted evidence of the last test run.
```

Остальные пять (`corp-plan`, `corp-review`, `corp-test-plan`, `corp-autotest`, `corp-archive`) — **полные тела в harness pack §A**. Пять скиллов, на которые они ссылаются (`corp-tdd` с разбиением на быстрый/медленный ярусы, `corp-verification`, `corp-debugging`, `corp-code-review`, `corp-drill-down`) — **полные тексты в harness pack §B**, установите в каталог скиллов порта (P3; если порт не поддерживает скиллы, встройте согласно §E пака). Закоммитьте всё в репозиторий — клон = сконфигурирован.

## 6. Дымовой тест цикла (полдня, один чемпион)

Прогоните одну **реальную, но небольшую** историю от начала до конца: интервью `corp-spec` → аналитик утверждает отрендеренную спеку (поверхность ревью фазы 1 = markdown-рендеринг форжа в PR; скрипт зеркалирования в вики — приятность фазы 2, не блокер) → `corp-plan` + `corp-implement` → PR со спекой и кодом вместе → слияние → **`corp-archive` на main** (сворачивает делту в живую спецификацию, черновик ADR, перегенерация индекса) → каталог стора подхватывает это на следующей агрегации. Каждая точка трения, найденная здесь, — это баг в харнессе, а не в людях — исправьте команду/скилл/скрипт, закоммитьте, повторите.

## 7. Базовые метрики (до фазы 1)

TESTED (чистый git, прогон на каждый репозиторий; примечание: основано на merge-коммитах — репозитории со squash-merge должны считать subject'ы PR-merge через `git log --grep` вместо этого):
```bash
# merges in the trailing 90 days (deploy-frequency proxy until CI data is wired)
git log --merges --since="90 days ago" --format=%cI | wc -l
# median hours from branch's first commit to merge (lead-time proxy)
git log --merges --since="90 days ago" --format="%H" | while read -r m; do
  s=$(git log --format=%ct "$m"^1.."$m"^2 2>/dev/null | tail -1); e=$(git show -s --format=%ct "$m")
  [ -n "$s" ] && echo $(( (e - s) / 3600 ))
done | sort -n | awk '{a[NR]=$1} END{if(NR)print a[int((NR+1)/2)]" h median"}'
```
TEMPLATE: change-failure-rate + MTTR из вашего трекера инцидентов; частота деплоя из CI (`/api/json` на задании деплоя); rework rate = % PR, помеченных fix/revert; анти-геймингом проверка порядка спеки на каждое заархивированное изменение (`git log --diff-filter=A --format=%ct -- openspec/changes/<id>/proposal.md | tail -1` должно предшествовать первому коммиту реализации на этой ветке — спека, написанная после кода = театр потока, считайте её как неприживаемость).
**Пульс DevEx — используйте эти пять, дословно, ежеквартально, анонимно, на уровне команды (шкала 1–5 + один свободный текст):** (1) «Насколько вы удовлетворены своим повседневным рабочим процессом разработки?» (2) «Как часто вы можете работать над задачей, не теряя поток из-за трения или ожидания?» (3) «Как бы вы оценили качество код-ревью, которое вы получаете?» (4) «Насколько поток SDD помогает vs мешает вашей работе?» (5) «Порекомендовали бы вы этот поток коллеге из другой команды?» + «Что одно нам следует исправить?»
Записывайте всё в заметку `baselines/` в сторе.

## 8. Чек-лист выхода из фазы 0

- [ ] Стор живой: `sync-repos` + `aggregate-index --strict` зелёные в ночном CI
- [ ] 2–3 пилотных репозитория: диспозер зелёный в pre-commit И CI; индекс + `repo.txt` закоммичены
- [ ] Команды + скиллы вендорены; JVM LSP MCP подключён; чемпион завершил §6 на реальной истории
- [ ] Базовые метрики записаны; путь исключений задокументирован («любая история может пропустить поток — отметьте почему в трекере»)
- [ ] Назначены чемпионы; **назначен владелец харнесса** (DevOps — владеет пинами, заданием каталога, переобследованиями порта); забронирован еженедельный слот office-hour
- [ ] Счётчик приживаемости работает: `ls openspec/changes/archive 2>/dev/null | wc -l` на каждый репозиторий vs число feature-merge (еженедельное число фазы 1)

Затем запустите фазу 1 точно по проекту §11 (opt-in, демо-день, 4-недельные гейты). Единственная go/no-go метрика для еженедельного наблюдения: **остаются ли индексы зелёными без человеческих усилий?**

## 9. Правила эксплуатации (распечатайте это)

1. Промпты советуют, диспозер и CI принуждают. Никогда не исправляйте красную проверку, ослабляя её.
2. Капы отвергают, а не подрезают. Агент перегенерирует; люди никогда не чинят вручную сгенерированные файлы.
3. Центральный каталог — это подсказка маршрутизации. Индекс репозитория выше него; репозиторий выше своего индекса.
4. Спеки долговечны, планы одноразовы. Перегенерируйте design/tasks всякий раз при сомнении.
5. Каждое обнаруженное расхождение спеки/кода становится делтой — это база спек растёт, а не провал.
6. Одна и та же ошибка три раза → остановитесь и спросите человека.

## 10. Справочник скриптов (протестированные исходники, после ревью)

### tools/corp-lint.mjs (spoke repos)
```javascript
#!/usr/bin/env node
// corp-lint.mjs — deterministic disposer for agent-written docs. Zero dependencies.
// Scope: openspec/, docs/, .agent/ only (never lints build output or source code docs).
// Checks: hard file caps, index<->spec bijection + index schema, relative links + anchors,
// embedded snippets vs source, tasks.md state header, delta-spec sections.
// Every ERROR carries a remediation hint. Exit 1 on any ERROR; WARNs never block.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative, sep } from 'node:path';

const ROOT = resolve(process.argv[2] ?? '.');
const SCOPES = ['openspec', 'docs', '.agent'].map(d => join(ROOT, d)).filter(existsSync);

// ---- hardcoded caps (lines). The write-boundary contract: exceed => rejected, never trimmed.
const CAPS = [
  [/(^|\/)openspec\/index\.md$/, 300],
  [/(^|\/)openspec\/specs\/.+\/spec\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/tasks\.md$/, 200],
  [/(^|\/)openspec\/changes\/.+\/research\.md$/, 400],
  [/(^|\/)openspec\/changes\/.+\/proposal\.md$/, 200],
  [/(^|\/)\.agent\/skills\/.+\.md$/, 250],
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
```

### tools/gen-index.mjs (spoke repos)
```javascript
#!/usr/bin/env node
// gen-index.mjs — generates openspec/index.json + index.md from openspec/specs/ (+ optional build/modules.txt).
// Deterministic across machines: byte-wise sort (no locale), digest built from sorted content,
// repo name from committed openspec/repo.txt (never from the checkout folder name).
// --check: regenerate in memory and diff against committed files; exit 1 on drift.
import { readFileSync, readdirSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { createHash } from 'node:crypto';

const CHECK = process.argv.includes('--check');
const ROOT = resolve(process.argv.filter(a => !a.startsWith('--'))[2] ?? '.');
const osDir = join(ROOT, 'openspec');
const specsDir = join(osDir, 'specs');
const repoTxt = join(osDir, 'repo.txt');

// repo identity is committed data, not the folder name (CI workspaces, worktrees, renamed clones)
const repoName = existsSync(repoTxt) ? readFileSync(repoTxt, 'utf8').trim() : basename(ROOT);

const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0); // byte-wise, locale-independent
const caps = [];
const texts = {};
if (existsSync(specsDir)) {
  for (const d of readdirSync(specsDir, { withFileTypes: true }).filter(e => e.isDirectory())) {
    const specPath = join(specsDir, d.name, 'spec.md');
    if (!existsSync(specPath)) continue; // dirs without spec.md are corp-lint's problem, not the index's
    const txt = readFileSync(specPath, 'utf8');
    texts[d.name] = txt;
    const title = txt.match(/^#\s+(.+)$/m)?.[1]?.trim() ?? d.name;
    const summary = (txt.split('\n').find(l => l.trim() && !l.startsWith('#')) ?? '').trim().slice(0, 200);
    caps.push({ id: d.name, title, path: `openspec/specs/${d.name}/spec.md`, summary });
  }
}
caps.sort(byId);

let modules = [];
const modFile = join(ROOT, 'build', 'modules.txt'); // produced by the build: mvn/gradle module list
if (existsSync(modFile)) {
  modules = readFileSync(modFile, 'utf8').split('\n').map(s => s.trim()).filter(Boolean).sort(); // default sort = code-unit order
}

// digest over SORTED content so filesystem readdir order can never change it
const digestInput = [repoName, ...caps.map(c => c.id + '\x00' + texts[c.id]), ...modules];
const index = {
  schema_version: 1,
  repo: repoName,
  source_digest: createHash('sha256').update(digestInput.join('\x01')).digest('hex').slice(0, 16),
  capabilities: caps,
  ...(modules.length ? { modules } : {}),
};
const json = JSON.stringify(index, null, 2) + '\n';

const md = [
  `# ${index.repo} — capability index`,
  '',
  `> GENERATED by tools/gen-index.mjs — do not edit. digest: ${index.source_digest}`,
  '',
  ...caps.map(c => `- [${c.title}](${c.path.replace(/^openspec\//, '')}) — ${c.summary}`),
  ...(modules.length ? ['', '## Modules', '', ...modules.map(m => `- ${m}`)] : []),
  '',
].join('\n');

const jsonPath = join(osDir, 'index.json');
const mdPath = join(osDir, 'index.md');

if (CHECK) {
  const cur = f => (existsSync(f) ? readFileSync(f, 'utf8') : '');
  if (cur(jsonPath) !== json || cur(mdPath) !== md) {
    console.error('✗ index drift: openspec/index.* does not match current specs');
    console.error('  ↳ run: node tools/gen-index.mjs && git add openspec/index.json openspec/index.md openspec/repo.txt');
    process.exit(1);
  }
  console.log('✓ index up to date');
} else {
  mkdirSync(osDir, { recursive: true });
  if (!existsSync(repoTxt)) writeFileSync(repoTxt, repoName + '\n'); // pin identity on first run — commit it
  writeFileSync(jsonPath, json);
  writeFileSync(mdPath, md);
  console.log(`✓ wrote openspec/index.json + index.md (${caps.length} capabilities, digest ${index.source_digest})`);
}
```

### tools/verify-docs.sh (spoke repos)
```bash
#!/usr/bin/env bash
# verify-docs.sh — the disposer entry point. One code path, four triggers:
# agent post-write self-check / lefthook pre-commit / on demand / CI backstop.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
node tools/gen-index.mjs --check || fail=1
node tools/corp-lint.mjs || fail=1
if [ "$fail" -ne 0 ]; then
  echo "✗ verify-docs failed — fix the errors above (each carries a remediation hint), then retry"
  exit 1
fi
echo "✓ verify-docs passed"
```

### tools/aggregate-index.mjs (system store)
```javascript
#!/usr/bin/env node
// aggregate-index.mjs — builds the store's thin catalog from spoke repos' generated indexes.
// Central = routing hint only. Invalid/missing spoke index => RED entry + last-good data kept (stale:true).
// repos.json names are input-gated (unique, safe charset). --strict (CI mode): exit 1 if any repo is red.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execSync } from 'node:child_process';

const STRICT = process.argv.includes('--strict');
const ROOT = resolve(process.argv.filter(a => !a.startsWith('--'))[2] ?? '.');
const cfg = JSON.parse(readFileSync(join(ROOT, 'repos.json'), 'utf8'));
// repos.json: { "clones_dir": "..", "repos": [ { "name": "...", "url": "..." } ] }
const clonesDir = resolve(ROOT, cfg.clones_dir);

// input gate: names become filesystem paths and shell words — constrain at the boundary
const seen = new Set();
for (const r of cfg.repos) {
  if (!/^[a-z0-9][a-z0-9._-]*$/.test(r.name)) { console.error(`✗ repos.json: invalid repo name "${r.name}" (allowed: [a-z0-9._-], no leading dot/dash)`); process.exit(2); }
  if (seen.has(r.name)) { console.error(`✗ repos.json: duplicate repo name "${r.name}"`); process.exit(2); }
  seen.add(r.name);
}

// keep-last-good: carry a red repo's previous entry, marked stale, instead of dropping it
const prevPath = join(ROOT, 'catalog.json');
const prev = existsSync(prevPath) ? JSON.parse(readFileSync(prevPath, 'utf8')) : { entries: [] };
const prevByName = new Map((prev.entries ?? []).map(e => [e.name, e]));

const entries = [], red = [];
const byName = (a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0); // byte-wise, locale-independent
for (const r of [...cfg.repos].sort(byName)) {
  const repoDir = join(clonesDir, r.name);
  const idxPath = join(repoDir, 'openspec', 'index.json');
  try {
    if (!existsSync(repoDir)) throw new Error('clone missing — run tools/sync-repos.sh');
    if (!existsSync(idxPath)) throw new Error('openspec/index.json missing — repo not onboarded or index not generated');
    const idx = JSON.parse(readFileSync(idxPath, 'utf8'));
    if (!Array.isArray(idx.capabilities)) throw new Error('index.json has no capabilities[] — regenerate in the repo');
    const head = execSync('git rev-parse --short HEAD', { cwd: repoDir }).toString().trim();
    entries.push({ name: r.name, url: r.url, head, digest: idx.source_digest, capabilities: idx.capabilities.map(c => ({ id: c.id, title: c.title, summary: c.summary })) });
  } catch (e) {
    red.push({ name: r.name, reason: e.message });
    const lastGood = prevByName.get(r.name);
    if (lastGood) entries.push({ ...lastGood, stale: true, stale_reason: e.message });
  }
}
entries.sort(byName);

const catalog = { schema_version: 1, entries, red };
writeFileSync(join(ROOT, 'catalog.json'), JSON.stringify(catalog, null, 2) + '\n');

const md = [
  '# System catalog',
  '',
  '> GENERATED by tools/aggregate-index.mjs — routing hints only. The repo index is the authority; the repo itself outranks its index.',
  '',
  ...(red.length ? ['## 🔴 RED — fix before trusting the catalog', '', ...red.map(x => `- **${x.name}**: ${x.reason}`), ''] : []),
  ...entries.flatMap(e => [
    `## ${e.name}${e.stale ? ' ⚠ STALE (last-good data; see RED above)' : ''}`,
    '',
    `repo: ${e.url} · HEAD \`${e.head}\` · digest \`${e.digest}\``,
    '',
    ...e.capabilities.map(c => `- **${c.id}** — ${c.summary}`),
    '',
  ]),
].join('\n');
writeFileSync(join(ROOT, 'catalog.md'), md);

console.log(`✓ catalog: ${entries.length} entries (${entries.filter(e => e.stale).length} stale), ${red.length} red`);
if (red.length) {
  for (const x of red) console.error(`  🔴 ${x.name}: ${x.reason}`);
  if (STRICT) process.exit(1);
}
```

### tools/sync-repos.sh (system store)
```bash
#!/usr/bin/env bash
# sync-repos.sh — materialize/refresh local clones of every repo in repos.json.
# Safe: ff-only pulls, never touches local work; reports repos that are behind/dirty.
set -uo pipefail
cd "$(dirname "$0")/.."
CLONES_DIR=$(node -e "console.log(require('./repos.json').clones_dir)")
mkdir -p "$CLONES_DIR"
fail=0
repolist=$(node -e "const c=require('./repos.json');const seen=new Set();for(const r of c.repos){if(!/^[a-z0-9][a-z0-9._-]*\$/.test(r.name)||seen.has(r.name)){console.error('invalid/duplicate repo name: '+r.name);process.exit(2)}seen.add(r.name);console.log(r.name+' '+r.url)}") || { echo "✗ repos.json failed validation"; exit 2; }
while read -r name url; do
  [ -z "$name" ] && continue
  dir="$CLONES_DIR/$name"
  if [ ! -d "$dir/.git" ]; then
    echo "cloning $name..."
    git clone --quiet "$url" "$dir" || { echo "🔴 $name: clone failed"; fail=1; continue; }
  else
    ( cd "$dir"
      git fetch --quiet origin || { echo "🔴 $name: fetch failed"; exit 1; }
      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠ $name: local changes — skipped pull (drill-down may read stale files here)"
      elif ! git pull --quiet --ff-only; then
        echo "⚠ $name: cannot fast-forward (diverged) — resolve manually"
      fi
    ) || fail=1
  fi
done <<< "$repolist"
if [ "$fail" -ne 0 ]; then
  echo "✗ sync finished with failures (see 🔴 above)"
  exit 1
fi
echo "✓ sync done → $CLONES_DIR"
```

## 11. Свидетельства тестирования (2026-07-18, Node v22, синтетический пилотный репозиторий + стор)

Раунд 1 = матрица автора. Раунд 2 = независимый состязательный ревьюер, заново выполняющий руководство с нуля (11 замечаний: 1 блокер, 4 серьёзных, 6 незначительных — все исправлены ниже и повторно доказаны).

| # | Сценарий | Результат |
|---|---|---|
| T0 | Здоровый репозиторий: спеки + папка изменения + встраивание + кросс-ссылки | ✓ всё зелёное |
| T1 | Папка спеки добавлена без перегенерации индекса | ✗ поймано `gen-index --check` |
| T2 | Битая относительная ссылка + битый якорь заголовка | ✗ оба пойманы с указанием целевого файла |
| T3 | Источник встраивания изменился под спекой | ✗ дрейф встраивания пойман с точным диапазоном |
| T4 | Файл спеки на 410 строк (кап 400) | ✗ жёсткое отвержение по капу |
| T5 | tasks.md без заголовка состояния + чекбокс `- []` | ✗ оба пойманы |
| T6 | Делта-спека, переизлагающая полное состояние (нет делта-секций) | ✗ поймано |
| T7 | Стор: хороший репозиторий + отсутствующий репозиторий | ✓ каталог построен; RED громкий; `--strict` выход 1 |
| T8 | sync-repos: свежий клон, идемпотентный повторный запуск, агрегация из клона | ✓ зелёное |
| T9 | sync-repos: недостижимый origin | ✗ выход 1 (баг pipe-subshell найден в раунде 1, исправлен) |
| T10 | **Клон под другим именем папки (CI workspace)** | ✓ зелёное — блокер ревьюера, исправлен через закоммиченный `openspec/repo.txt` |
| T11 | gen-index/check под LC_ALL=C, en_US.UTF-8, C.UTF-8, POSIX | ✓ стабильно — зависящий от локали `localeCompare` заменён на побайтовую сортировку |
| T12 | Папка capability без spec.md | ✗ отдельная ошибка (был неисправимый цикл перегенерации — замечание ревьюера) |
| T13 | Директива встраивания с хвостовым пробелом + дрейф источника | ✗ всё равно поймано (ранее срабатывало открыто — замечание ревьюера) |
| T14 | Битая ссылка в выводе сборки `target/site/*.md` | проигнорировано — линт ограничен openspec/, docs/, .agent/ |
| T15 | Вложенный под-чекбокс в tasks.md | ✓ разрешено |
| T16 | Директива встраивания внутри кодового ограждения (пример) + некорректная директива | пример проигнорирован; некорректная → WARN, не молчание |
| T17 | repos.json с дублирующимися / path-traversal именами репозиториев | ✗ выход 2, громко (входной гейт) |
| T18 | Репозиторий становится красным после зелёного | last-good запись сохранена, помечена ⚠ STALE (никогда молча не отброшена) |

Баги, найденные тестированием до передачи: неверные относительные ссылки в сгенерированном index.md (раунд 1); зависящий от имени папки индекс, зависящая от локали сортировка, цикл перегенерации биекции, fail-open проверка встраивания, линтинг вывода сборки, вложенность чекбоксов, ENOENT при отсутствующем openspec/, невалидированный repos.json, проглатывание кода выхода sync (раунд 2). **Это философия диспозера, применённая к самому диспозеру.**

**Известные ограничения (намеренно v0):** слаги якорей покрывают латинские заголовки (расширьте `slug()` для кириллицы, если спеки станут двуязычными); проверка split-brain на переизложение и свежесть `sources:` — будущие повышения линта; выключатель на 3 удара — на уровне промпта (§3), а не принуждаемый инструментом; история пагинации index.md >300 строк отложена до момента, когда репозиторий реально в неё упрётся; тела команд/скиллов и сниппеты lefthook/определения CI-пайплайна — TEMPLATE до дымового теста на корпоративном порте и self-hosted CI; **все T-кейсы прогонялись только против файловой системы + git — ничто здесь ещё не выполнялось внутри самого порта** (это задача §0a + §6 в корпоративной среде).
