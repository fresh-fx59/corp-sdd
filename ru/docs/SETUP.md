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
4. созданные OpenSpec-команды new, continue, apply, verify и archive;
5. названия MCP-инструментов проекта, трекера, wiki и поиска кода;
6. поддержку хуков, предел контекста и версию агента.

Не предполагайте `.qwen/`, slash-команды и имена MCP. Один раз инициализируйте
OpenSpec на временных данных закреплённым внутренним пакетом и изучите созданные
файлы. Запишите точные вызовы:

```text
<opsx-new-command>
<opsx-continue-command>
<opsx-apply-command>
<opsx-verify-command>
<opsx-archive-command>
```

Внешний Superpowers не требуется. Используйте самостоятельные файлы
`skills/corp-*`. Если порт не поддерживает навыки, вставьте тело каждого нужного
навыка в установленную команду и удалите строку `Follow skill ...`.

## 3. Создайте или проверьте соседнее системное хранилище

При первой локальной установке выберите один путь. Если удалённый `system-store`
уже содержит хранилище проекта, клонируйте его утверждённую ветку рядом с `corp-sdd`:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
git clone --branch "<system-store-base-branch>" --single-branch "<system-store-remote-url>" "$CORP_SYSTEM_STORE_ROOT"
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Только если проект явно создаёт новое пустое системное хранилище, начните с
включённого в комплект шаблона:

```bash
test ! -e "$CORP_SYSTEM_STORE_ROOT"
cp -R "$CORP_SDD_ROOT/system-store-template" "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" init -b "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" remote add origin "<system-store-remote-url>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Существующее локальное хранилище не перезаписывайте и не клонируйте поверх него.
Докажите, что это отдельный Git-корень. Затем проверьте ветку и рабочее дерево до
изменения списка репозиториев или установленных файлов:

```bash
test "$(git -C "$CORP_SYSTEM_STORE_ROOT" rev-parse --show-toplevel)" = "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" status --short --branch
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$CORP_SYSTEM_STORE_ROOT" --base "<system-store-base-branch>"
git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch "<system-store-base-branch>"
```

Проверка состояния отклоняет незакоммиченные файлы, stash, detached HEAD,
неопубликованные коммиты, неверный upstream и расхождение веток. Она выполняет
только проверенную перемотку вперёд.

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
   `check-git-naming.sh`;
5. скопируйте `config/lefthook.yml.example` в `lefthook.yml`, установите lefthook
   из разрешённого внутреннего источника и выполните `lefthook install`;
6. создайте стабильный id в `openspec/repo.txt`, сгенерируйте индекс и запустите
   корневой `verify-docs.sh`;
7. объявите хранилище в `openspec/config.yaml` этого репозитория, чтобы спека
   ссылалась на общий контракт, а не повторяла его:

   ```yaml
   references:
     - <store-id>
   ```

   Без этого блока строка `openspec show <spec-id> --type spec --store <store-id>`,
   которую `corp-spec` пишет в каждую межрепозиторную delta, не разрешается, а
   `check-contract-split-brain.mjs` завершается нулём, ничего не проверив: вставленная
   копия контракта пройдёт незамеченной.

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

Замените все OpenSpec-плейсхолдеры в установленных копиях точными вызовами из
`port-facts.md`. `corp-spec` явно вызывает new и continue, `corp-implement` — apply,
`corp-review` — verify, `corp-archive` — archive.

```bash
rg -n '<opsx-(new|continue|apply|verify|archive)-command>' "<installed-command-dir>" && exit 1 || true
```

Если навыки не поддерживаются, вставьте их тела сейчас и докажите отсутствие
недоступных ссылок. Полный процесс устанавливается без Superpowers.

## 7. Подключите проверку в CI

Адаптируйте под используемый self-hosted CI и проверьте дымовым прогоном, прежде
чем на него полагаться. Каждый репозиторий гоняет ту же проверку, что агент и хук:

```bash
bash "$(git rev-parse --show-toplevel)/tools/verify-docs.sh"
```

Системное хранилище гоняет сборку каталога ночью и на merge в репозиториях:

```bash
STORE_ROOT="$(git rev-parse --show-toplevel)"
bash "$STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$STORE_ROOT/project-repositories.json" --store-root "$STORE_ROOT"
node "$STORE_ROOT/tools/aggregate-index.mjs" --strict   # красный репозиторий валит сборку, громко
git add catalog.json catalog.md
git diff --cached --quiet || git commit -m "chore(<TICKET>): refresh catalog" && git push
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
- [ ] команды и навыки установлены, ни одного плейсхолдера `<opsx-*-command>` не осталось;
- [ ] одна Corp-команда отработала целиком в порту;
- [ ] назван чемпион в каждой команде и назван владелец харнесса: за ним закрепления
      версий, задача каталога и повторные проверки порта;
- [ ] записан путь исключения: любую задачу можно вести мимо потока, причина
      фиксируется в трекере.
