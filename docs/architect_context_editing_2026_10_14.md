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

## Нова точка

Следва: обща контекстна команда за приложимите контури и стени. При стена
точката дели геометрията на свързани сегменти; „Срежи“ остава отделна операция
за прекъсване с cutting stroke.
