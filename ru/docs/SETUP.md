# Задача установки для агента

Выполните эти этапы после получения или обновления `corp-sdd`. Останавливайтесь
при любой ошибке. Сохраняйте команды и вывод в отчёте проекта. Во время установки
не удаляйте и не переписывайте существующие репозитории, ветки и локальную работу.

## 0. Требования к окружению, входные данные и устойчивые пути

Сначала докажите наличие инструментов. Каждая строка должна вывести версию; иначе
установка останавливается. Иначе сбой всплывёт посреди этапа 3, когда хранилище
уже заполнено наполовину:

```bash
git --version        # >= 2.13, нужен `submodule --branch`
node --version       # >= 18, на нём работают .mjs-проверки
rg --version         # нужен для проверки плейсхолдеров на этапе 6
lefthook version     # ставится из разрешённого внутреннего источника
```

CLI OpenSpec закреплён и внутренний. Пакет называется `@fission-ai/openspec`.
Короткое имя `openspec` в публичном реестре — чужая пустышка версии `0.0.0`: она
установится молча и работать не будет. Запишите закреплённую версию в
`port-facts.md` и один раз докажите её:

```bash
npx @fission-ai/openspec@<закреплённая-версия> --version
```

В закрытой сети берите пакет из разрешённого внутреннего зеркала и укажите в отчёте,
какой реестр был использован.

Получите `<project-id>`, название корпоративного порта агента, закреплённую версию
OpenSpec, URL и согласованную базовую ветку системного хранилища, доступ к forge.
В корне `corp-sdd` выполните:

```bash
export CORP_SDD_ROOT="$(git rev-parse --show-toplevel)"
export CORP_WORKSPACE_ROOT="$(cd "$CORP_SDD_ROOT/.." && pwd -P)"
export CORP_SYSTEM_STORE_ROOT="${CORP_SYSTEM_STORE_ROOT:-$CORP_WORKSPACE_ROOT/system-store}"
test -d "$CORP_SDD_ROOT/system-store-template"
test "$CORP_SYSTEM_STORE_ROOT" != "$CORP_SDD_ROOT"
```

Переменные заменяют пути конкретной машины. `system-store` должен находиться
рядом с `corp-sdd`, а не внутри него.

## 1. Найдите репозитории для `<project-id>`

Это первое действие после определения корней. Получите список доступных MCP-инструментов.
Если есть инструмент привязок репозиториев проекта, вызовите его с `<project-id>`.
Включите только репозитории, привязанные к этому проекту. Нормализуйте ответ:

```json
{
  "schema_version": 1,
  "project": "<project-id>",
  "repository_source": "mcp",
  "repositories": [
    {"name": "service-a", "url": "ssh://git@forge/project/service-a.git", "base_branch": "develop"}
  ]
}
```

Ручной резервный путь: если MCP отсутствует, недоступен или не отдаёт привязки,
скопируйте `config/project-repositories.json.example`, установите
`repository_source` в `manual` и заполните те же поля из проекта forge.
Установка продолжается; в отчёте укажите выбранный источник.

Используйте базовую ветку из MCP, если она передана. Иначе выберите `develop`,
если такая удалённая ветка существует, затем символическую ветку по умолчанию.
Не делайте вывод по текущей рабочей копии. До записи проверьте уникальные безопасные
имена, непустые URL и корректные имена веток Git.

## 2. Исследуйте порт агента до установки

Проверьте реальный порт и запишите доказательства в копию `templates/port-facts.md`:

1. каталог конфигурации и имя файла проектных инструкций;
2. каталог и формат команд, синтаксис вызова и токен аргументов;
3. каталог навыков и автоматическую загрузку проектных навыков;
4. точный вызов OpenSpec CLI, доказанный запуском: процесс использует подкоманды CLI
   (`new change`, `status`, `instructions`, `validate`, `archive`), а не slash-команды агента —
   они меняются от версии и профиля;
5. названия MCP-инструментов проекта, трекера, wiki и поиска кода;
6. поддержку хуков, предел контекста и версию агента.

