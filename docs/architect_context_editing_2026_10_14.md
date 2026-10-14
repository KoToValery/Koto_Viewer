# Architect: размери, контекст и свързани стени

## Размери и задържане — завършено

Finished-face clearance geometry вече работеше за всички ориентации. Label се
скриваше, когато midpoint е извън viewport. Етикетът вече използва видимата част
на размерния сегмент, без да променя измерената стойност. Позиционирането при
обход на wall obstacles е ограничено до видимия чертеж. Избор от Pan също може
да показва wall clearance.

Кратък hold (280 ms) избира елемент; дълъг stationary hold (700 ms) отваря
контекст. Drag, втори пръст, tool/floor change, scroll и cancel отменят context
timer. Opening на меню отменя pending native preview, без commit/Undo.

Fan използва пълен полукръг и spacing поне 60 px между центровете на 52 px
targets. Цялото меню се измества във viewport вместо индивидуално clamping,
който събираше командите. При тесен/нисък viewport има rows fallback.

Проверки: 349 успешни Architect/shared BIM/Construction interaction теста;
още 7 viewport cancellation сценария. Чист статичен анализ.

## Свързани стени — завършено

Pointer и numeric движения използват същата операция с разрешено extension на
attached supports. Returns и T endpoints следват новото положение на свързаната
стена; shared unselected junctions се пренасят веднъж. Другите краища остават
фиксирани, detached walls остават независими. Вратите/прозорците в удължаваните
стени пазят физическите си места, IDs и styles; в преместената стена се местят с
нея. Ако скъсяване изведе отвор извън host, цялата операция се отхвърля атомарно.
Pure translation пази ratios точно, без floating-point re-projection.

Проверки: 114 успешни теста; три wall orientations, outward pull отвъд старите
краища, T returns, detached cut parts, preview/cancel/commit, hosted identity,
invalid shortening и single Undo/Redo. Чист статичен анализ.

## Нова точка — завършено

Общ BimEditAction.newPoint и localized BG/EN labels/hints/tooltips. Контекстът
показва командата за стени, греди, CAD линии/правоъгълници, плочи, зони и отвори.
Профили, кръгове, оси, врати/прозорци и annotations нямат произволни междинни
редактируеми vertices и не получават неподдържана команда.

BimLineGeometry.insertion намира най-близката проекция върху open/closed path.
UI използва общата input precision и capture band. Native command запазва ID,
свойства, winding и площ на contour; добавеният collinear vertex остава за
следваща редакция. Греда/CAD линия се разделя на два native сегмента със запазени
размери и стилове. Opening boundary използва същия polygon editor и painter.

При стена New point разделя на свързани сегменти (connectEnd/connectStart=true).
Hosted openings се прехвърлят с правилни parent IDs/ratios, без загуба на styles.
Split/„Срежи“ използва cutting stroke и прекъсва връзката. Това разграничение е
в localized tooltip. Невалидна точка, endpoint или split през отвор не добавя
Undo. Pending insertion има Cancel и се отменя при смяна на tool/floor.
Zone editing cache се синхронизира при commit/Undo, за да не рисува стар contour.

Проверки: 17 нови native/property/interaction сценария, включително BG phone с
осем context targets, всички седем tool families, cancel, invalid point и Undo.
Финална серия: 99 BIM тестови файла, 846 успешни теста и 2 предварително пропуснати
external CAD scenarios. В първия разширен run имаше transient pumpAndSettle timeout
в floor-control I/O тест; той мина изолирано и в последващия пълен run. Чист
статичен анализ и git diff --check. Логове: build/architect_context_all_verified.log
и build/architect_context_all_analyze.log.

Големите корекции са качени поотделно в origin/main: 590c83f (размери/hold/fan),
03ff66c (connected stretching) и финалният New point commit.
