# Задача обновления для агента

Используйте эту инструкцию, когда рабочая копия уже существует — `corp-sdd`,
соседнее системное хранилище и N подключённых подмодулей — и вы переводите её со
старой редакции комплекта на текущую. Первая установка описана в
`docs/SETUP.md`; этот файл её не заменяет.

Останавливайтесь при любой ошибке. Сохраняйте команды и вывод в отчёте проекта.
Во время обновления не удаляйте и не переписывайте существующие репозитории,
ветки и локальную работу. Обновление меняет *файлы инструментов, команд и
навыков*. Оно не трогает содержимое проекта.

## 0. Снимите картину до первого изменения

Определите те же устойчивые пути, что и при установке. Выполните это в корне
нового распакованного `corp-sdd`:

```bash
export CORP_SDD_ROOT="$(git rev-parse --show-toplevel)"
export CORP_WORKSPACE_ROOT="$(cd "$CORP_SDD_ROOT/.." && pwd -P)"
export CORP_SYSTEM_STORE_ROOT="${CORP_SYSTEM_STORE_ROOT:-$CORP_WORKSPACE_ROOT/system-store}"
export KV="$CORP_SDD_ROOT/scripts/tools/kit-version.sh"
test -d "$CORP_SYSTEM_STORE_ROOT/.git" || test -f "$CORP_SYSTEM_STORE_ROOT/.git"
test "$CORP_SYSTEM_STORE_ROOT" != "$CORP_SDD_ROOT"
```

Назовите обе редакции — устанавливаемую и уже лежащую на диске:

```bash
bash "$KV" show      # редакция этого комплекта
bash "$KV" verify    # файлы комплекта — это байты той редакции
bash "$KV" list      # все файлы с метками
```

`verify` должен быть зелёным до первого копирования. Комплект, не проходящий
собственный манифест, — не релиз; распакуйте его заново.

Теперь классифицируйте каждую **установленную** копию. `identify` считает хеш
указанного файла, поэтому работает по любому пути, включая каталог команд в
домашней папке агента:

```bash
# инструменты хранилища
bash "$KV" identify "$CORP_SYSTEM_STORE_ROOT"/tools/* || true
# инструменты каждого подмодуля
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do bash "$KV" identify "$repo"/tools/* || true; done
# установленные команды и навыки по путям из port-facts.md
bash "$KV" identify "<installed-command-dir>"/corp-*.md || true
bash "$KV" identify "<installed-skill-dir>"/corp-*/SKILL.md || true
```

Каждая строка — один из трёх вердиктов:

| Вердикт | Значение | Что делает обновление |
|---|---|---|
| `pristine <редакция>` | нетронутый файл комплекта той редакции | заменяет молча |
| `MODIFIED` | метка есть, а байты другие — файл правили | **стоп**, этап 5 |
| `UNSTAMPED` | копия старше версионирования или своя | как MODIFIED, этап 5 |

Запишите полную опись из трёх групп в отчёт **до** первого копирования. После
обновления её уже не восстановить: заменённый файл выглядит ровно так же, как
файл, который и без того был актуальным.

## 1. Каждый репозиторий чист и на базовой ветке

Обновление пишет в хранилище и в каждый подмодуль. Это отдельные Git-репозитории,
каждый коммитится отдельно, поэтому и проверяется каждый отдельно, до любого
копирования:

```bash
bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base \
  --repo "$CORP_SYSTEM_STORE_ROOT" --base "$(git -C "$CORP_SYSTEM_STORE_ROOT" config corp.baseBranch)"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do
      bash "$CORP_SDD_ROOT/scripts/tools/repository-state.sh" prepare-base --repo "$repo"
    done
```

Проверка состояния отклоняет грязное дерево, detached HEAD, неотправленные коммиты
на самой базовой ветке, чужой upstream и расхождение. Она делает только проверенный
fast-forward. Про stash и коммиты на других локальных ветках она сообщает, но не
блокирует работу и ничего не трогает.
Разбирайте каждую остановку с владельцем этой работы — не обходите её. Репозиторий,
который не прошёл проверку, пропускается целиком и называется в отчёте: обновлённый
наполовину репозиторий — единственное состояние, которое ежедневный поток не
замечает.

Не заводите одну общую ветку обновления на все репозитории. У каждого свой коммит
на своей базе, чтобы каждый откатывался отдельно (этап 9).

## 2. Перепроверяйте порт, только если он изменился

Пропустите этот этап, если с момента записи `port-facts.md` не менялись версия CLI
агента, его каталог команд или навыков и закреплённая версия OpenSpec. Если
что-то из этого изменилось, повторите этап 2 установки полностью на реальном порту
— не правьте записанные вызовы руками — и один раз докажите новую версию:

```bash
npx @fission-ai/openspec@<закреплённая-версия> --version
```

Обновите копию фактов в хранилище, сохранив записанные идентификаторы:

```bash
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- port-facts.md
```

`<store-id>` и id репозиториев — это контракт, а не подпись. Обновление никогда их
не переименовывает: межрепозиторные ссылки ищут по id и молча перестанут
разрешаться.

## 3. Обновите инструменты самого системного хранилища

