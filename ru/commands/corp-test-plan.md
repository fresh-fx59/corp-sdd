---
description: Превратить сценарии утверждённой delta spec в ручной test plan
---
Создай ручной test plan для {{args}}.
0. Установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. Для локальной ветки истории
   также выполни `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET> --allow-dirty`.
1. Прочитай сценарии delta spec и изменяемые разделы живой спеки.
2. На сценарий создай пункт: условия, данные, роль, состояние, шаги, результат, requirement ID.
   Для MODIFIED-требований добавь regression-пункты.
3. Добавь «что исследовать»: переходы состояний, права, concurrency, пустые и переполненные входы.
4. Отправь checklist через интеграцию трекера. Если её нет, выведи готовый текст.
   Не отмечай проверки пройденными; дополнения тестировщика имеют приоритет.
