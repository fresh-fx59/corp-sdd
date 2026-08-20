---
description: Структурированное предварительное ревью diff до ревью человеком
---
Проверь diff {{args}}. Следуй corp-code-review. Дай findings по важности
(blocker / serious / minor), каждый с file:line и конкретным исправлением.
0. СОСТОЯНИЕ: установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`, выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. Для локальной ветки истории
   также выполни `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
1. ПОКРЫТИЕ: сначала `<opsx-verify-command> <change-id>` с настроенным store option.
   Незакрытая задача или CRITICAL — blocker; непокрытый сценарий — минимум serious.
   Наличие теста не доказывает его запуск. Если это не OpenSpec-изменение, отметь это.
2. СООТВЕТСТВИЕ СПЕКЕ: реализовано ровно требуемое, без пропусков и лишнего.
3. ЧЕСТНОСТЬ ТЕСТОВ: тест проверяет поведение сценария и упал бы при поломке функции.
4. КОРРЕКТНОСТЬ: ошибки, границы сценариев, error handling, конкуренция общего состояния.
5. DISPOSER: `bash "$REPO_ROOT/tools/verify-docs.sh"`; любая ошибка — blocker.
Не approve и не merge. Решение принимает человек. Если diff чистый, скажи одной строкой.
