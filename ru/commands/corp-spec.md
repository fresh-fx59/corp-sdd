---
description: Создать delta spec истории; при необходимости разнести её по репозиториям
version: 1.0.0
---
Ты готовишь спеку для истории {{args}}. Следуй corp-drill-down и corp-verification.

1. ПРОЧИТАЙ И ПРОВЕДИ ОДНО ИНТЕРВЬЮ. Получи историю, wiki и вложения через
   настроенную интеграцию. Если её нет, используй предоставленный экспорт и пометь
   недостающие доказательства. В каждом выбранном репозитории установи
   `REPO_ROOT="$(git rev-parse --show-toplevel)"` и выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect`. Прочитай только нужные
   живые спеки и проверь каждый факт контракта по коду. Задавай аналитику по одному
   вопросу, пока требования и Given/When/Then не станут однозначными. Для нескольких
   репозиториев интервью всё равно одно.

2. ОПРЕДЕЛИ ФОРМУ И ПОДТВЕРДИ ДО ИЗМЕНЕНИЙ. Один репозиторий — шаг 3. Несколько
   репозиториев без общей формы или протокола — это независимые истории, остановись.
   При общем контракте — шаг 4. До создания ticket, ветки, коммита или PR покажи
   аналитику репозитории, producer, существующие и новые tickets, число PR и дождись
   подтверждения. Не делай fan-out молча.

3. ОДИН РЕПОЗИТОРИЙ. Выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`; при ошибке остановись.
   Создай `feature/<TICKET>` от настроенной базы, опубликуй upstream и выполни
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET>`.
   Запусти `<opsx-new-command> <change-id>`, затем
   `<opsx-continue-command> <change-id>` до появления `proposal.md` и delta `spec.md`.
   Остановись до design и tasks. В research.md сохраняй только указатели path#Lx-Ly
   и краткий вывод. Выполни `bash "$REPO_ROOT/tools/verify-docs.sh"` до зелёного.
   Закоммить change folder, отправь ветку, открой или обнови spec PR и верни ссылку
   в историю. Аналитик не выполняет Git-операции.

4. НЕСКОЛЬКО РЕПОЗИТОРИЕВ — СНАЧАЛА TICKETS. Используй существующие дочерние
   tickets родительской истории и однозначно сопоставь каждый репозиторию. При
   пробеле остановись и спроси аналитика. Если дочерних tickets нет, уточни, кто
   создаёт по одному на репозиторий. Родительская история — ticket контракта
   хранилища; отдельный child для неё не нужен.

5. СНАЧАЛА КОНТРАКТ. В SYSTEM STORE установи
   `STORE_ROOT="$(git rev-parse --show-toplevel)"` и выполни
   `bash "$STORE_ROOT/tools/repository-state.sh" prepare-base`. Создай и опубликуй
   `feature/<parent-ticket>`, затем выполни
   `bash "$STORE_ROOT/tools/repository-state.sh" assert-change <parent-ticket>`.
   Выполни `<opsx-new-command> <contract-change-id>`, затем
   `<opsx-continue-command> <contract-change-id>` до proposal и contract delta.
   Используй `store-contract.md`; форма живёт только здесь. Выполни
   `bash "$STORE_ROOT/tools/verify-docs.sh"`, закоммить, отправь, открой PR и верни
   ссылку в parent.

6. ДЛЯ КАЖДОГО РЕПОЗИТОРИЯ:
   a. Установи `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Выполни
      `bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`, создай и опубликуй
      `feature/<child-ticket>`, затем выполни
      `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <child-ticket>`.
   b. Выполни `<opsx-new-command> <change-id>` и
      `<opsx-continue-command> <change-id>` до proposal и собственной delta spec.
      Она ссылается на контракт по spec id и store id, но не повторяет форму. Добавь:
      `openspec show <contract-spec-id> --type spec --store <store-id>`.
      В research.md сохраняй указатели. Не создавай design.md и tasks.md.
   c. Выполни `bash "$REPO_ROOT/tools/verify-docs.sh"`. При split-brain ошибке удали повтор формы
      и оставь ссылку.
   d. Коммит `feat(<child-ticket>): <text>`, push, PR и ссылка в ticket.

7. В каждом child зафиксируй порядок: согласовать контракт первым; реализовать
   producer первым; merge producer → consumers → контракт последним. Изменение
   контракта останавливает все репозитории. Child блокируется parent.

8. В parent опубликуй карту ticket → репозиторий → роль и окно merge.

9. До отчёта проверь: каждый child связан и сопоставлен; у каждого репозитория есть
   ветка, отправленный коммит и открытый PR; verify-docs зелёный. Приложи доказательства.
