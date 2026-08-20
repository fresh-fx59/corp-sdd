# Задача установки для агента

Выполните эти этапы после получения или обновления `corp-sdd`. Останавливайтесь
при любой ошибке. Сохраняйте команды и вывод в отчёте проекта. Во время установки
не удаляйте и не переписывайте существующие репозитории, ветки и локальную работу.

## 0. Входные данные и устойчивые пути

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
   корневой `verify-docs.sh`.

Создайте собственный OpenSpec-корень каждого подмодуля до запуска сгенерированных
команд внутри него. Иначе родительское хранилище может перехватить изменения.

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

## 7. Докажите работу хуков и защит

До реального изменения проверьте инструменты на временных плохих данных:

- неверный OpenSpec-корень должен завершиться ошибкой;
- повторённая форма общего контракта должна упасть на split-brain проверке;
- неверная ветка и несовпадающий ticket в коммите должны быть отклонены;
- `git config core.hooksPath` должен быть пустым или указывать на хуки репозитория;
- намеренно неверный временный коммит должен быть отклонён установленным хуком.

Не ослабляйте проверку ради зелёного результата.

## 8. Финальная приёмка

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
