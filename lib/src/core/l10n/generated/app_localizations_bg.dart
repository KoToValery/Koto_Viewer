// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'KoToViewer';

  @override
  String get language => 'Език';

  @override
  String get selectLanguage => 'Избор на език';

  @override
  String get systemDefault => 'Системен по подразбиране';

  @override
  String get cancel => 'Отказ';

  @override
  String get close => 'Затвори';

  @override
  String get ok => 'ОК';

  @override
  String get save => 'Запази';

  @override
  String get search => 'Търсене';

  @override
  String get share => 'Сподели';

  @override
  String get copy => 'Копирай';

  @override
  String get copied => 'Копирано';

  @override
  String get clear => 'Изчисти';

  @override
  String get error => 'Грешка';

  @override
  String get toggleTheme => 'Смяна на тема';

  @override
  String get about => 'Относно';

  @override
  String get supportDeveloper => 'Подкрепи разработчика';

  @override
  String get coordinateSettings => 'Координатни системи';

  @override
  String get homeBannerTitle => 'Отвори чертежи, 3D модели и документи';

  @override
  String get browseFiles => 'Преглед на файлове';

  @override
  String get recentFiles => 'Скорошни';

  @override
  String get customFolder => 'Папка';

  @override
  String get addFolder => 'Добави папка';

  @override
  String get noFilesFound => 'Няма намерени файлове';

  @override
  String get searchFilesHint => 'Търсене на файлове...';

  @override
  String get sortBy => 'Сортиране по';

  @override
  String get sortByDate => 'Дата на промяна';

  @override
  String get sortByName => 'Име на файл';

  @override
  String get categories => 'Категории';

  @override
  String get categoryAll => 'Всички';

  @override
  String get categoryCad2d => '2D CAD';

  @override
  String get categoryCad3d => '3D Модели';

  @override
  String get categoryPcb => 'PCB Платки';

  @override
  String get categoryRoutes => 'Маршрути';

  @override
  String get recentlyOpenedSubtitle => 'Последно отваряни файлове';

  @override
  String get categoryDocuments => 'Документи';

  @override
  String get categoryMedical => 'Медицински (DICOM)';

  @override
  String get categoryImages => 'Снимки';

  @override
  String get categoryVideo => 'Видео';

  @override
  String get loadingFile => 'Зареждане на файл...';

  @override
  String get loadingPdf => 'Зареждане на PDF документ...';

  @override
  String get loadingPresentation => 'Зареждане на презентация...';

  @override
  String get loadingCad => 'Зареждане на CAD чертеж...';

  @override
  String get convertingDwg => 'Конвертиране и зареждане на DWG...';

  @override
  String get loadingWordDoc => 'Зареждане на Word документ...';

  @override
  String get loadingSpreadsheet => 'Зареждане на електронна таблица...';

  @override
  String get loading3dModel => 'Зареждане на 3D модел...';

  @override
  String get loadingEbook => 'Зареждане на електронна книга...';

  @override
  String get loadingEbookFb2 => 'Зареждане на книга (FB2)...';

  @override
  String get loadingComic => 'Зареждане на комикс...';

  @override
  String get loadingDicom => 'Зареждане на DICOM изследване...';

  @override
  String get statusPreparingPages => 'Подготовка и анализ на страниците...';

  @override
  String get statusScanningSeries =>
      'Сканиране на серии, срезове и метаданни...';

  @override
  String get statusTriangulatingMesh =>
      'Триангулация и изграждане на полигонална мрежа...';

  @override
  String get statusIndexingWorksheet =>
      'Индексиране на работни листове, клетки и формули...';

  @override
  String get statusDecodingEbook =>
      'Декодиране на текст, глави и съдържание...';

  @override
  String get statusAnalyzingCad =>
      'Анализиране на CAD слоеве, блокове и геометрия...';

  @override
  String get statusParsingWord =>
      'Парсиране на страници, форматиране и таблици...';

  @override
  String get statusOpeningFile => 'Отваряне на файл...';

  @override
  String get statusExtractingStructure => 'Разархивиране на структурата...';

  @override
  String statusExtractingPage(int current, int total) {
    return 'Разархивиране на страница $current от $total...';
  }

  @override
  String get statusFinalizingPages => 'Финализиране на страниците...';

  @override
  String get statusIndexingPages => 'Индексиране на страниците...';

  @override
  String statusReadingFile(String sizeMb) {
    return 'Четене на файл ($sizeMb MB)...';
  }

  @override
  String get fitWidth => 'По ширината';

  @override
  String get fitPage => 'Цяла страница';

  @override
  String get fitHeight => 'По височината';

  @override
  String get jumpToPage => 'Към страница';

  @override
  String get firstPage => 'Първа страница';

  @override
  String get lastPage => 'Последна страница';

  @override
  String get previousPage => 'Предишна страница';

  @override
  String get nextPage => 'Следваща страница';

  @override
  String pageIndicator(int current, int total) {
    return 'Страница $current от $total';
  }

  @override
  String enterPageNumber(int total) {
    return 'Въведете номер на страница (1 - $total)';
  }

  @override
  String get zoomIn => 'Увеличи';

  @override
  String get zoomOut => 'Намали';

  @override
  String get resetZoom => 'Възстанови мащаба';

  @override
  String get rotate => 'Завърти';

  @override
  String get reflowMode => 'Режим на четене (Reflow)';

  @override
  String get outline => 'Съдържание';

  @override
  String get thumbnails => 'Миниатюри';

  @override
  String get layers => 'Слоеве';

  @override
  String get displaySettings => 'Настройки на изгледа';

  @override
  String get coordinateSystem => 'Координатна система';

  @override
  String get exportDxf => 'Експорт в DXF';

  @override
  String get measure => 'Измерване';

  @override
  String get annotations => 'Анотации';

  @override
  String get wireframe => 'Каркасен модел (Wireframe)';

  @override
  String get shaded => 'Оцветен модел (Shaded)';

  @override
  String get resetView => 'Възстанови изгледа';

  @override
  String get rasterPreview => 'Вграден преглед (Растерен)';

  @override
  String get previewOnly => 'Само преглед';

  @override
  String get encoding => 'Кодировка';

  @override
  String get wrapLines => 'Пренасяне на редове';

  @override
  String get fontSize => 'Размер на шрифт';

  @override
  String get lineSpacing => 'Междуредие';

  @override
  String get fontFamily => 'Шрифт';

  @override
  String get theme => 'Тема';

  @override
  String get tableOfContents => 'Съдържание на книгата';

  @override
  String get sheet => 'Лист';

  @override
  String get columns => 'Колони';

  @override
  String get rows => 'Редове';

  @override
  String get windowLevel => 'Прозорец / Ниво';

  @override
  String get invert => 'Инвертиране';

  @override
  String get panZoom => 'Преместване / Мащаб';

  @override
  String resumedAtPage(int page, int total) {
    return 'Възобновено от страница $page от $total';
  }

  @override
  String get fileNotFoundOrInaccessible =>
      'Файлът не е намерен или няма достъп до него.';

  @override
  String get comicRar5NotSupported =>
      'Този CBR файл е компресиран в RAR5 формат, който не се поддържа от вградения архив декомпресор. Моля, преобразувайте комикса в .cbz (ZIP) за пълна съвместимост.';

  @override
  String get comicRarNotSupported =>
      'Този CBR файл използва RAR компресия, която не се поддържа от вградения декомпресор. Моля, преобразувайте архива в .cbz (ZIP) формат.';

  @override
  String get comicArchiveCorrupted =>
      'Архивът на комикса е повреден или нечетлив.';

  @override
  String get comicAutoplay => 'Автоматично прелистване';

  @override
  String get comicAutoplayStart => 'Старт на автоматично прелистване';

  @override
  String get comicAutoplayPause => 'Пауза на прелистването';

  @override
  String get comicAutoplayResume => 'Възобнови прелистването';

  @override
  String get comicAutoplayStop => 'Спри автоматичното прелистване';

  @override
  String get comicAutoplaySettings => 'Настройки за автоматично прелистване';

  @override
  String get comicAutoplayPageDuration => 'Време на страница';

  @override
  String get comicAutoplayScrollSpeed => 'Скорост на Webtoon скролване';

  @override
  String comicAutoplaySeconds(int seconds) {
    return '$seconds сек.';
  }

  @override
  String comicAutoplaySpeedPx(int speed) {
    return '$speed px/сек.';
  }

  @override
  String get comicAutoplayLoop => 'Повторение от началото';

  @override
  String get comicAutoplayPauseOnZoom => 'Пауза при мащабиране';

  @override
  String get comicAutoplayEndReached => 'Достигнат е краят на комикса.';

  @override
  String get comicAutoplayPausedForZoom => 'Пауза (Мащабирано)';

  @override
  String unsupportedFileFormat(String name) {
    return 'Неподдържан файлов формат: $name';
  }

  @override
  String get convertingDwgTitle => 'Конвертиране на DWG...';

  @override
  String get convertingDwgMessage => 'Конвертиране на DWG към DXF за преглед';

  @override
  String get convertingPresentationTitle => 'Конвертиране на презентация...';

  @override
  String get convertingPresentationMessage =>
      'Конвертиране на презентация към PDF за преглед';

  @override
  String errorLoadingSpreadsheet(String error) {
    return 'Грешка при зареждане на Excel файл: $error';
  }

  @override
  String errorLoadingMarkdown(String error) {
    return 'Грешка при зареждане на markdown: $error';
  }

  @override
  String errorReadingWordDocument(String error) {
    return 'Грешка при четене на Word документ: $error';
  }

  @override
  String errorReadingTextFile(String error) {
    return 'Грешка при четене на текстов файл: $error';
  }

  @override
  String get resumedReadingPosition => 'Възобновена позиция на четене';

  @override
  String get woffNotSupported =>
      'Прегледът на WOFF/WOFF2 не се поддържа. Моля, първо конвертирайте в TTF или OTF.';

  @override
  String errorLoading3dModel(String error) {
    return 'Грешка при зареждане на 3D модел: $error';
  }

  @override
  String get failedToParse3dMesh => 'Неуспешно разчитане на 3D геометрията.';

  @override
  String get retry => 'Опитай отново';

  @override
  String get bimStoreysAndCategories => 'BIM етажи и категории';

  @override
  String get properties3d => '3D Свойства';

  @override
  String get dragMode => 'Преместване (Drag)';

  @override
  String get orbitMode => 'Завъртане (Orbit)';

  @override
  String get dragModelTooltip => 'Влачене / преместване на модела';

  @override
  String get rotateModelTooltip => 'Завъртане на модела';

  @override
  String get dragModeActive => 'Режим преместване (активен)';

  @override
  String get flyMode => 'Летене (Walk / Fly)';

  @override
  String get flyModeTooltip => 'Свободно летене и оглед (BIMx / ArchiCAD)';

  @override
  String get flyModeActive => 'Режим летене (BIMx Walk / Fly)';

  @override
  String errorLoadingDxf(String error) {
    return 'Грешка при отваряне на DXF файл: $error';
  }

  @override
  String failedToSaveDxf(String error) {
    return 'Грешка при запис на DXF: $error';
  }

  @override
  String savedDxf(String name) {
    return 'Записан DXF: $name';
  }

  @override
  String errorImportingDxf(String error) {
    return 'Грешка при импортиране на DXF: $error';
  }

  @override
  String importedDxfSuccess(int count, String name) {
    return 'Успешно импортирани $count обекта от $name';
  }

  @override
  String get fitScreen => 'Побиране в екрана';

  @override
  String printPreviewUnavailable(String error) {
    return 'Прегледът за печат е недостъпен: $error';
  }

  @override
  String errorReadingHpgl(String error) {
    return 'Грешка при четене на HPGL плотерен файл: $error';
  }

  @override
  String errorReadingPcb(String error) {
    return 'Грешка при четене на платка (PCB): $error';
  }

  @override
  String errorReadingCdr(String error) {
    return 'Грешка при четене на CorelDRAW файл: $error';
  }

  @override
  String couldNotExportPng(String error) {
    return 'Неуспешен експорт на PNG: $error';
  }

  @override
  String printError(String error) {
    return 'Грешка при печат: $error';
  }

  @override
  String errorReadingEps(String error) {
    return 'Грешка при четене на EPS файл: $error';
  }

  @override
  String errorLoadingSvg(String error) {
    return 'Грешка при зареждане на SVG: $error';
  }

  @override
  String errorLoadingRoute(String error) {
    return 'Грешка при зареждане на маршрут: $error';
  }

  @override
  String centeredOnWaypoint(String name) {
    return 'Центрирано върху: $name';
  }

  @override
  String dicomParseError(String error) {
    return 'Грешка при анализ на DICOM: $error';
  }

  @override
  String errorLoadingDicom(String error) {
    return 'Грешка при зареждане на DICOM изследване: $error';
  }

  @override
  String get dicomReferenceLines => 'Референтни линии';

  @override
  String get dicomLayout => 'Разпределение';

  @override
  String errorLoadingEbook(String error) {
    return 'Грешка при зареждане на електронна книга: $error';
  }

  @override
  String get couldNotDecodePsd =>
      'Неуспешно декодиране на PSD композитно изображение.';

  @override
  String errorPickingFolder(String error) {
    return 'Грешка при избор на папка: $error';
  }

  @override
  String get pleaseSelectSupportedFile =>
      'Моля, изберете поддържан CAD, PCB, 3D, векторен или текстов файл.';

  @override
  String couldNotOpenFilePicker(String error) {
    return 'Неуспешно отваряне на диалога за избор на файл: $error';
  }

  @override
  String errorSharingFile(String error) {
    return 'Грешка при споделяне на файл: $error';
  }

  @override
  String get singlePageModeTooltip =>
      'Режим единична страница (Докоснете за непрекъснат)';

  @override
  String get continuousModeTooltip =>
      'Непрекъснат режим (Докоснете за единична страница)';

  @override
  String get singlePageLabel => 'Единична страница';

  @override
  String get continuousLabel => 'Непрекъснато';

  @override
  String get viewMode => 'Режим на преглед:';

  @override
  String get singlePageSwipe => 'Единична страница (Плъзгане)';

  @override
  String get continuousScroll => 'Непрекъснато превъртане';

  @override
  String archiveFilesCount(int count) {
    return 'Файлове в архива ($count)';
  }

  @override
  String get openArchiveFile => 'Отвори';

  @override
  String get unsupportedArchiveFormat =>
      'Не се поддържа директен преглед за този файлов формат.';

  @override
  String extractingFile(String name) {
    return 'Отваряне на $name...';
  }

  @override
  String get videoViewerTitle => 'Видео плейър';

  @override
  String get videoLoopOn => 'Повторението е включено';

  @override
  String get videoLoopOff => 'Повторението е изключено';

  @override
  String get presentationMode => 'Старт на презентацията';

  @override
  String get nextProjectItem => 'Следващ файл';

  @override
  String get prevProjectItem => 'Предишен файл';

  @override
  String get projectOverview => 'Файлове в проекта';

  @override
  String get uploadViaWifi => 'Качване през Wi-Fi';

  @override
  String get receiveFiles => 'Получаване на файлове';

  @override
  String get receiveFilesSubtitle => 'Качване от браузър през локалната мрежа';

  @override
  String get receivedFiles => 'Получени файлове';

  @override
  String get openFile => 'Отвори';

  @override
  String get hideFromPresentation => 'Скрий от презентацията';

  @override
  String get includeInPresentation => 'Включи в презентацията';

  @override
  String get hiddenInPresentation => 'Скрит';

  @override
  String fileHiddenNotification(String name) {
    return '\"$name\" е скрит от презентацията';
  }

  @override
  String fileIncludedNotification(String name) {
    return '\"$name\" е включен в презентацията';
  }

  @override
  String get unhideAllFiles => 'Включи всички файлове';

  @override
  String get allFilesIncludedNotification =>
      'Всички файлове са включени в презентацията';

  @override
  String hiddenFilesFilter(int count) {
    return 'Скрити ($count)';
  }

  @override
  String get allFilesHiddenWarning =>
      'Всички файлове са скрити от презентацията. Моля, включете поне един файл.';

  @override
  String get fileSkippedInPresentation => 'Пропуснат от презентацията';

  @override
  String get checkForUpdates => 'Проверка за нова версия';

  @override
  String get checkingForUpdates => 'Проверка за нова версия...';

  @override
  String get updateAvailableTitle => 'Налична е нова версия';

  @override
  String get updateAvailableMessage =>
      'Налична е нова версия на KoToViewer в Google Play.';

  @override
  String get updateNow => 'Актуализиране';

  @override
  String get updateDownloadedSnackbar =>
      'Новата версия е изтеглена. Рестартирайте приложението, за да я приложите.';

  @override
  String get restartToUpdate => 'Рестартиране';

  @override
  String get appUpToDate => 'Използвате най-новата версия на KoToViewer.';

  @override
  String get updateCheckFailed =>
      'Неуспешна проверка за нова версия през Google Play.';

  @override
  String get openPlayStore => 'Отвори Google Play';

  @override
  String get debugTestingNote =>
      'При дебъг / локален билд, Google Play обновяването изисква инсталация през Play Store (Вътрешен тестов канал или Internal App Sharing).';

  @override
  String get simulateUpdate => 'Симулирай обновяване (Дебъг)';

  @override
  String get localAppFolder => 'Качени файлове';

  @override
  String get localAppFolderSubtitle => 'Папка в паметта на приложението';

  @override
  String get deleteFileTitle => 'Изтриване на файл';

  @override
  String deleteFileConfirm(String name) {
    return 'Сигурни ли сте, че искате да изтриете \"$name\" от паметта на приложението?';
  }

  @override
  String get delete => 'Изтрий';

  @override
  String get fileDeleted => 'Файлът беше изтрит';

  @override
  String get removeFromRecent => 'Премахни от скорошни';

  @override
  String get pdfFormFilling => 'Попълване на формуляр';

  @override
  String pdfFormFieldsCount(int count) {
    return '$count полета';
  }

  @override
  String get pdfNoFormFields =>
      'Този документ не съдържа интерактивни формулярни полета.';

  @override
  String get pdfFormSaved => 'Формулярът беше успешно запазен!';

  @override
  String get pdfFormFlatten => 'Заключи формуляра след запис (Flatten)';

  @override
  String get pdfFormFlattenTooltip =>
      'Стойностите ще станат статичен текст и формулярът няма да може да се редактира.';

  @override
  String get pdfFormSaveAsCopy => 'Запази като нов файл...';

  @override
  String get pdfFormSaveOverwrite => 'Запази';

  @override
  String get pdfDigitalCertificates => 'Цифрови сертификати и подписи';

  @override
  String get pdfNoDigitalCertificates =>
      'Този документ не съдържа цифров сертификат или вграден електронен подпис.';

  @override
  String get pdfSignedBy => 'Подписано от:';

  @override
  String get pdfIssuer => 'Издател (CA):';

  @override
  String get pdfSignDate => 'Дата на подписване:';

  @override
  String get pdfValidFrom => 'Валиден от:';

  @override
  String get pdfValidTo => 'Валиден до:';

  @override
  String get pdfSignatureValid => 'Валиден сертификат';

  @override
  String get pdfSignatureExpired => 'Изтекъл сертификат';

  @override
  String get pdfCheckExternalCert => 'Провери външен сертификатен файл';

  @override
  String get fullscreen => 'Цял екран';

  @override
  String get exitFullscreen => 'Изход от цял екран';

  @override
  String get lockRotation => 'Заключване на завъртането';

  @override
  String get unlockRotation => 'Отключване на завъртането';

  @override
  String get rotationLocked => 'Завъртането на екрана е заключено';

  @override
  String get rotationUnlocked => 'Автоматичното завъртане е възстановено';

  @override
  String get dwgMemoryLimitError =>
      'Чертежът съдържа твърде много вътрешни обекти и изисква повече оперативна памет от наличната на това устройство. Препоръчваме да го конвертирате в DXF на компютър или да го изчистите с командата PURGE в CAD софтуер.';

  @override
  String dwgConversionFailed(String error) {
    return 'Грешка при конвертиране на DWG файл: $error';
  }

  @override
  String get structuralDesignerBim => 'Конструктивен Модел (BIM)';

  @override
  String get showBimOverlay => 'Покажи BIM елементи';

  @override
  String get hideBimOverlay => 'Скрий BIM елементи';

  @override
  String get structuralDesigner => 'Конструктивен Модел';

  @override
  String get structural3dView => '3D Конструкция';

  @override
  String get snapEnabledTooltip => 'Прилепване (Snap): Включено';

  @override
  String get snapDisabledTooltip => 'Прилепване (Snap): Изключено';

  @override
  String get undoAction => 'Отмени';

  @override
  String traceReferenceLayer(String storey) {
    return 'Референтен слой (Trace): $storey';
  }

  @override
  String get toolNavigation => 'Навигация';

  @override
  String get toolColumn => 'Колона';

  @override
  String get toolShearWall => 'Шайба';

  @override
  String get toolSlab => 'Плоча';

  @override
  String get toolOpening => 'Отвор';

  @override
  String get toolCantilevers => 'Еркери';

  @override
  String circularColumnPreset(int diameter) {
    return 'Ø$diameter кръгла';
  }

  @override
  String get rotate90 => 'Завърти на 90°';

  @override
  String get wallThicknessLabel => 'Дебелина на шайба: ';

  @override
  String get undoPoint => 'Отмени точка';

  @override
  String closeSlab(int count) {
    return 'Затвори ($count)';
  }

  @override
  String get storeyManagerTitle => 'Етажен Мениджър (Нива & Слоеве)';

  @override
  String get traceReferenceTitle => 'Trace Reference (Блед референтен слой)';

  @override
  String get traceRefNone => 'Изключен';

  @override
  String get traceRefBelow => 'Долен етаж';

  @override
  String get traceRefAbove => 'Горен етаж';

  @override
  String storeyElevationSub(
    String elevation,
    String height,
    int columns,
    int walls,
  ) {
    return 'Кота Z: +$elevation m • H: $height m • $columns кол, $walls шайби';
  }

  @override
  String get changeHeightH => 'Промени височина H';

  @override
  String get deleteStorey => 'Изтрий етаж';

  @override
  String get newStorey => 'Нов етаж';

  @override
  String get duplicateTypical => 'Дублирай типови';

  @override
  String get storeyClearHeight => 'Светла височина на етажа (m)';

  @override
  String get cantileverAnalysisTitle =>
      'Анализ на Еркери (Конзоли & Провисване)';

  @override
  String get totalCantilevers => 'Общо еркери';

  @override
  String get cornerCantilevers => 'Ъглови двойни';

  @override
  String get criticalZones => 'Критични зони';

  @override
  String get maxDeflection => 'Макс. провисване';

  @override
  String get eurocodeStandardInfo =>
      'БДС EN 1992-1-1 (EC2): Гранично провисване flim = Lcant / 250. Включено пълзене на бетона φ = 2.5 и фасаден товар.';

  @override
  String get noCantileversFound =>
      'Няма засечени конзолни зони или еркери.\nВсички плочи стъпват изцяло върху колони/шайби.';

  @override
  String get propLengthL => 'Дължина L';

  @override
  String get propSlabH => 'Плоча h';

  @override
  String deflectionFtot(String value) {
    return 'Провисване ftot: $value mm';
  }

  @override
  String deflectionLimitFlim(String value) {
    return 'Лимит flim: $value mm';
  }

  @override
  String get structural3dTitle => '3D Конструктивен Модел';

  @override
  String get shadingModeTitle => 'Режим на осветяване';

  @override
  String get centerView => 'Центрирай изглед';

  @override
  String get allStoreys => 'Всички етажи';

  @override
  String get shadingWireframe => 'Прозрачен (Телена мрежа)';

  @override
  String get shadingSolid => 'Бял солид';

  @override
  String get shadingShadedEdges => 'Осветен с ръбове';

  @override
  String get shadingNormals => 'Нормали на повърхнините';

  @override
  String get snapEndpoint => 'Край';

  @override
  String get snapMidpoint => 'Среда';

  @override
  String get snapCenter => 'Център';

  @override
  String get snapNearest => 'Най-близка';

  @override
  String get snapPerpendicular => 'Перпендикуляр';

  @override
  String get snapPoint => 'Точка';

  @override
  String previewColumnTag(int width, int height) {
    return 'Колона $width x $height cm';
  }

  @override
  String previewCircularColumnTag(int diameter) {
    return 'Колона Ø$diameter cm';
  }

  @override
  String get previewWallStartTag => 'Шайба: начало на стена';

  @override
  String get previewWallEndTag => 'Шайба: край на стена';

  @override
  String previewSlabVertexTag(int index) {
    return 'Плоча: точка $index';
  }

  @override
  String get cantileverTypeLinear => 'Линеен еркер (еднопосочна конзола)';

  @override
  String get cantileverTypeCorner => 'Двоен ъглов еркер (двупосочна конзола)';

  @override
  String get cantileverTypeTransfer =>
      'Трансферен еркер (колона върху конзола)';

  @override
  String get riskLevelSafe => 'В норма (Безопасно)';

  @override
  String get riskLevelWarning => 'Внимание (Повишено провисване)';

  @override
  String get riskLevelCritical => 'Критично (Риск от недопустими деформации)';

  @override
  String storeyLevelName(int number, String elevation) {
    return 'Етаж $number (Кота +$elevation)';
  }

  @override
  String storeyTypicalName(int number, String source) {
    return 'Етаж $number (Типов от $source)';
  }

  @override
  String get hardwareAcceleration => 'Хардуерно GPU ускорение';

  @override
  String get gpuAccelerationActive => 'Хардуерно GPU ускорение (Активно)';

  @override
  String get gpuAccelerationInactive => 'Хардуерно GPU ускорение (Изключено)';

  @override
  String get structuralFilterActive => 'Филтър подложка (Вкл.)';

  @override
  String get structuralFilterInactive => 'Филтър подложка (Изкл.)';

  @override
  String get structuralFilterNoWallsFound =>
      'Няма разпознати специфични слоеве за стени; показани са всички слоеве';

  @override
  String get floatingColumnBadge => 'НАСАДЕНА';

  @override
  String alignedOffsetFlush(String offset) {
    return '$offset m (Прилепено)';
  }

  @override
  String get layersTabTitle => 'Слоеве';

  @override
  String get layersTabHint =>
      'Задръжте елемент от чертежа, за да скриете или изолирате слоя му';

  @override
  String get underlayFilterTitle => 'Филтър подложка';

  @override
  String get underlayFilterSubtitle =>
      'Изберете кои CAD слоеве да се показват при активен филтър';

  @override
  String get underlayFilterAutoReset => 'Автоматично (Стени и оси)';

  @override
  String get underlayFilterSelectAll => 'Всички слоеве';

  @override
  String get underlayFilterClearAll => 'Изчисти';

  @override
  String get syncColumnsAcrossStoreys => 'Синхронизирай колоните по нива';

  @override
  String syncColumnsSuccess(int count) {
    return '$count колони са синхронизирани по нива';
  }

  @override
  String layerHiddenNotice(String layer) {
    return 'Слоят \"$layer\" е скрит';
  }

  @override
  String get filteringUnderlay => 'Прилагане на филтър за подложка...';

  @override
  String get searchLayers => 'Търсене на слой...';

  @override
  String get manageUnderlayFilter => 'Настройка на филтъра';

  @override
  String get previewSlabCorner1Tag => 'Плоча: посочете 1-ви ъгъл';

  @override
  String get previewSlabCorner2Tag => 'Плоча: посочете срещуположен ъгъл';

  @override
  String cantileverExtrudeDepth(String depth) {
    return 'Еркер: $depth m';
  }

  @override
  String get slabEdgeExtrudeTooltip =>
      'Изтеглете средата на отсечката за еркер';

  @override
  String slabParallelAligned(String distance) {
    return 'Прилепено към линия: $distance m';
  }

  @override
  String get slabPointByPointPrompt => 'Поставяйте точки със снап';

  @override
  String get cancelSlab => 'Откажи плоча';

  @override
  String slabRectDimensions(String width, String height) {
    return 'Плоча: $width x $height m';
  }

  @override
  String get moveElement => 'Премести';

  @override
  String get rotateElement => 'Завърти 90°';

  @override
  String get mirrorElement => 'Огледало';

  @override
  String get columnDeleted => 'Колоната е изтрита';

  @override
  String selectedColumnTitle(String dimensions) {
    return 'Избрана колона $dimensions';
  }

  @override
  String get dragToMoveTooltip => 'Задръжте и плъзнете за преместване';

  @override
  String get slabCorrectionTitle => 'Корекция на плоча';

  @override
  String get slabOffsetLabel => 'Отместване';

  @override
  String get slabRotateLabel => 'Ротация';

  @override
  String get slabPointsMerged => 'Точките са обединени';

  @override
  String slabPointDeleted(int number) {
    return 'Точка $number е изтрита';
  }

  @override
  String get slabVertexInserted => 'Добавена е нова точка в средата';

  @override
  String get slabMinPointsWarning => 'Плочата трябва да има поне 3 точки';

  @override
  String get deleteSlab => 'Изтрий плоча';

  @override
  String get slabDeleted => 'Плочата е изтрита';

  @override
  String get editSlabAction => 'Корекция на плоча';

  @override
  String get selectedSlabTitle => 'Избрана плоча';

  @override
  String get duplicateElement => 'Дублирай';

  @override
  String get flipSide => 'Обърни страна';

  @override
  String selectedWallTitle(String dimensions) {
    return 'Избрана шайба $dimensions';
  }

  @override
  String get columnShapeLShape => 'Г-образна 50x50/25';

  @override
  String get toolBeam => 'Греда';

  @override
  String selectedBeamTitle(String dimensions) {
    return 'Избрана греда $dimensions';
  }

  @override
  String selectedOpeningTitle(String dimensions) {
    return 'Избран отвор $dimensions';
  }

  @override
  String get deleteVertex => 'Изтрий точка';

  @override
  String get beamPreset25x50 => '25x50';

  @override
  String get beamPreset25x60 => '25x60';

  @override
  String get beamPreset25x40 => '25x40';

  @override
  String get openingPresetShaft => 'Щранг 0.40x0.60';

  @override
  String get openingPresetStairs => 'Стълбище 2.40x4.50';

  @override
  String get openingPresetElevator => 'Асансьор 1.80x2.00';

  @override
  String get openingPresetCustom => 'Свободен отвор';

  @override
  String get deleteOpening => 'Изтрий отвор';

  @override
  String get toolGridAxis => 'Осова линия';

  @override
  String selectedGridAxisTitle(String name) {
    return 'Осова линия $name';
  }

  @override
  String get deleteGridAxis => 'Изтрий ос';

  @override
  String get renameGridAxis => 'Преименувай';

  @override
  String get firstWallSidePrompt => 'Изберете първа страна на стена';

  @override
  String get secondWallSidePrompt => 'Изберете срещуположна страна';

  @override
  String get snapIntersection => 'Пресечна точка';

  @override
  String get verticalCapacityTitle => 'Вертикален капацитет (EC2)';

  @override
  String get verticalCapacitySubtitle =>
      'Смачкване на колони, пробиване на плоча и провисване';

  @override
  String get columnCrushingTitle => 'Смачкване на колони';

  @override
  String get punchingShearTitle => 'Пробиване на плоча';

  @override
  String get slabDeflectionTitle => 'Препоръчителна дебелина на плоча';

  @override
  String get foundationPressureTitle => 'Натоварване на основите';

  @override
  String get totalBaseLoad => 'Общ вертикален товар';

  @override
  String get criticalColumns => 'Критични колони';

  @override
  String get punchingRisks => 'Риск от пробиване';

  @override
  String get maxSpanLabel => 'Макс. светъл отвор';

  @override
  String get recommendedThicknessLabel => 'Препоръчителна дебелина';

  @override
  String get axialUtilizationLabel => 'Осов натиск (EC2)';

  @override
  String get punchingStressLabel => 'Срязване при пробиване';

  @override
  String get statusSafe => 'В норма';

  @override
  String get statusWarning => 'Повишено натоварване';

  @override
  String get statusCritical => 'Критично претоварване';

  @override
  String get ec2FeasibilityButton => 'EC2 Капацитет';

  @override
  String columnRequiredSection(String section) {
    return 'Изисква минимум $section';
  }

  @override
  String storeyColumnLoad(String storey, String ned, String nrd, String ratio) {
    return '$storey: Ned = $ned kN / Nrd = $nrd kN ($ratio%)';
  }

  @override
  String get seismicAnalysisTitle => 'Предварителна сеизмична оценка';

  @override
  String get seismicAnalysisSubtitle =>
      'Показатели за схема — без доказано съответствие с EC8';

  @override
  String get centerOfMass => 'Център на масите (CM)';

  @override
  String get centerOfRigidity => 'Център на коравините (CR)';

  @override
  String get seismicEccentricity => 'Сеизмичен ексцентрицитет';

  @override
  String get torsionalSensitivity => 'Усуквателна чувствителност';

  @override
  String get shearWallRatio => 'Покритие с шайби';

  @override
  String get floatingColumnsTitle => 'Насадени колони';

  @override
  String get discontinuousWallsTitle => 'Прекъснати шайби';

  @override
  String get softStoreyTitle => 'Мек етаж';

  @override
  String get beamSizingTitle => 'Сечения на греди';

  @override
  String get openingsProximityTitle => 'Отвори в плочата';

  @override
  String get ec8SeismicButton => 'EC8 Сеизмичност';

  @override
  String beamDepthWarning(int depth) {
    return 'Препоръчителна височина: мин. $depth cm';
  }

  @override
  String floatingColumnWarning(String name, String storey) {
    return 'Колона $name на $storey е насадена върху плочата (липсва долна опора)!';
  }

  @override
  String get applyAction => 'Приложи';

  @override
  String get offsetAction => 'Офсет';

  @override
  String get renameColumnTitle => 'Преименуване на колона';

  @override
  String get renameBeamTitle => 'Преименуване на греда';

  @override
  String get designationLabel => 'Обозначение (напр. К1, К2, С1)';

  @override
  String get keepBoth => 'Запази и двете';

  @override
  String get deletePrevious => 'Изтрий предишната';

  @override
  String get offsetCreatedTitle => 'Офсетът е създаден';

  @override
  String deletePreviousAxisPrompt(String name) {
    return 'Желаете ли да изтриете предишната ос \"$name\"?';
  }

  @override
  String deletePreviousColumnPrompt(String name) {
    return 'Желаете ли да изтриете предишната колона \"$name\"?';
  }

  @override
  String offsetWithDuplication(String item) {
    return 'Офсет с дублиране: $item';
  }

  @override
  String get distanceMeters => 'Разстояние (метри)';

  @override
  String get duplicationDirection => 'Посока на дублиране:';

  @override
  String get directionLeft => 'Наляво';

  @override
  String get directionRight => 'Надясно';

  @override
  String get directionUp => 'Нагоре';

  @override
  String get directionDown => 'Надолу';

  @override
  String get specifyDirectionByDrag => 'Укажи посока с влачене на екрана';

  @override
  String dragForDirectionReleaseToOffset(String distance) {
    return 'Плъзнете за посока • Пуснете за офсет ($distance m)';
  }

  @override
  String get columnDimensionsTitle => 'Размери на колона';

  @override
  String get widthCm => 'Ширина (cm)';

  @override
  String get heightCm => 'Височина (cm)';

  @override
  String get shapeRectangular => 'Правоъгълна';

  @override
  String get shapeCircular => 'Кръгла';

  @override
  String get shapeLShape => 'L-образна';

  @override
  String get shearWallThicknessTitle => 'Дебелина на шайба';

  @override
  String get thicknessCm => 'Дебелина (cm)';

  @override
  String get beamDimensionsTitle => 'Размери на греда';

  @override
  String get widthBCm => 'Ширина b (cm)';

  @override
  String get depthHCm => 'Височина h (cm)';

  @override
  String get slabThicknessTitle => 'Дебелина на плочата';

  @override
  String get slabThicknessHCm => 'Дебелина h (cm)';

  @override
  String get axisNameTitle => 'Име на ос';

  @override
  String get axisNameLabel => 'Име / номер на ос (напр. 1, A, 1-1)';

  @override
  String get shearWallTitle => 'Шайба';

  @override
  String get beamTitle => 'Греда';

  @override
  String get slabOpeningTitle => 'Отвор в плоча';

  @override
  String get openingShaftTitle => 'Щранг';

  @override
  String get openingStaircaseTitle => 'Стълбищен отвор';

  @override
  String get openingElevatorTitle => 'Асансьорна шахта';

  @override
  String gridAxisTitle(String name) {
    return 'Ос \"$name\"';
  }

  @override
  String get structuralElevationLabel => 'К.К.';

  @override
  String get layersTooltip => 'Слоеве на подложката';

  @override
  String get dimensionsEllipsis => 'Размери...';

  @override
  String get otherEllipsis => 'Друга...';

  @override
  String get hiddenBeamLabel => 'скрита';

  @override
  String get shaftOpeningLabel => 'Щранг (40×60 cm)';

  @override
  String get elevatorOpeningLabel => 'Асансьор (1.8×2.0)';

  @override
  String get stairsOpeningLabel => 'Стълби (2.4×4.5)';

  @override
  String get nameEllipsis => 'Име...';

  @override
  String get pointsAbbr => 'т.';

  @override
  String get previewOpeningCorner2Tag => 'Отвор: избери срещуположен ъгъл';

  @override
  String get cancelOpening => 'Отказ от отвор';

  @override
  String get seismicStatMaxEccentricity => 'Макс. ексц.';

  @override
  String get seismicStatTorsion => 'Усукване';

  @override
  String get seismicStatusHigh => 'ВИСОКО';

  @override
  String get seismicStatusNormal => 'В норма';

  @override
  String get seismicStatFloatingColumns => 'Насадени колони';

  @override
  String get seismicStatShearWallsEc8 => 'Дял шайби*';

  @override
  String get seismicStatusDeficit => 'ДЕФИЦИТ';

  @override
  String get seismicStatusOkCoverage => '≥1%*';

  @override
  String get seismicTabBalance => 'Баланс (CM/CR)';

  @override
  String get seismicTabWalls => 'Шайби (%)';

  @override
  String get seismicTabRegularity => 'Регулярност';

  @override
  String get seismicTabBeamsOpenings => 'Греди/Отвори';

  @override
  String get seismicNoStoreys => 'Няма данни за етажи в проекта.';

  @override
  String get seismicEccentricityTitle => 'Сеизмичен ексцентрицитет';

  @override
  String get seismicTorsionSensitive => 'Усуквателно чувствителна';

  @override
  String get seismicBalanced => 'Балансирана';

  @override
  String get seismicEccentricityXLabel => 'Ексцентрицитет X (ex)';

  @override
  String get seismicEccentricityYLabel => 'Ексцентрицитет Y (ey)';

  @override
  String get seismicLimitEc8Label => 'Ориентир за ексц.';

  @override
  String get seismicTorsionStiffEccentric => 'Торзионно устойчива (e > 0.30·r)';

  @override
  String get seismicStatusEccentricShort => 'Ексцентрична';

  @override
  String get seismicTorsionalRadiiLabel => 'Торзионни радиуси (rx, ry)';

  @override
  String get seismicMassRadiusLabel => 'Инерционен радиус (ls)';

  @override
  String get seismicLimitEc8Formula => '≤ 0.30·r (EC8)';

  @override
  String get seismicShearWallCoverageTitle =>
      'Площен дял на шайбите — евристика';

  @override
  String get seismicOkMinCoverage => 'Ориентир ≥1%';

  @override
  String get seismicDeficitMinCoverage => 'Ориентир <1%';

  @override
  String get seismicWallCoverageXLabel => 'Покритие по X (ρ_wx):';

  @override
  String get seismicWallCoverageYLabel => 'Покритие по Y (ρ_wy):';

  @override
  String seismicWallRecommendationText(String area) {
    return 'Препоръка по Eurocode 8 за България: минимум 1.0% - 1.5% шайби във всяко от двете направления спрямо етажна площ ($area m²).';
  }

  @override
  String get seismicFloatingColumnsTitle =>
      'Насадени колони (Floating / Transfer Columns)';

  @override
  String seismicCountFound(int count) {
    return '$count открити';
  }

  @override
  String get seismicNoFloatingColumnsText =>
      'Няма насадени колони. Всички колони по височината стъпват надеждно върху вертикални опори на долните етажи.';

  @override
  String get seismicCriticalEc8FloatingText =>
      'КРИТИЧНО ЗА ЗЕМЕТРЪС (EC8 §4.2.3.3): Насадените колони предават целия си сеизмичен и вертикален товар точково върху плочата!';

  @override
  String seismicFloatingColItem(String storey, String columns) {
    return '• $storey: Колони $columns са насадени без колона отдолу.';
  }

  @override
  String get seismicSoftStoreyTitle => 'Проверка за Мек етаж (Soft Storey)';

  @override
  String get seismicDanger => 'ОПАСНОСТ';

  @override
  String get seismicNone => 'НЯМА';

  @override
  String get seismicSoftStoreyDangerText =>
      'Установена е рязка загуба на коравина (> 30%) между съседни етажи. Това създава предпоставка за етажен механизъм на разрушение при земетръс.';

  @override
  String get seismicSoftStoreyOkText =>
      'Коравината между етажите се изменя плавно по височина (без меки етажи).';

  @override
  String get seismicNoBeamsOrOpenings =>
      'Няма дефинирани греди или отвори в плочите.';

  @override
  String get seismicBeamSizingTitle =>
      'Предварително оразмеряване на греди (h = L/10 - L/12):';

  @override
  String seismicSpanM(String span) {
    return 'Отвор L = $span m';
  }

  @override
  String get seismicOpeningsProximityTitle =>
      'Геометрична близост на отвори — ориентир 0,70 m';

  @override
  String seismicRecFloatingCols(String names) {
    return 'Колони $names са НАСАДЕНИ върху плочата (без колона отдолу). Това е сериозна сеизмична уязвимост! ';
  }

  @override
  String seismicRecHighTorsion(String ecc, int pct) {
    return 'Силно усукване: ексцентрицитет $ecc m ($pct%). ';
  }

  @override
  String get seismicRecAddWallEast =>
      'Препоръка: добавете шайба в източната (дясна) част. ';

  @override
  String get seismicRecAddWallWest =>
      'Препоръка: добавете шайба в западната (лява) част. ';

  @override
  String get seismicRecAddWallNorth =>
      'Препоръка: добавете шайба в северната част. ';

  @override
  String get seismicRecAddWallSouth =>
      'Препоръка: добавете шайба в южната част. ';

  @override
  String seismicRecDeficitBoth(String rx, String ry) {
    return 'Дефицит на шайби в двете направления (X: $rx%, Y: $ry% < 1.0%). Препоръчват се допълнителни шайби. ';
  }

  @override
  String seismicRecDeficitX(String rx) {
    return 'Дефицит на шайби по X ($rx% < 1.0%). Препоръчва се шайба по направление X. ';
  }

  @override
  String seismicRecDeficitY(String ry) {
    return 'Дефицит на шайби по Y ($ry% < 1.0%). Препоръчва се шайба по направление Y. ';
  }

  @override
  String get seismicRecBalanced =>
      'Няма сигнал от предварителните показатели за схемата. Съответствие с EC8 не е доказано. ';

  @override
  String seismicRecTorsionStiffEccentric(
    String rx,
    String ry,
    String ls,
    String ecc,
  ) {
    return 'Торзионно устойчива схема (rx=$rx m, ry=$ry m ≥ ls=$ls m), но структурният ексцентрицитет ($ecc m) надвишава 0.30·r. Изисква се 3D пространствен динамичен модален анализ съгласно Еврокод 8. ';
  }

  @override
  String seismicRecTorsionRegular(String rx, String ry, String ls) {
    return 'Регулярна в план по EC8 §4.2.3.2 (rx=$rx m, ry=$ry m ≥ ls=$ls m, e ≤ 0.30·r). Отличен сеизмичен баланс. ';
  }

  @override
  String seismicRecTorsionFlexible(String rx, String ry, String ls) {
    return 'Усукващо податлива система по EC8 §4.2.3.2 (rx=$rx m, ry=$ry m < ls=$ls m). Недостатъчна периферна торзионна коравина! Препоръчват се допълнителни периферни шайби/колони. ';
  }

  @override
  String get seismicRecSoftStoreyPrefix =>
      'ВНИМАНИЕ: МЕК ЕТАЖ! Коравината на този етаж е с над 30% по-ниска от горния. ';

  @override
  String seismicRecBeamDepthInsufficient(
    String span,
    int depth,
    int recW,
    int recH,
  ) {
    return 'За отвор L = $span m, височина $depth cm е недостатъчна. Препоръчва се греда ${recW}x$recH cm.';
  }

  @override
  String seismicRecBeamWidthInsufficient(int width, int depth) {
    return 'Ширина $width cm е под сеизмичния минимум (25 cm по EC8). Препоръчва се 25x$depth cm.';
  }

  @override
  String seismicRecBeamSizingOk(int width, int depth, String span) {
    return 'Сечение ${width}x$depth cm е напълно оразмерено за отвор L = $span m.';
  }

  @override
  String seismicRecOpeningClose(String dist, String support) {
    return 'Отстояние между контурите на отвора и $support: $dist m — под ориентировъчните 0,70 m. Необходима е отделна проверка за пробиване и окантване.';
  }

  @override
  String seismicRecOpeningSafe(String dist, String support) {
    return 'Отстояние между контурите на отвора и $support: $dist m. Геометричният ориентир 0,70 m не е нарушен; пробиване не е проверено.';
  }

  @override
  String get seismicNoSlabBadge => 'Липсва плоча';

  @override
  String get seismicNoSlabEccentricity => 'Невъзможно без плоча';

  @override
  String get seismicRecNoSlabDiaphragm =>
      'Липсва подова плоча на този етаж. Съгласно Еврокод 8 и строителната динамика, над колоните и шайбите е необходима плоча, която да формира хоризонтална сеизмична диафрагма и да позволи изчисляване на Центъра на масите (CM), Центъра на коравината (CR) и ексцентрицитета.';

  @override
  String seismicRecDisconnectedWalls(String names) {
    return 'Шайби $names са разположени извън очертанията на плочата и не са свързани с подовата диафрагма. Те са изключени от пресмятането на коравината (CR) и сеизмичния център.';
  }

  @override
  String seismicRecDisconnectedCols(String names) {
    return 'Колони $names са разположени извън очертанията на плочата и не са свързани с подовата диафрагма.';
  }

  @override
  String seismicWallsOutsideSlabWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шайби извън плочата (изключени от диафрагмата)',
      one: '1 шайба извън плочата (изключена от диафрагмата)',
    );
    return '$_temp0';
  }

  @override
  String get seismicNoSlabWallCoverage =>
      'Не може да се пресметне процентно покритие на шайбите без подова плоча.';

  @override
  String get seismicPreliminaryBalanced => 'Без сигнал от модела';

  @override
  String get seismicRigidityUnavailable =>
      'Напречната схема не може да се оцени: липсват използваеми свързани опори, има неподдържано сечение или неустойчив числен модел. CR и ексцентрицитетът са неопределени.';

  @override
  String get verticalBasePressure => 'Базисен натиск';

  @override
  String get verticalNoColumns => 'Няма дефинирани колони в проекта.';

  @override
  String get verticalPunchingCheckLabel => 'Пробиване (EC2 §6.4):';

  @override
  String verticalRecSlabInsufficient(String span, int cur, int req) {
    return 'При отвор L = $span m, дебелина $cur cm е недостатъчна. Препоръчва се плоча минимум $req cm.';
  }

  @override
  String verticalRecSlabBeamlessDeflection(String span, int cur, int req) {
    return 'При светъл отвор L = $span m без греди, плоча $cur cm ще провисне недопустимо. Препоръчва се минимум $req cm или главни греди 25x50 cm.';
  }

  @override
  String verticalRecSlabSafe(int cur, String span) {
    return 'Дебелината на плочата ($cur cm) е напълно достатъчна за светъл отвор L = $span m.';
  }

  @override
  String verticalRecColOverloaded(
    String name,
    String storey,
    int curW,
    int curH,
    String minSec,
    int storeys,
    String ned,
    String nrd,
  ) {
    return 'Колона $name в $storey не може да е ${curW}x$curH cm, трябва да е минимум $minSec, за да носи $storeys етажа (Ned = $ned kN, капацитет Nrd = $nrd kN).';
  }

  @override
  String verticalRecColWarning(
    String name,
    String storey,
    int util,
    String minSec,
  ) {
    return 'Колона $name в $storey е близо до капацитета си ($util%). Препоръчва се преминаване към $minSec.';
  }

  @override
  String verticalRecColSafe(
    String name,
    int curW,
    int curH,
    String storey,
    int storeys,
    int util,
  ) {
    return 'Колона $name (${curW}x$curH cm) в $storey поема $storeys етажа напълно безопасно ($util%).';
  }

  @override
  String verticalRecPunchingRisk(
    String name,
    String ved,
    String vrdc,
    int slabH,
  ) {
    return 'Риск от пробиване на плочата при $name (v_Ed = $ved MPa > v_Rd,c = $vrdc MPa). Препоръчва се капител (drop panel), плоча $slabH cm или по-голяма колона.';
  }

  @override
  String verticalRecPunchingProtectedByBeams(String name) {
    return 'Колона $name е защитена от пробиване: товарът от плочата се поема директно от главните носещи греди.';
  }

  @override
  String verticalTabColumns(int count) {
    return 'Колони ($count)';
  }

  @override
  String verticalTabSlabs(int count) {
    return 'Плочи ($count)';
  }

  @override
  String get verticalTabFoundations => 'Основи';

  @override
  String verticalStoreysCarried(
    String storey,
    int storeys,
    String storeysLabel,
    String area,
  ) {
    return '$storey • Носи $storeys $storeysLabel • Atrib = $area m²';
  }

  @override
  String get verticalStoreySingle => 'етаж';

  @override
  String get verticalStoreyPlural => 'етажа';

  @override
  String get verticalAxialCompressionLabel => 'Осов натиск (EC2 §5.8):';

  @override
  String get verticalNoSlabs => 'Няма данни за плочи в проекта.';

  @override
  String verticalSlabStoreyTitle(String storey) {
    return 'Плоча - $storey';
  }

  @override
  String get verticalSlabStatusOk => 'В норма';

  @override
  String get verticalSlabStatusEnlarge => 'Препоръчва се уголемяване';

  @override
  String get verticalClearSpanLmax => 'Светъл отвор (Lmax)';

  @override
  String get verticalCurrentThicknessH => 'Текуща дебелина (h)';

  @override
  String get verticalRequiredThicknessEc2 => 'Изисквана (EC2 §7.4)';

  @override
  String get verticalFoundationsEvaluation =>
      'Оценка на натоварването върху основите';

  @override
  String get verticalTotalBaseLoadNed =>
      'Общ вертикален товар в основата (Ned,base):';

  @override
  String get verticalFootprintArea => 'Застроена площ (фундаментна основа):';

  @override
  String get verticalMeanBasePressure =>
      'Среден базисен натиск върху почвата (σ_base):';

  @override
  String verticalBasePressureSafeText(String pressure) {
    return 'Базисният натиск ($pressure kPa) е в стандартните граници за фундаментна плоча/ивични основи в умерени до добри почви (R0 >= 200 kPa).';
  }

  @override
  String verticalBasePressureHighText(String pressure) {
    return 'Базисният натиск ($pressure kPa) е висок. Препоръчва се цялостна фундаментна плоча (mat foundation) или пилотно фундиране след геоложки доклад.';
  }

  @override
  String get toolMeasure => 'Мярка';

  @override
  String get distanceCentimeters => 'Разстояние (см)';

  @override
  String get loadStructuralModule => 'Зареди конструктивния модул';

  @override
  String get updatingLayers => 'Обновяване на слоевете...';

  @override
  String get isolateStructuralLayers => 'Изолирай конструктивни';

  @override
  String get showAllLayers => 'Всички слоеве';

  @override
  String get layersPreparationTitle => 'Подготовка на слоеве за BIM';

  @override
  String get layersPreparationSubtitle =>
      'Скрийте излишните архитектурни слоеве (мебели, текстове, щриховки) за максимална прегледност и бързина.';

  @override
  String get exportBimModel => 'Експорт на BiM модел';

  @override
  String get exportBimJson => 'BiM проект (JSON)';

  @override
  String get exportStructuralDxf => 'Конструктивен AutoCAD (DXF)';

  @override
  String get exportSuccess => 'Моделът беше експортиран успешно';

  @override
  String exportFailed(String error) {
    return 'Неуспешен експорт: $error';
  }

  @override
  String slabOverStorey(String storey) {
    return 'Плоча над $storey';
  }

  @override
  String get shearWallSizePreset => '25×150 см';

  @override
  String get shearWallSizePresetAlt => '25×120 см';

  @override
  String get customWallDimensions => 'Произволна шайба...';

  @override
  String measuredDistance(String meters, String cm) {
    return 'Разстояние: $meters m ($cm cm)';
  }

  @override
  String measuredDelta(String dx, String dy) {
    return 'ΔX = $dx m, ΔY = $dy m';
  }

  @override
  String get clearMeasurement => 'Изчисти';

  @override
  String get columnNamePrefix => 'К';

  @override
  String get shearWallNamePrefix => 'Ш';

  @override
  String slabSectionElevationMarker(String elevation) {
    return 'К.К. $elevation';
  }

  @override
  String slabThicknessLabel(String thickness) {
    return 'd = $thickness cm';
  }

  @override
  String get autoDetectWallsAndAxes => 'Автоматично откриване на стени и оси';

  @override
  String autoDetectWallsPrompt(String thickness, String unit, String layer) {
    return 'Открити са зидове ($thickness $unit) в \"$layer\". Желаете ли да изолирате стените в чист слой и да генерирате осови линии?';
  }

  @override
  String get isolateWallsAndGenerateAxes => 'Изолирай стените и генерирай оси';

  @override
  String wallsAndAxesGeneratedSuccess(
    int axesCount,
    int wallsCount,
    String unit,
  ) {
    return 'Генерирани $axesCount оси и изолирани $wallsCount стенни контура ($unit)';
  }

  @override
  String get noWallsDetected =>
      'Не са открити двойки стени (20-30 см) в чертежа';

  @override
  String wallCandidatesFound(int pairCount, String length) {
    return 'Открити $pairCount двойки стени ($length м)';
  }

  @override
  String get autoDetectWallsSubtitle =>
      'Открива стени 20-30 см, изолира контурите им в WALLS_250 и чертае осови линии.';

  @override
  String get stripFootingFoundation => 'Ивични основи (Кота ±0.00)';

  @override
  String get matFoundation => 'Фундаментна плоча (Кота ±0.00)';

  @override
  String foundationFootingLabel(int width) {
    return 'Основа • b = $width см';
  }

  @override
  String overheadSlabLabel(String elev) {
    return 'Плоча (+$elev м)';
  }

  @override
  String get bimProjects => 'BiM Проекти';

  @override
  String get bimProjectsSubtitle =>
      'Конструктивни модели и многоетажни чертежи';

  @override
  String get bimProjectLibraryTitle => 'Библиотека с BiM Проекти';

  @override
  String get bimProjectNew => 'Нов BiM Проект';

  @override
  String get bimProjectName => 'Име на проекта';

  @override
  String get bimProjectNameHint => 'напр. Жилищна сграда Флора';

  @override
  String get bimProjectLocation => 'Местоположение / Град';

  @override
  String get bimProjectLocationHint => 'напр. София, България';

  @override
  String get bimProjectStoreysSection => 'Етажи и подложки';

  @override
  String get bimProjectAddUnderlay => 'Зареди подложка';

  @override
  String get bimProjectReplaceUnderlay => 'Смени подложка';

  @override
  String get bimProjectNoUnderlay => 'Няма заредена подложка';

  @override
  String get bimProjectUnderlayFormatError =>
      'Моля, изберете валиден CAD чертеж във формат .dxf, .dwg или .kcad.';

  @override
  String get bimProjectElevation => 'Кота (м)';

  @override
  String get bimProjectHeight => 'Височина (м)';

  @override
  String get bimProjectStoreyName => 'Име на етаж';

  @override
  String get bimProjectQuickSetup => 'Бърза настройка на етажи';

  @override
  String get bimProjectBasementCount => 'Подземни етажи';

  @override
  String get bimProjectAboveGroundCount => 'Надземни етажи';

  @override
  String get bimProjectFloorHeight => 'Етажна височина (м)';

  @override
  String get bimProjectGenerateStoreys => 'Генерирай етажи';

  @override
  String get bimProjectAddStorey => 'Добави етаж';

  @override
  String get bimProjectDeleteStorey => 'Изтрий етаж';

  @override
  String get bimProjectCreateButton => 'Създай проект';

  @override
  String get bimProjectStatusAlignment => 'Чака подравняване';

  @override
  String get bimProjectStatusReady => 'Подравнен • Готов за BiM';

  @override
  String bimProjectStoreysCount(int count) {
    return '$count етажа';
  }

  @override
  String get bimProjectOpen => 'Отвори модела';

  @override
  String get bimProjectAlignStoreys => 'Подравни чертежи';

  @override
  String get bimProjectDeleteConfirmTitle => 'Изтриване на проект?';

  @override
  String bimProjectDeleteConfirmMessage(String name) {
    return 'Сигурни ли сте, че искате да изтриете \"$name\"? Всички конструктивни елементи и чертежи ще бъдат изтрити.';
  }

  @override
  String get bimProjectRename => 'Преименувай';

  @override
  String get bimAlignmentTitle => 'Подравняване на чертежи';

  @override
  String get bimAlignmentInstructions =>
      'Задръжте с пръст, за да поставите водеща контролна точка (напр. пресечката на оси 1 и А) на всяка подложка.';

  @override
  String bimAlignmentControlPointSet(String x, String y) {
    return 'Контролната точка е поставена на ($x, $y)';
  }

  @override
  String get bimAlignmentControlPointMissing => 'Изисква се контролна точка';

  @override
  String get bimAlignmentOnionSkin => 'Сравнение с долен етаж';

  @override
  String get bimAlignmentReadyButton => 'Готов съм • Стартирай BiM';

  @override
  String get bimAlignmentConfirmTitle => 'Потвърждение на подравняването';

  @override
  String get bimAlignmentConfirmMessage =>
      'Всички контролни точки са поставени. BiM модулът ще подравни етажите, ще открие стените и ще генерира оси. Продължаване?';

  @override
  String get bimProjectExportStoreyDxf => 'Експорт на етажния чертеж (DXF)';

  @override
  String get bimProjectExportStoreyDxfSubtitle =>
      'Оригинални координати с показаните и конструктивни слоеве';

  @override
  String get bimProjectExportAllZip => 'Експорт на целия проект (ZIP)';

  @override
  String get bimProjectExportAllZipSubtitle =>
      'Всички етажни чертежи + конструктивен BiM модел';

  @override
  String bimProjectExportSuccess(String filename) {
    return 'Успешен експорт: $filename';
  }

  @override
  String get bimProjectNoProjects =>
      'Все още няма BiM проекти. Натиснете \'+\', за да създадете първия си проект.';

  @override
  String get bimProjectManageStoreys => 'Управление на етажи и подложки';

  @override
  String bimProjectBasement(int num) {
    return 'Сутерен $num';
  }

  @override
  String get bimProjectGroundFloor => 'Партер';

  @override
  String bimProjectFloor(int num) {
    return 'Етаж $num';
  }

  @override
  String get bimProjectSaving => 'Запазване на BiM проект...';

  @override
  String get bimProjectUnderlayAttached => 'Подложката е прикачена';

  @override
  String get bimProjectAlignFirstPrompt =>
      'Моля, подравнете всички етажи преди отваряне на BiM дизайнера.';

  @override
  String get bimProjectLoading => 'Зареждане на BiM проект и подложки...';

  @override
  String get cadThemeDarkCad => 'Тъмен CAD фон';

  @override
  String get cadThemePaperWhite => 'Бяла хартия';

  @override
  String get noSlabLayerDetectedOrEmpty =>
      'Няма открит слой за плоча или слоят е празен';

  @override
  String slabLayerAddedToFilter(String layer) {
    return 'Слоят за плоча \"$layer\" е добавен към конструктивния филтър';
  }

  @override
  String get deleteOpeningPoint => 'Изтрий точка';

  @override
  String get openingPointsMerged => 'Точките на отвора са обединени';

  @override
  String get finePositionTitle => 'Позиция и стъпка';

  @override
  String nudgeStepLabel(String step) {
    return 'Стъпка: $step';
  }

  @override
  String get step1cm => '1 cm';

  @override
  String get step5cm => '5 cm';

  @override
  String get step10cm => '10 cm';

  @override
  String get step25cm => '25 cm';

  @override
  String get coordinateXLabel => 'X (m)';

  @override
  String get coordinateYLabel => 'Y (m)';

  @override
  String clearDistanceDimension(String distance) {
    return 'Светло: $distance m';
  }

  @override
  String axialDistanceDimension(String distance) {
    return 'Ос: $distance m';
  }

  @override
  String get flushFaceAligned => 'Подравнено лице';

  @override
  String get refLineCenter => 'Реф: Център';

  @override
  String get refLineLeft => 'Реф: Ляво лице';

  @override
  String get refLineRight => 'Реф: Дясно лице';

  @override
  String get refLineTitle => 'Референтна линия';

  @override
  String get snapToNearest => 'Прилепи към най-близък';

  @override
  String get alignLeftFace => 'Ляво лице';

  @override
  String get alignRightFace => 'Дясно лице';

  @override
  String get alignTopFace => 'Горно лице';

  @override
  String get alignBottomFace => 'Долно лице';

  @override
  String shearWallRefLineChanged(String line) {
    return 'Референтна линия: $line';
  }

  @override
  String get axisLockAuto => 'Авто';

  @override
  String get axisLockX => '↔ Заключи X';

  @override
  String get axisLockY => '↕ Заключи Y';

  @override
  String get axisLockTitle => 'Ограничение по ос';

  @override
  String get equalSpacing => 'Равни разстояния';

  @override
  String equalSpacingDimension(String distance) {
    return '$distance = $distance m';
  }

  @override
  String get clearDistanceToNeighbors => 'Светъл размер до съседи';

  @override
  String clearDistanceLeft(String name, String dist) {
    return 'До $name (наляво): $dist m';
  }

  @override
  String clearDistanceRight(String name, String dist) {
    return 'До $name (надясно): $dist m';
  }

  @override
  String clearDistanceTop(String name, String dist) {
    return 'До $name (нагоре): $dist m';
  }

  @override
  String clearDistanceBottom(String name, String dist) {
    return 'До $name (надолу): $dist m';
  }

  @override
  String get setClearDistanceAction => 'Светъл размер';

  @override
  String get targetClearDistanceLabel => 'Желан светъл размер (m)';

  @override
  String get applyClearDistance => 'Приложи';

  @override
  String get noNeighborsFound => 'Няма съседни елементи по осите';

  @override
  String get precisionMoveActive => 'Преместване';

  @override
  String get confirmMove => 'Потвърди';

  @override
  String get cancelMove => 'Отказ';

  @override
  String get bimProjectEditElevation => 'Редактиране на кота';

  @override
  String get bimProjectSortStoreys => 'Сортирай по кота';

  @override
  String get bimProjectElevationHelper => 'напр. +2,85, 0,00, -3,20';

  @override
  String get bimProjectInvalidElevation => 'Въведете валидна кота в метри.';

  @override
  String get bimProjectDuplicateElevation => 'Вече има етаж с тази кота.';

  @override
  String get bimProjectConvertingUnderlay => 'Конвертиране на подложка…';

  @override
  String get bimProjectDetectingWallsAndSlabs =>
      'Разпознаване на стени и плочи…';

  @override
  String get bimProjectKcadReady => 'KCAD готов';

  @override
  String get bimProjectConversionFailed => 'Неуспешна конверсия на подложката';

  @override
  String get bimProjectReprocessUnderlay => 'Повторен анализ на подложката';

  @override
  String bimSlabLoggiaCount(int count) {
    return 'От тях предложения за лоджии: $count.';
  }

  @override
  String bimSlabProjectionCount(int count) {
    return 'Външни участъци за преглед (цианено): $count. Видът и нивото още не са потвърдени.';
  }

  @override
  String get bimSlabPreviewTitle => 'Предложения за контур на плоча';

  @override
  String get bimSlabPreviewMissing =>
      'Няма записан анализ на контура. Стартирайте повторен анализ на подложката.';

  @override
  String bimSlabPreviewCount(int count) {
    return 'Предложени контури: $count';
  }

  @override
  String get bimSlabPreviewExplanation =>
      'Оранжевите контури са приблизителни предложения. Червените връзки са предположени отвори, които трябва да проверите; могат да се показват и без получен контур. Включете структурния филтър, за да ги видите. Предложението може да обхваща само част от сградата. Дворове, шахти и стълбищни отвори не са класифицирани. Проверете нивото и ръба на бетона. Не е създадена конструктивна плоча.';

  @override
  String bimSlabPreviewRegions(int regions, int unresolved, int gaps) {
    return 'Анализирани области: $regions; без контур: $unresolved; предположени връзки: $gaps.';
  }

  @override
  String bimSlabPreviewSkipped(int count) {
    return 'Необработени области поради ограничението за обем: $count.';
  }

  @override
  String get bimSlabPreviewEmpty =>
      'Не е получен надежден затворен контур. Възможните причини включват прекъсвания или липсващи стени, нееднозначни връзки, много малки затворени площи или прекалено голям чертеж за текущата разделителна способност.';

  @override
  String get cadLayersTitle => 'CAD Слоеве';

  @override
  String cadLayersVisibleCount(int visible, int total) {
    return '$visible от $total слоя са видими';
  }

  @override
  String get cadLayersShowAll => 'Покажи всички';

  @override
  String get cadLayersHideAll => 'Скрий всички';

  @override
  String get cadLayersLineweightForAll => 'Дебелина за всички:';

  @override
  String get cadLayersSelectForAll => 'Избери за всички...';

  @override
  String get cadLayersUnnamed => 'Неименуван слой';

  @override
  String cadLayersObjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count обекта',
      one: '1 обект',
    );
    return '$_temp0';
  }

  @override
  String get cadLayersFrozen => 'Замразен';

  @override
  String get cadLayersLineweight => 'Дебелина:';

  @override
  String get cadLayersOriginal => 'Оригинална';

  @override
  String cadLayersOriginalWithMm(String mm) {
    return 'Оригинална ($mm мм)';
  }

  @override
  String cadLayersMm(String mm) {
    return '$mm мм';
  }

  @override
  String get bimGenerateSlabs => 'Генерирай начални плочи';

  @override
  String get bimSlabsAlreadyGenerated =>
      'На този етаж вече има генерирани плочи. Редактирайте ги директно; генерирането няма да презапише промените.';

  @override
  String get bimSlabSeedsEmpty =>
      'Няма валидни контури за плочи. Първо обработете основата.';

  @override
  String bimSlabSeedsReview(int count, int skipped, String thickness) {
    return 'Създаване на $count редактируеми плочи на този етаж; пропуснати: $skipped. Дебелина: $thickness cm, от текущата настройка за плоча.\n\nРъбовете се прилепват само при разстояние под 2 cm. Това са начални предложения: проверете контура, отворите, котите и дебелината преди използване в конструктивната схема.';
  }

  @override
  String get seismicNotEvaluated => 'Неоценено';

  @override
  String get seismicModelAssumptions =>
      'Предварителна схема: корава диафрагма, общи фактори за материал и закрепване и опростени тегла. Напукване, взаимодействие на ядра, случаен ексцентрицитет и 3D поведение не са проверени.';

  @override
  String get seismicOpeningNotEvaluated =>
      'Липсва опора или валидна геометрия на отвора; близостта не е оценена.';

  @override
  String seismicConnectionReview(String names) {
    return 'Непроверена връзка с плочата: $names. Частичният контакт или невалидната/твърде сложна геометрия изискват преглед; коравината и ексцентрицитетът не са оценени.';
  }

  @override
  String get seismicInvalidSlabGeometry =>
      'Неоценено: невалиден контур на плоча или отвор. Проверете самопресичанията, отворите извън плочата и допиращите се/припокрити отвори.';

  @override
  String get seismicOverlappingSlabs =>
      'Неоценено: плочите се припокриват. Уточнете геометрията и товарите, за да не се брои масата два пъти.';

  @override
  String seismicSeparateRegions(int count) {
    return 'Открити са $count несвързани области на плочите. Общ център на коравина и ексцентрицитет не са оценени; необходими са отделни диафрагми или модел на връзките.';
  }

  @override
  String get seismicSlabGeometryLimit =>
      'Неоценено: геометрията на плочите надвишава възможностите на предварителната проверка. Нужен е отделен геометричен преглед.';

  @override
  String seismicRegionTitle(int index, int columns, int walls) {
    return 'Област $index · колони: $columns, шайби: $walls';
  }

  @override
  String seismicRegionSharedSupport(String names) {
    return 'Неоценено: обща опора или неясна принадлежност: $names. Необходим е модел на взаимодействието.';
  }

  @override
  String get seismicRegionScope =>
      'Отделни предварителни модели със собствените тегла на плочите и зададените площни товари. Взаимодействието, гредите между областите и вертикалната непрекъснатост не са оценени.';

  @override
  String get seismicLoadsTitle => 'Товари за сеизмичната маса';

  @override
  String get seismicLoadsScope =>
      'Само за предварителния сеизмичен модел. Собственото тегло 25 × h се добавя отделно. Постоянният товар е без него. При изключена настройка: проектните G/Q и дял 0,3. Дялът се задава от конструктора; не се избира автоматично по Еврокод. Вертикалните и конзолните проверки запазват своите товари.';

  @override
  String get seismicLoadPermanent => 'Допълнителен постоянен товар G';

  @override
  String get seismicLoadVariable => 'Полезен товар Q';

  @override
  String get seismicLoadParticipation => 'Дял на Q за масата (0–1)';

  @override
  String get seismicLoadOverride => 'Отделни стойности за тази плоча';

  @override
  String seismicLoadSlab(int index) {
    return 'Плоча $index';
  }

  @override
  String get seismicInvalidMassLoads =>
      'Неоценено: проверете товарите и дебелината. G и Q трябва да са крайни неотрицателни числа, дялът на Q — между 0 и 1, дебелината — положителна.';

  @override
  String get seismicWallContinuityTitle => 'Непрекъснатост на шайбите';

  @override
  String get seismicWallContinuityScope =>
      'Застъпване на сечението с успоредни шайби на предходния етаж в проекта. Под 100% изисква преглед за отместване, скъсяване или прекъсване. Това не е проверка на носимоспособност; насаждане върху греди/колони и фундаментите не са оценени.';

  @override
  String seismicWallContinuityItem(
    String storey,
    String wall,
    String coverage,
  ) {
    return '$storey · $wall: застъпване $coverage';
  }

  @override
  String get seismicElevationAmbiguous =>
      'Вертикалните проверки са неоценени: има еднакви или невалидни коти. Уточнете нивата на етажите.';

  @override
  String get seismicDirectionalScope =>
      'Отношение на предварителната коравина към горния етаж по X/Y. Под 0,70 е сигнал за преглед, а не нормативна присъда. Сравняват се само еднозначно свързани единични области.';

  @override
  String get seismicRegionTrackingTitle => 'Области между етажите';

  @override
  String get seismicLinkUnique => 'еднозначно застъпване';

  @override
  String get seismicLinkBranching => 'разделяне/сливане — преглед';

  @override
  String get seismicLinkAbsent => 'без застъпване — преглед';

  @override
  String seismicRegionTrackingItem(
    String storey,
    int region,
    String lower,
    String matches,
    String coverage,
    String status,
  ) {
    return '$storey, област $region → $lower, области $matches: $coverage; $status. Геометрична връзка, не доказан път на усилията.';
  }

  @override
  String get ceilingSlabTitle => 'Плоча над етажа';

  @override
  String ceilingSlabContext(String level) {
    return 'Архитектурна основа $level · изглед нагоре';
  }

  @override
  String get ceilingExplicitLevel => 'Задай горна конструктивна кота';

  @override
  String get ceilingConcreteTop => 'Горен ръб бетон';

  @override
  String ceilingSlabLevels(String top, String bottom) {
    return 'Горен ръб $top m · долен ръб $bottom m';
  }

  @override
  String get ceilingSlabLevelHint =>
      'Без зададена кота: основа + височина − настилка. Зададената кота е за бетон и настилка не се изважда повторно. Промяната на дебелината запазва горния ръб.';

  @override
  String get ceilingSlabInvalid =>
      'Въведете крайни числа, положителна дебелина и долен ръб над котата на основата.';

  @override
  String get slabEdgeOffset => 'Отместване на ръб';

  @override
  String get slabEdgeNumber => 'Ръб';

  @override
  String get slabEdgeDistance => 'Отместване (cm)';

  @override
  String get slabEdgeHint =>
      'Положително: навън. Отрицателно: навътре. Общият ръб се мести и в съседната плоча.';

  @override
  String get slabEdgeInvalid =>
      'Корекцията създава невалиден контур или засяга частично общ ръб. Разделете общата граница на съвпадащи ръбове.';

  @override
  String get cleanSlabContour => 'Почисти контура';

  @override
  String get cleanSlabContourTooltip =>
      'Премахни излишни точки и поправи артефакти';

  @override
  String slabContourCleaned(int count) {
    return 'Контурът на плочата е почистен (премахнати $count излишни точки)';
  }

  @override
  String get slabContourAlreadyClean =>
      'Контурът на плочата вече е чист и оптимален';

  @override
  String get openingNoSlab => 'Първо създайте плочата над етажа.';

  @override
  String get openingInvalidPlacement =>
      'Отворът трябва да е изцяло в една плоча, без да докосва контура или друг отвор.';

  @override
  String get openingAmbiguousOwner =>
      'Повече от една плоча обхваща отвора. Коригирайте застъпването на плочите.';

  @override
  String get openingMissing => 'Избраният отвор вече не съществува.';

  @override
  String get schemeReadinessTitle => 'Проверка преди генериране';

  @override
  String get schemeGeometryReady =>
      'Плочите и стълбището са геометрично готови.';

  @override
  String get schemeReadinessHint =>
      'Това проверява входните обекти. Не генерира колони и шайби и не е конструктивна оценка.';

  @override
  String get schemeEditing => 'Завършете текущата редакция на плочата.';

  @override
  String get schemeMissingStairs =>
      'Поставете отвор от тип „Стълбище“ в покриващата плоча. Асансьорът е допълнителен.';

  @override
  String get schemeAmbiguousLevels =>
      'Етажът или плочата нямат еднозначна принадлежност. Проверете повторени коти и идентификатори.';

  @override
  String get schemeInvalidLevel =>
      'Проверете котата и дебелината на покриващата плоча: долният бетон трябва да е над основата на етажа.';

  @override
  String get schemeInvalidGeometry =>
      'Има невалидна плоча или отвор. Проверете самопресичанията, ръбовете и застъпването на отворите.';

  @override
  String get schemeOverlappingSlabs =>
      'Плочите се застъпват. Коригирайте контурите преди генериране.';

  @override
  String get schemeComputationLimit =>
      'Контурите са твърде сложни за тази проверка. Опростете ги.';

  @override
  String get schemeCeilingLabel => 'Плоча';

  @override
  String get schemeRegionsLabel => 'Отделни области';

  @override
  String get schemeGenerate => 'Предложи колони и шайби';

  @override
  String get schemePreview => 'Начална конструктивна схема';

  @override
  String get schemeVariantCore => 'Вариант 1 · около стълбището';

  @override
  String get schemeVariantLong => 'Вариант 2 · по дългите стени';

  @override
  String get schemeMinSpacing => 'Минимална стъпка (m)';

  @override
  String get schemeTargetSpacing => 'Целева стъпка (m)';

  @override
  String get schemeRebuild => 'Обнови вариантите';

  @override
  String get schemeConfirm => 'Потвърждавам показаните контури и отвори';

  @override
  String get schemeAccept => 'Приеми предложението';

  @override
  String get schemeNoWalls =>
      'Няма разпознати непрекъснати стени. Първо изпълнете разпознаването на стените.';

  @override
  String get schemeNoCandidates =>
      'Няма свободни подходящи позиции. Съществуващите елементи са запазени.';

  @override
  String get schemeLimits =>
      'Достигнат е лимитът за тази предварителна схема. Нужен е ръчен преглед на останалите участъци.';

  @override
  String get schemePreliminary =>
      'Размерите са текущо избраните сечения. Стъпките са настройки за подреждане, не допустими изчислени отвори. Проверете излизането на сеченията извън архитектурните стени.';

  @override
  String get schemeLegend =>
      'Сиво: съществуващи · Синьо: плочи · Зелено: нови колони · Оранжево: нови шайби · Червено: отвори';

  @override
  String get schemeUnresolved =>
      'Области без шайби и в двете основни направления';

  @override
  String get schemeRejected => 'Отхвърлени кандидати';

  @override
  String get schemeReport => 'Подробна оценка';

  @override
  String get schemeInvalidOptions =>
      'Въведете положителни стъпки; целевата трябва да е поне минималната.';

  @override
  String get schemeStale =>
      'Проектът е променен. Отворете нов преглед преди приемане.';

  @override
  String get schemeComparison =>
      'Сравнение на вариантите · eX/eY (m) · насадени колони';

  @override
  String get schemeFresh =>
      'Приемат се само новите обекти. Ръчните елементи и приетите редакции се запазват.';
}