Не предполагайте имя домашнего каталога агента, slash-команды и имена MCP — этот набор
их намеренно не называет: один и тот же набор ставится на порты, где каталог и файл
инструкций называются по-разному. Один раз инициализируйте OpenSpec на временных данных
закреплённым внутренним пакетом и изучите созданные файлы.

Два из этих фактов читает сама тулинг-часть, поэтому запишите их машиночитаемо, а не только
прозой:

```bash
git -C "$REPO" config corp.agentDir "<найденный каталог агента, напр. .acme>"
```

`corp-lint.mjs` определяет домашний каталог агента в таком порядке: `CORP_AGENT_DIR`, затем
`git config corp.agentDir`, затем единственный dot-каталог в корне репозитория, внутри которого
есть подкаталог `skills/`. Если их больше одного — он выходит с кодом 1, а не угадывает. Файл
проектных инструкций порта — аналог `AGENTS.md`, как бы порт его ни называл — настраивать не
нужно: линт берёт любой `.md` в корне, имя которого записано ЗАГЛАВНЫМИ, кроме обычных
проектных файлов (README, LICENSE, CHANGELOG, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, NOTICE).
Запишите оба имени в `port-facts.md` (P1), чтобы человек, читающий заметку, их знал.

Установленные команды вызывают **CLI** OpenSpec, а не сгенерированные slash-команды.
Slash-команды различаются от версии и профиля: в профиле core у OpenSpec 1.10 есть только
`propose, explore, apply, update, sync, archive`, а `new`, `continue` и `verify` нет вовсе.
Шесть вызовов CLI ниже стабильны и машиночитаемы. Запишите ОДИН токен — точный вызов
закреплённого пакета:

```text
<openspec>
```

Подставьте то, что реально работает на этой машине, например
`npx @fission-ai/openspec@<pinned-version>` или внутреннюю обёртку в PATH, и докажите все
шесть вызовов, которые использует процесс:

```bash
<openspec> new change corp-probe
<openspec> status --change corp-probe --json
<openspec> instructions proposal --change corp-probe --json
<openspec> instructions specs --change corp-probe --json
<openspec> instructions apply --change corp-probe --json
<openspec> validate corp-probe --type change --strict --json
<openspec> archive --help
<openspec> store --help
<openspec> show --help
<openspec> list --help
```

Вызовы со стором нельзя доказать, пока стора нет, поэтому докажите их в конце этапа 3 на
зарегистрированном сторе: `store register`, `store list`,
`show <change-id> --type change --store <id> --json --deltas-only`,
`show <spec-id> --type spec --store <id>`, `list --specs --store <id>` и
`instructions specs --change <id> --store <id> --json`. Записывайте каждый доказанный вызов
с выводом в `port-facts.md`.

Затем удалите пробное изменение. Запишите подставленный токен и шесть доказанных вызовов
в `port-facts.md`.

Внешний Superpowers не требуется. Используйте самостоятельные файлы
`skills/corp-*`. Если порт не поддерживает навыки, вставьте тело каждого нужного
навыка в установленную команду и удалите строку `Follow skill ...`.

## 3. Создайте или проверьте соседнее системное хранилище

Три случая, и выбирает машина: не угадывайте и не спрашивайте у оператора то, на
что отвечает Git:

```bash
git ls-remote --heads "<system-store-remote-url>" "<system-store-base-branch>"
```

**Хранилище уже есть на удалённом сервере** (проверка вывела ссылку) — вы второй или
следующий разработчик. Клонируйте, ничего не создавайте:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
git clone --branch "<system-store-base-branch>" --single-branch "<system-store-remote-url>" "$CORP_SYSTEM_STORE_ROOT"
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Путь с шаблоном здесь создал бы через `git init` вторую, не связанную историю против
сервера, где хранилище проекта уже лежит. Это единственная ошибка этого этапа,
которая стоит не повтора, а переделки.

**Проект осознанно создаёт новое пустое хранилище** (проверка ничего не вывела, и это
первая установка вообще) — начните с поставляемого шаблона:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
cp -R "$CORP_SDD_ROOT/system-store-template" "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" init -b "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" remote add origin "<system-store-remote-url>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