Это тот этап, которого не было в старой заметке об обновлении, и единственное
место, где ставятся `tools/` хранилища. Пропустив его, вы оставите хранилище на
прежних `sync-submodules.sh`, `repository-state.sh` и `aggregate-index.mjs`, тогда
как все остальные файлы уже новые:

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
install -m 0644 "$CORP_SDD_ROOT/templates/conventions-branching.md" "$CORP_SYSTEM_STORE_ROOT/conventions/branching.md"
```

`port-facts.md` в этом списке **нет**. В нём факты конкретной установки, а не
содержимое комплекта; им владеет этап 2. Пустой шаблон поверх него сотрёт данные
порта, из которых были подставлены вызовы в установленных командах.

Докажите копирование, коммит оставьте этапу 8:

```bash
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh"
bash -n "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"
bash "$KV" identify "$CORP_SYSTEM_STORE_ROOT"/tools/*.sh "$CORP_SYSTEM_STORE_ROOT"/tools/*.mjs
git -C "$CORP_SYSTEM_STORE_ROOT" status --short
```

Каждая строка с меткой теперь должна быть `pristine <новая редакция>`.

## 4. Обновите инструменты в каждом подмодуле

В каждом подключённом репозитории лежат семь инструментов из этапа 5 установки,
пункт 4. Копируйте их из только что обновлённого `tools/` хранилища, по одному
репозиторию за раз, пропуская те, что не прошли проверку на этапе 1:

```bash
git -C "$CORP_SYSTEM_STORE_ROOT" submodule foreach --quiet 'echo "$toplevel/$sm_path"' \
  | while IFS= read -r repo; do
      test -d "$repo/tools" || continue
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/repository-state.sh"        "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/verify-docs.sh"             "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/check-openspec-root.sh"     "$repo/tools/"
      install -m 0755 "$CORP_SYSTEM_STORE_ROOT/tools/check-git-naming.sh"        "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/corp-lint.mjs"              "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/gen-index.mjs"              "$repo/tools/"
      install -m 0644 "$CORP_SYSTEM_STORE_ROOT/tools/check-contract-split-brain.mjs" "$repo/tools/"
      bash -n "$repo/tools/verify-docs.sh"
      bash "$repo/tools/verify-docs.sh"
    done
```

`aggregate-index.mjs`, `index-all.sh` и `sync-submodules.sh` живут только в
хранилище. Репозиторий, который их заводит, начинает вести второй список
репозиториев.

Если в репозитории `verify-docs.sh` покраснел на содержимом, которое раньше было
зелёным, значит новая проверка ужесточила лимит. Перепишите содержимое. Не
ослабляйте лимит и не удаляйте проверку ради завершения обновления.

## 5. Команды, навыки и обязательная подстановка плейсхолдеров

Скопируйте `skills/corp-*` в проектный каталог навыков из `port-facts.md`, а
`commands/corp-*.md` — в записанный каталог команд. Меняйте только оболочку порта,
frontmatter и токен `{{args}}`, ровно как при установке.

Свежий файл команды приходит с **неподставленным** токеном. Копирование отменяет
подстановку, сделанную при установке, поэтому повторная подстановка обязательна:
замените каждый токен `<openspec>` подставленным вызовом CLI из `port-facts.md`.
`corp-spec` вызывает `new change` и `instructions` по артефактам, `corp-plan` —
`instructions design` и `instructions tasks`, `corp-implement` — `instructions apply`,
`corp-review` — `validate` и `status`, `corp-archive` — `archive`.

```bash
rg -n '<openspec>' "<installed-command-dir>" && exit 1 || true
```

Это и есть проверка: непустой вывод означает, что обновление оставило команду,
которая не запустится. Если порт не поддерживает навыки, снова вставьте их тела и
докажите отсутствие недоступных ссылок.

## 6. Файлы MODIFIED и UNSTAMPED: решайте, а не перезаписывайте

Список составлен на этапе 0. Для каждого такого файла остановите копирование
именно его и:

1. сравните установленную копию с копией из комплекта по тому же пути:

   ```bash
   diff -u "<installed-file>" "$CORP_SDD_ROOT/<kit-path-from-identify>"
   ```

   Для нетронутого файла `identify` печатает путь в комплекте; для MODIFIED
   возьмите тот же относительный путь внутри `$CORP_SDD_ROOT`.
2. решите **оставить** или **заменить** вместе с названным человеком — владельцем
   харнесса либо автором локальной правки, если Git его называет:

   ```bash
   git -C "<repo>" log -1 --format='%an %ae %cI' -- "<path-relative-to-repo>"
   ```
3. запишите решение в отчёт: файл, обе редакции, кто решил и почему. Оставленная
   правка — это постоянная развилка по этому файлу: скажите об этом прямо и
   заведите запрос на изменение комплекта, чтобы следующее обновление не решало
   тот же вопрос заново.

Молчаливая перезапись — ровно тот сбой, ради которого существует этот этап:
осознанно добавленная защита или обёртка под порт исчезает, и ежедневный поток
об этом не сообщает.

## 7. Чего обновление не трогает никогда

Это содержимое проекта и идентичность установки, а не файлы комплекта. Оставьте
их как есть:

- `project-repositories.json` — список репозиториев. Обновление привязок — это
  отдельная операция (`docs/OPERATIONS.md`, «Обновление привязок проекта»).
- `.gitmodules` и содержимое подмодулей — обновление не добавляет репозиториев и
  не двигает указатели.
- `openspec/` в хранилище и в каждом репозитории — контракты, ADR, изменения,
  архив, `repo.txt`, `config.yaml`.
- `port-facts.md`, кроме как через этап 2.
- Собственные файлы проекта в `tools/`, которых комплект не поставляет.

Никогда не повторяйте копирование `system-store-template` и никогда не запускайте
`git init` в хранилище. Оба действия — только для первой установки. На живом
хранилище они создают вторую, не связанную историю, и это стоит не повтора, а
переделки.

## 8. Заново докажите защиты и выполните одну реальную команду

Новые байты инструментов означают, что защиты снова не доказаны. Повторите этап 8
установки на временных плохих данных — в хранилище и в одном показательном
репозитории:

- неверный OpenSpec-корень должен завершиться ошибкой;
- повторённая форма общего контракта должна упасть на split-brain проверке;
- неверная ветка и несовпадающий ticket в коммите должны быть отклонены;
- `git config core.hooksPath` должен быть пустым или указывать на хуки репозитория;
- намеренно неверный временный коммит должен быть отклонён установленным хуком.

Выполните `lefthook install` заново в каждом репозитории, где изменился
`lefthook.yml`. Затем докажите повторяемость и работу каталога:

```bash
bash "$CORP_SYSTEM_STORE_ROOT/tools/sync-submodules.sh" \
  --inventory "$CORP_SYSTEM_STORE_ROOT/project-repositories.json" \
  --store-root "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" diff -- .gitmodules   # должно быть пусто
node "$CORP_SYSTEM_STORE_ROOT/tools/aggregate-index.mjs" --strict "$CORP_SYSTEM_STORE_ROOT"
git -C "$CORP_SYSTEM_STORE_ROOT" submodule status
```

Файлы на диске — ещё не выполненное обновление. Вызовите одну Corp-команду в самом
порту: запустите `corp-spec` на выдуманном тикете в одном подключённом
репозитории, убедитесь, что дело дошло до интервью и появился
`openspec/changes/<id>/proposal.md`, затем удалите ветку и папку изменения.
Обновление, в котором ни одна команда ни разу не отработала в реальном порту, не
доказано, что бы ни печатал `identify`.

Коммитьте каждый репозиторий отдельно, по одному коммиту, только скопированные
файлы:

```bash
git -C "<repo>" add tools/ && git -C "<repo>" commit -m "chore(<TICKET>): corp-sdd tools -> <new edition>"
```

То же сделайте в хранилище и там, где порт держит установленные команды и навыки
под контролем версий.

## 9. Откат

Копирование в каждом репозитории — ровно один коммит, поэтому откат это один
revert на репозиторий и ничего больше:

```bash
git -C "<repo>" revert --no-edit <upgrade-commit>
bash "<repo>/tools/verify-docs.sh"
```

Хранилище и репозитории откатываются независимо и в любом порядке: инструменты не
читают друг друга. Откат хранилища не меняет указатель подмодуля, потому что этап 4
коммитил внутри подмодуля, а не в хранилище.

Откат команд и навыков — это установка `commands/` и `skills/` предыдущего
комплекта и повторная подстановка плейсхолдеров этапа 5. Каталог порта обычно не
Git-репозиторий, поэтому держите предыдущий комплект распакованным, пока приёмка
не станет зелёной.

Ничего из этапов 3–5 не трогает содержимое проекта, поэтому откат не теряет ни
спеку, ни изменение, ни указатель подмодуля.

## Приёмка

Закрывайте обновление, только когда верна каждая строка:

- [ ] опись pristine / MODIFIED / UNSTAMPED, снятая до обновления, лежит в отчёте;
- [ ] `kit-version.sh verify` на новом комплекте зелёный до любого копирования;
- [ ] каждый репозиторий проверен через `prepare-base` до копирования; пропущенные
      названы вместе с упавшей проверкой и её выводом;
- [ ] `tools/` хранилища и `tools/` каждого репозитория дают `identify` со статусом
      pristine новой редакции;
- [ ] по каждому файлу MODIFIED или UNSTAMPED записано решение «оставить или
      заменить» и назван тот, кто его принял;
- [ ] команды и навыки переустановлены, `rg` доказывает, что плейсхолдеров
      `<openspec>` не осталось;
- [ ] `port-facts.md`, `project-repositories.json`, `.gitmodules` и все деревья
      `openspec/` обновлением не изменены;
- [ ] негативные тесты этапа 8 установки повторены и красные там, где должны быть;
- [ ] `sync-submodules.sh` отработал чисто, `aggregate-index --strict` зелёный;
- [ ] одна Corp-команда отработала целиком в порту после обновления;
- [ ] по одному коммиту на репозиторий, каждый откатывается сам по себе, SHA
      записаны в отчёте.
