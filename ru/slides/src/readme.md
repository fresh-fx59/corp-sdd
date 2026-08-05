---
title: SDD decks — source & rebuild
type: reference
status: active
created: 2026-07-22
updated: 2026-07-22
tags: [sdd, presentation, content, enterprise-sdd-agents]
links: []
---

# SDD-презентации — исходник

Воспроизводимый исходник русской HTML-презентации `../deck-ru-talk5.html`
(доклад о решении на 5 минут). Управляется данными: **один движок, контент в JSON.**

> Презентации `deck-ru-leadership.html` (18 сл.) и `deck-ru-team.html` (21 сл.) **удалены
> 2026-08-05**: собраны 2026-07-23 и не содержали ни одного изменения от 2026-08-04/05.
> Устаревшая презентация, которая лежит на месте, рано или поздно будет показана.
> При необходимости восстанавливается из истории git; контент собирать заново из
> `docs/2026-08-05-corp-sdd-solution-handoff.md`, а не из старого JSON.

## Файлы
- `deck-template.html` — движок: дизайн-система CSS (два акцента, светлая+тёмная темы),
  data-driven рендерер (12 макетов слайдов), навигация с клавиатуры, прогресс, авто-подгонка высоты,
  печать в PDF. Плейсхолдеры: `/*__TOKENS_CSS__*/`, `/*__META_JSON__*/`, `/*__SLIDES_JSON__*/`.
- `build-decks.mjs` — инжектит цветовые токены каждой презентации + JSON слайдов в шаблон; выдаёт
  автономный `.html` (с `<head>`) **и** `.artifact.html` (только body, для публикатора
  Artifact) в `dist/`.
- `content/leadership.json`, `content/team.json` — контент слайдов (один массив на презентацию).
  **Это поверхность редактирования** — меняйте формулировки здесь, а не в собранном HTML.

## Пересборка
```
node build-decks.mjs talk5                # -> dist/deck-ru-talk5.html (+ .artifact.html)
cp dist/deck-ru-talk5.html ../deck-ru-talk5.html
```
Чтобы переопубликовать Artifact на месте, переопубликуйте соответствующий `dist/*.artifact.html` с
существующим URL Artifact (см. `../index.md`).

## Макеты (поле `layout` каждого слайда)
`title · bullets · statement · two-col · cards · stack · fanout · pipeline · timeline · table · map · closing`
См. блок комментария со схемой у начала рендерера в `deck-template.html`.

## Происхождение
Контент написан и состязательно проверен субагентами Opus (контент → проверка → правка)
строго на основе `docs/superpowers/specs/2026-07-17-corp-sdd-transition-design.md` и
`docs/superpowers/plans/2026-07-18-corp-sdd-team-playbook.md`. Сгенерировано 2026-07-22.