**Хранилище уже есть на этой машине** — не копируйте и не клонируйте поверх.
Докажите, что это отдельный Git-корень, затем проверьте ветку и рабочее дерево до
изменения списка репозиториев и установленных файлов:

```bash
test "$(git -C "$CORP_SYSTEM_STORE_ROOT" rev-parse --show-toplevel)" = "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" status --short --branch
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Проверка состояния отклоняет грязное дерево, detached HEAD, неотправленные коммиты
на самой базовой ветке, чужой upstream и расхождение. Она делает только проверенный
fast-forward. Про stash и коммиты на других локальных ветках она сообщает, но не
блокирует работу и ничего не трогает — жёсткой остановкой stash остаётся только для
`assert-archivable`.

Сохраните результат этапа 1 как
`$CORP_SYSTEM_STORE_ROOT/project-repositories.json`. Скопируйте текущие инструменты
и шаблоны, не удаляя проектные файлы:

```bash
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/sync-submodules.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/index-all.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/verify-docs.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/check-git-naming.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/aggregate-index.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/gen-index.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/corp-lint.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/scripts/tools/check-contract-split-brain.mjs" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0755 "$CORP_SDD_ROOT/scripts/tools/check-openspec-root.sh" "$CORP_SYSTEM_STORE_ROOT/tools/"
install -m 0644 "$CORP_SDD_ROOT/templates/port-facts.md" "$CORP_SYSTEM_STORE_ROOT/port-facts.md"
install -m 0644 "$CORP_SDD_ROOT/templates/conventions-branching.md" "$CORP_SYSTEM_STORE_ROOT/conventions/branching.md"
mkdir -p "$CORP_SYSTEM_STORE_ROOT/templates"
install -m 0644 "$CORP_SDD_ROOT/templates/store-contract.md"  "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/testing-stack.md"   "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/research.md"        "$CORP_SYSTEM_STORE_ROOT/templates/"
install -m 0644 "$CORP_SDD_ROOT/templates/adr.md"             "$CORP_SYSTEM_STORE_ROOT/templates/"
```

Инициализируйте OpenSpec в хранилище закреплённым пакетом и портом из этапа 2.
Запустите проверку корня. Зарегистрируйте абсолютный путь со стабильным `<store-id>`.
Докажите через `openspec store list`, что id и путь точны. До этого не выполняйте
другие OpenSpec-команды.

Идентификаторы — это контракт, а не подпись: межрепозиторные ссылки ищут по id, и
два агента, ставящие один проект, обязаны получить одну строку. Для `<store-id>`
берите `<project-id>-store`, для репозитория — его имя из этапа 1, оба в нижнем
регистре через дефис. Запишите оба в `port-facts.md`.

## 4. Создайте подмодули репозиториев проекта

```bash
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- .gitmodules
```

Синхронизация только добавляет и допускает повторный запуск. Она записывает базовые
ветки в `.gitmodules`, отклоняет несовпадающие URL и пути, а исчезнувшие привязки
показывает как сохранённые orphan-записи. Удаляйте такую запись только вручную после
проверки привязки и локальной работы.

## 5. Подключите каждый зарегистрированный подмодуль

Для каждого пути из `.gitmodules`:

1. запустите корневой `repository-state.sh prepare-base` и устраните каждую ошибку;
2. инициализируйте OpenSpec в этом репозитории закреплённым пакетом и портом;
3. через `check-openspec-root.sh` докажите, что корень совпадает с подмодулем;
4. скопируйте в `tools/`: `repository-state.sh`, `corp-lint.mjs`, `gen-index.mjs`,
   `verify-docs.sh`, `check-openspec-root.sh`, `check-contract-split-brain.mjs`,
   `check-git-naming.sh`, а в `templates/` этого репозитория — шаблоны, на которые
   установленные команды ссылаются по пути: `adr.md` (corp-archive), `research.md`
   и `testing-stack.md`. Команда, называющая отсутствующий шаблон, — мёртвая инструкция;
5. скопируйте `config/lefthook.yml.example` в `lefthook.yml`, установите lefthook
   из разрешённого внутреннего источника и выполните `lefthook install`;
6. создайте стабильный id в `openspec/repo.txt`, сгенерируйте индекс и запустите
   корневой `verify-docs.sh`;
6a. скопируйте `templates/testing-stack.md` в `docs/testing-stack.md` этого репозитория и
   заполните его вместе с командой: быстрый и медленный уровни, команда запуска каждого,
   границы связывания, которые ловит только медленный уровень, и порядок границ при отладке.
   `corp-tdd` и `corp-debugging` не называют собственных фреймворков — они читают этот файл,
   поэтому пустой файл оставляет оба навыка без стека;
6b. приведи `.gitignore` этого репозитория в порядок до первого запуска: вывод сборки, кеши
   языка (`__pycache__/`, `*.py[cod]`, `target/`, `build/`, `node_modules/`) и локальные
   настройки должны быть там. За основу возьми `system-store-template/.gitignore`.
   Untracked-файлы не блокируют ни один gate, но игнорируемый файл невидим для всех gate И его
   нельзя случайно закоммитить — именно это нужно для файла настроек с паролем;
7. объявите хранилище в `openspec/config.yaml` этого репозитория, чтобы спека
   ссылалась на общий контракт, а не повторяла его:

   ```yaml
   references:
     - <store-id>
   ```

   Без этого блока не разрешается ни один из маршрутов получения — строк, которые `corp-spec`
   пишет в каждую межрепозиторную delta, — а `check-contract-split-brain.mjs` завершается нулём,
   ничего не проверив: вставленная копия контракта пройдёт незамеченной.

   Объявляйте и remote, а не только id, если CLI это принимает:

   ```yaml
   references:
     - id: <store-id>
       remote: <store-clone-url>
   ```

   С указанным remote машина, где стор не зарегистрирован, получает готовую строку
   `git clone … && openspec store register … --id <store-id>` вместо простой ошибки.

   Маршрута всегда два. Живая спека читается как
   `openspec show <spec-id> --type spec --store <store-id>`, но ТОЛЬКО после архивации change
   контракта. Пока он открыт — а это всё межрепозиторное окно, ведь контракт мержится последним —
   контракт существует только внутри своей change-папки и читается как
   `openspec show <change-id> --type change --store <store-id> --json --deltas-only`. Проверено на
   CLI 2026-08-26: до архивации spec-маршрут выходит с кодом 1 и
   `Spec '<id>' not found at <store>/openspec/specs/<id>/spec.md`, после архивации change-маршрут
   выходит с кодом 1 и `Change "<id>" not found`. `openspec context` печатает только spec-рецепт,
   поэтому в открытом окне ему доверять нельзя.

Создайте собственный OpenSpec-корень каждого подмодуля до запуска сгенерированных
команд внутри него. Иначе родительское хранилище может перехватить изменения.

Если один подмодуль подключить нельзя, доведите остальные, оставьте этот репозиторий
неподключённым, а не подключённым наполовину, и назовите его в отчёте вместе с
упавшей проверкой и её выводом. Наполовину подключённый репозиторий — единственное
состояние, которое ежедневный поток не замечает.

Добавьте правило границы записи в файл инструкций проекта, который порт читает по
данным этапа 2, — в каждом подключённом репозитории и в хранилище:

```markdown
## ЖЁСТКОЕ ПРАВИЛО — самопроверка
После создания или правки ЛЮБОГО файла в openspec/ или docs/ выполните:
    bash "$(git rev-parse --show-toplevel)/tools/verify-docs.sh"
