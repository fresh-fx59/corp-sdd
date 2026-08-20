---
description: Создать design и tasks утверждённого изменения по текущему коду
---
Спланируй {{args}}. Следуй corp-drill-down и corp-verification.
Условие: proposal и delta spec существуют и утверждены. Иначе остановись и назови пробел.
0. Установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET>`.
   Затем выполняй `<opsx-continue-command> {{args}}` до появления design и tasks.
   Не переходи к реализации.
1. Прочитай delta spec, research.md, изменяемые живые спеки и текущий код модулей.
2. Напиши design.md: подход, файлы и классы, точки интеграции и риски. Не более 200 строк.
3. Напиши tasks.md. Первая строка — состояние и следующая задача. Каждая задача — один
   проверяемый red-green цикл со сценарием, тестом и областью кода. Рискованное — первым.
4. Выполни `bash "$REPO_ROOT/tools/verify-docs.sh"`; исправь всё до зелёного.
5. Представь план разработчику. Не начинай реализацию.
