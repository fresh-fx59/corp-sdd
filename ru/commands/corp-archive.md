---
description: Закрытие после merge — перенос delta в живые спеки, ADR и индекс
version: 1.0.0
---
Архивируй изменение {{args}}. Следуй навыку corp-verification.
Установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Выполни
`bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`; при ошибке остановись.
Условие: PR изменения смержен, текущая ветка — подготовленная настроенная база.
Не предполагай, что она называется `main`, `master` или `develop`.
1. Выполни `<opsx-archive-command> {{args}}`. Delta перейдёт в `openspec/specs/`.
2. По решениям proposal, research.md и поправкам спеки создай ADR через
   `templates/adr.md` в `openspec/adr/NNNN-<slug>.md`. Принятые ADR не изменяй.
3. Пересобери индекс: `node "$REPO_ROOT/tools/gen-index.mjs"`.
4. Выполни `bash "$REPO_ROOT/tools/verify-docs.sh"`; результат должен быть зелёным.
5. Коммит: `chore(<TICKET>): archive {{args}} living spec and ADR`. Отправь его.
   Каталог хранилища обновится при следующей агрегации; не правь его вручную.
6. Отправь короткую запись через настроенную интеграцию трекера. Если её нет,
   выведи готовый текст для ручной вставки.