Исправьте каждый ✗ (в каждой ошибке есть подсказка) и повторяйте до зелёного
результата ДО отчёта о готовности и до предложения коммита. Отклонённую запись
исправляют, переписывая содержимое, — никогда ослаблением лимитов или удалением
проверок.
СТОП-ПРАВИЛО: если та же ошибка держится после 3 попыток, остановитесь и спросите
человека, не зацикливайтесь.
```

Один скрипт держит границу для всех троих: агента после записи, человека на
pre-commit через lefthook и CI как последнюю преграду.

## 6. Установите Corp-команды и навыки

Скопируйте `skills/corp-*` в проектный каталог навыков из этапа 2. Скопируйте
`commands/corp-*.md` в найденный каталог команд. Меняйте только оболочку порта,
frontmatter и токен `{{args}}`, если это требуется.

Замените каждый токен `<openspec>` в установленных копиях подставленным вызовом из
`port-facts.md`. `corp-spec` вызывает `new change` и `instructions` по артефактам,
`corp-plan` — `instructions design` и `instructions tasks`, `corp-implement` —
`instructions apply`, `corp-review` — `validate` и `status`, `corp-archive` — `archive`.

```bash
rg -n '<openspec>' "<installed-command-dir>" && exit 1 || true
```

Если навыки не поддерживаются, вставьте их тела сейчас и докажите отсутствие
недоступных ссылок. Полный процесс устанавливается без Superpowers.

## 7. Подключите проверку в CI

ШАБЛОН — адаптируйте под внутренний CI и проверьте дымовым прогоном, прежде чем на
него полагаться. Каждый репозиторий гоняет ту же проверку, что агент и хук:

```groovy
stage('docs-disposer') { steps { sh 'bash "$(git rev-parse --show-toplevel)/tools/verify-docs.sh"' } }
```

Системное хранилище гоняет сборку каталога ночью и на merge в репозиториях:

```groovy
stage('catalog') {
  steps {
    sh 'bash "$(git rev-parse --show-toplevel)/tools/sync-submodules.sh" --inventory project-repositories.json --store-root "$(git rev-parse --show-toplevel)"'
    sh 'node "$(git rev-parse --show-toplevel)/tools/aggregate-index.mjs" --strict'   // красный репозиторий валит сборку, громко
    sh 'git add catalog.json catalog.md && git diff --cached --quiet || git commit -m "chore(<TICKET>): refresh catalog" && git push'
  }
}
```

Контрактные тесты, проверку совместимости схем и линт миграций держите в отдельных
пайплайнах со своими доступами: у задачи для агента не должно быть их прав.

## 8. Докажите работу хуков и защит

До реального изменения проверьте инструменты на временных плохих данных:

- неверный OpenSpec-корень должен завершиться ошибкой;
- повторённая форма общего контракта должна упасть на split-brain проверке;
- неверная ветка и несовпадающий ticket в коммите должны быть отклонены;
- `git config core.hooksPath` должен быть пустым или указывать на хуки репозитория;
- намеренно неверный временный коммит должен быть отклонён установленным хуком.

Не ослабляйте проверку ради зелёного результата.

## 9. Финальная приёмка

После последнего изменения проверьте синтаксис и повторите синхронизацию:

```bash
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh"
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" status --short --branch
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
```

Также проверьте в каждом подмодуле OpenSpec-корень, базовую ветку, текущее состояние,
хуки, docs-проверки, команды и навыки. Коммитьте хранилище и каждый репозиторий
отдельно. Укажите источник списка (`mcp` или `manual`) и приложите свежий вывод.

Файлы на диске — ещё не работающая установка. Вызовите одну Corp-команду в самом
порту: запустите `corp-spec` на выдуманном тикете в одном подключённом репозитории,
убедитесь, что дело дошло до интервью и появился `openspec/changes/<id>/proposal.md`,
затем удалите ветку и папку изменения. Установка, в которой ни одна команда ни разу
не отработала в реальном порту, не доказана, что бы ни показывал список файлов.

Закрывайте установку, только когда верна каждая строка:

- [ ] хранилище живо: синхронизация и `aggregate-index --strict` зелёные в ночной задаче CI;
- [ ] в каждом подключённом репозитории проверка зелёная в pre-commit и в CI, индекс
      и `repo.txt` закоммичены;
- [ ] команды и навыки установлены, ни одного токена `<openspec>` не осталось;
- [ ] одна Corp-команда отработала целиком в порту;
- [ ] назван чемпион в каждой команде и назван владелец харнесса: за ним закрепления
      версий, задача каталога и повторные проверки порта;
- [ ] записан путь исключения: любую задачу можно вести мимо потока, причина
      фиксируется в трекере.
