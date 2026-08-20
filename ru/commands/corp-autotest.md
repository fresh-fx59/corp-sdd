---
description: Создать каркасы автотестов по сценариям утверждённой delta spec
---
Создай каркасы автотестов для {{args}} в командном фреймворке. Если он неизвестен, уточни.
0. Установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
   Остановись при неверной ветке истории или расхождении.
1. Один тест на сценарий, названный по нему и проверяющий поведение Given/When/Then,
   а не внутренние вызовы или private state.
2. Не выдумывай fixtures. Пометь данные и окружение как `TODO(<что нужно>)`.
3. Не читай и не меняй закрытые gate suites и их credentials. При такой задаче остановись.
4. Запусти всё доступное и приложи вывод. Незапускаемые каркасы пометь как drafts.
5. После записи OpenSpec или docs выполни `bash "$REPO_ROOT/tools/verify-docs.sh"`.
