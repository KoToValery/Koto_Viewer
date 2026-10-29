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
  String get back => 'Назад';

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
  String closeOpening(int count) {
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
  String get snapOpeningEdge => 'Ръб на отвор';

  @override
  String get snapOpeningCenter => 'Център на отвор';

  @override
  String get snapModuleStep => 'Модулна стъпка';

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
  String get openingPointByPointPrompt => 'Поставяйте точки на отвора със снап';

  @override
  String get staircase2PointPrompt =>
      'Докоснете 1-ви ъгъл, след това 2-ри за стълбище';

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
  String get shaftOpeningLabel => 'Шахта';

  @override
  String get elevatorOpeningLabel => 'Асансьор';

  @override
  String get stairsOpeningLabel => 'Стълбище';

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
    return 'Ориентир в приложението: 1.0% площ на свързаните шайби във всяко направление спрямо нетна етажна площ ($area m²). Това не е универсален минимум по Еврокод 8 или доказателство за сеизмична носимоспособност.';
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
    return 'Таванна плоча над $storey';
  }

  @override
  String get verticalSlabStatusOk => 'В норма';

  @override
  String get verticalSlabStatusEnlarge => 'Препоръчва се уголемяване';

  @override
  String get verticalSlabStatusUnknown => 'Неопределено';

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
  String get bimMeasureGestureHint =>
      'Плъзни за навигация · Докосни за точка · Задръж за прецизност · 2 пръста за мащаб';

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
  String get ceilingSlabTitle => 'Таванна плоча над етажа';

  @override
  String ceilingSlabContext(String level) {
    return 'Етаж $level · таванна плоча над етажа';
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
      'Плочата и отворите са над активния етаж. Ниво на бетона: кота на следващия етаж − настилка; за последния етаж: кота + височина − настилка. Зададената кота е за бетон.';

  @override
  String get ceilingSlabInvalid =>
      'Въведете положителна дебелина и кота, при която плочата е над активния етаж и не надвишава следващото ниво.';

  @override
  String get overheadSlabTag => 'Плоча над етажа (таван)';

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
  String get schemeMinSpacing => 'Мин. стъпка между колони (m)';

  @override
  String get schemeTargetSpacing => 'Целева стъпка (m)';

  @override
  String get schemeRebuild => 'Следващ вариант';

  @override
  String get schemeConfirm => 'Потвърждавам показаните контури и отвори';

  @override
  String get schemeAccept => 'Приеми предложението';

  @override
  String get schemeNoWalls =>
      'Няма разпознати плътни стенни участъци. Осите сами по себе си не разрешават колони в помещенията.';

  @override
  String get schemeNoCandidates =>
      'Няма свободни подходящи позиции. Съществуващите елементи са запазени.';

  @override
  String get schemeLimits =>
      'Достигнат е лимитът за тази предварителна схема. Нужен е ръчен преглед на останалите участъци.';

  @override
  String get schemePreliminary =>
      'Автоматичните размери отчитат свободния стенен участък и предварителните проверки за натиск/продънване. Избраните сечения са начални размери при включена адаптация. Размерите, пътят на товарите и армировката изискват потвърждение с конструктивен модел.';

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
      'Въведете положителни размери и стъпки. Целевата стъпка трябва да е поне минималната, а максималната шайба — поне началната дължина.';

  @override
  String get schemeStale =>
      'Проектът е променен. Отворете нов преглед преди приемане.';

  @override
  String get schemeComparison => 'Преди → след';

  @override
  String get schemeFresh =>
      'Приемат се само новите обекти. Ръчните елементи и приетите редакции се запазват.';

  @override
  String get schemePairedWalls =>
      'Предпочитай разпределени шайби по двете направления';

  @override
  String get schemeGenerousDensity =>
      'Допълнителна плътност на опорите (по избор)';

  @override
  String get toggleGroundFoundations => 'Показване на основи (±0.00)';

  @override
  String get schemeVariant => 'Вариант';

  @override
  String get schemeNoAlternative =>
      'Не е намерен нов различен вариант в текущото търсене. Променете отстоянията или опитайте отново.';

  @override
  String get schemeCoverage =>
      'Червени точки: разстояние над половината от целевата стъпка / максимално разстояние до опора';

  @override
  String get schemeEurocodeScope =>
      'Геометрична предварителна проверка. Разстоянието до опора не е изчислен отвор или провисване. За проверка по EC2 са нужни статическа схема, товари, материали и армировка; докладът за EC8 съдържа само предварителни показатели.';

  @override
  String get schemeSpanUnknown => 'Подпорното разстояние е неопределено';

  @override
  String get schemeSupportSpan =>
      'Критично подпорно разстояние (предварително)';

  @override
  String get schemeOpeningFallback =>
      'Лилаво: резервни колони във врати/прозорци — проверете отвора';

  @override
  String get schemeAdaptiveSizes =>
      'Адаптирай сеченията към стените и предварителните проверки';

  @override
  String get schemeWallDensity =>
      'Площ на свързаните шайби / нетна етажна площ (ориентир 1%)';

  @override
  String get schemeWallDeficit =>
      'Оставащ недостиг на площ на шайбите — ограничения на разполагането';

  @override
  String get schemeResizedColumns => 'Колони с адаптирани сечения';

  @override
  String get schemeSizingReview =>
      'Сечения за преглед: натоварване или продънване над предварителната цел';

  @override
  String get schemePlacementReasons => 'Отхвърлени позиции';

  @override
  String get schemeWallConstraint => 'побиране в стена';

  @override
  String get schemeSlabConstraint => 'плоча / отвор';

  @override
  String get schemeSpacingConstraint => 'отстояние / застъпване';

  @override
  String get schemeMaxWallLength => 'Макс. дължина на нова шайба (m)';

  @override
  String get schemeWallSections => 'Шайби — дебелина × дължина';

  @override
  String schemeContinueLower(String level) {
    return 'Продължаване на схемата от кота $level. Позициите и сеченията се запазват. Нерешените разстояния и недостигът на шайби изискват преработка на долната схема.';
  }

  @override
  String get schemeContinuityReview =>
      'Има ръчно поставени опори, които не съвпадат със схемата отдолу. Прегледайте вертикалната непрекъснатост.';

  @override
  String schemeBlockedContinuations(int count) {
    return 'Опори, които не могат да се продължат: $count. Червените точки показват местата за преглед.';
  }

  @override
  String spanFeedbackCount(int count) {
    return 'Проблемни връзки: $count';
  }

  @override
  String get spanFeedbackScope => 'Предварително · по зададената дебелина';

  @override
  String spanFeedbackUnknown(int count) {
    return 'Връзки без валидна дебелина: $count';
  }

  @override
  String get bimClearStructure => 'Изчисти конструкцията — всички етажи';

  @override
  String bimClearStructureConfirm(int count) {
    return 'Ще бъдат изтрити $count колони и шайби от всички етажи. Плочите, гредите и осите се запазват. Действието може да се върне с Undo.';
  }

  @override
  String bimDeleteStoreyConfirm(String level) {
    return 'Изтриване на етаж $level и неговите конструктивни елементи?';
  }

  @override
  String bimUnderlayReviewNeeded(String levels) {
    return 'Данните на подложката са променени на $levels. Провери запазените конструктивни елементи и отвори.';
  }

  @override
  String bimFloorSlabReference(String level, String owner) {
    return 'Подова плоча на $level — таван на етажа $owner';
  }

  @override
  String get bimEditFloorSlab => 'Редактирай плочата';

  @override
  String schemeSearchSummary(int layouts, int changes, int evaluations) {
    return 'Сравнени схеми: $layouts · приети промени: $changes · оценки: $evaluations';
  }

  @override
  String schemeFieldSummary(int count, int review) {
    return 'Затворени полета: $count · за преглед: $review';
  }

  @override
  String get schemeUnresolvedFieldArea =>
      'Площ с неустановено подпиране на полетата';

  @override
  String get schemeOpeningSupportReview =>
      'Подпиране около отвори: точки за преглед';

  @override
  String get schemeBoundarySupportReview =>
      'Конзоли или неустановено подпиране по ръба';

  @override
  String get schemeContinuityIssues => 'Проблеми с вертикалната непрекъснатост';

  @override
  String get schemeConcreteVolume => 'Обем бетон на опорите';

  @override
  String get schemeBalanceIndex =>
      'Предварителен индекс за усукване (по-нисък е по-добре)';

  @override
  String get schemeNoWallConstraint => 'Няма подходяща стена';

  @override
  String get schemeCollisionConstraint => 'Колизия на сечения';

  @override
  String get schemeColumnSpacingConstraint => 'Стъпка между колони';

  @override
  String get schemeWallSpacingConstraint => 'Стъпка между шайби';

  @override
  String get schemeBudgetConstraint => 'Бюджет за разполагане';

  @override
  String get schemeLimitInput => 'Лимит на входните данни';

  @override
  String get schemeLimitSampling => 'Лимит на геометричните проби';

  @override
  String get schemeLimitJunctions => 'Лимит на стенните възли';

  @override
  String get schemeLimitElements => 'Лимит на броя опори';

  @override
  String get schemeLimitFields => 'Лимит на топологията на полетата';

  @override
  String get schemeLimitOptimization =>
      'Достигнат е бюджетът за локално търсене; оптималност не е установена';

  @override
  String get schemeStageCore => 'Ядро';

  @override
  String get schemeStageWalls => 'Разпределени шайби';

  @override
  String get schemeStageColumns => 'Колонни възли';

  @override
  String get schemeStageCoverage => 'Покритие';

  @override
  String get schemeStageRepair => 'Поправка на полетата';

  @override
  String get schemeStageOpenings => 'Преглед на архитектурните отвори';

  @override
  String get schemePunchingGeometryReview =>
      'Геометрията за продънване или прехвърлянето на товара към гредите изисква преглед';

  @override
  String get schemeInteriorColumn => 'Вътрешна колона';

  @override
  String get schemeEdgeColumn => 'Крайна колона';

  @override
  String get schemeCornerColumn => 'Ъглова колона';

  @override
  String get schemeUnknownColumnPosition =>
      'Неустановено положение на колоната';

  @override
  String get schemeSearchNoImprovement =>
      'Търсенето запази най-добрия оценен начален вариант';

  @override
  String get schemeMinWallSpacing => 'Мин. стъпка между успоредни шайби (m)';

  @override
  String get schemeUnavailableChecks => 'Неустановени проверки';

  @override
  String get schemeSeedDensityConstraint => 'Пропуснати в по-редкия вариант';

  @override
  String get floorSlabTitle => 'Подова плоча на тази кота';

  @override
  String floorSlabContext(String level) {
    return 'Под на кота $level · редакция на нейната кота';
  }

  @override
  String get floorSlabLevelHint =>
      'Плочата принадлежи на тази кота и се показва като таван на непосредствено по-ниската кота.';

  @override
  String bimCeilingSlabReference(String owner) {
    return 'Таванна плоча · под на кота $owner';
  }

  @override
  String gridAxisSourceLevels(String levels) {
    return 'Коти: $levels';
  }

  @override
  String get staircaseSetupTitle => 'Стълбища по нива';

  @override
  String get staircaseSetupHint =>
      'Задайте началото и последното ниво на пристигане на всяко стълбище. Очертайте зоната за преминаване по нивата и отвора в подовете на пристигане. Началният под и покривът могат да останат плътни.';

  @override
  String get staircaseNoStairs => 'Сградата няма стълбища';

  @override
  String get staircaseAdd => 'Добави стълбище';

  @override
  String get staircaseStart => 'Начално ниво';

  @override
  String get staircaseEnd => 'Последно ниво на пристигане';

  @override
  String get staircaseZone => 'Зона за преминаване';

  @override
  String get staircaseZoneHint =>
      'Очертайте рамената, площадките и прохода. Полигонът запазва място за стълбата и не изрязва плочата. Затворете полигона, за да го запазите.';

  @override
  String get staircaseDrawZone => 'Очертай зона';

  @override
  String get staircaseDrawOpening => 'Очертай отвор в пода';

  @override
  String get staircaseDetect => 'Открий стълбище';

  @override
  String get staircaseReviewMissing =>
      'Проверете нивата на стълбищата преди генериране на опори.';

  @override
  String get staircaseScopeMissing =>
      'Проверете началото и последното ниво на пристигане.';

  @override
  String get staircaseZoneMissing =>
      'Липсва или е невалидна зоната за преминаване';

  @override
  String get staircaseOpeningMissing =>
      'Липсва съответстващ стълбищен отвор в пода на пристигане';

  @override
  String get staircaseOpeningReady => 'Отворът в пода е намерен';

  @override
  String get staircaseZoneReady => 'Зоната е очертана';

  @override
  String get staircaseDetectionTitle => 'Предложения за стълбище';

  @override
  String get staircaseDetectionHint =>
      'Повтарящите се линии подсказват рамена, но не определят точния отвор в плочата. Прегледайте геометрията и очертайте отвора на етажа на пристигане.';

  @override
  String get staircaseDetectionEmpty =>
      'Не е намерена надеждна поредица от стъпала. Очертайте зоната ръчно или проверете долния етаж.';

  @override
  String get staircaseUseZone => 'Приеми като зона за преминаване';

  @override
  String get staircaseDetectionPartial =>
      'Предложение за рамо; проверете площадките и прохода';

  @override
  String get staircaseLimit =>
      'Чертежът е твърде голям за пълно геометрично търсене. Използвайте ръчно очертаване.';

  @override
  String get staircaseInvalidZone =>
      'Полигонът за преминаване е невалиден. Коригирайте точките.';

  @override
  String get staircaseWinder => 'Завиващо рамо';

  @override
  String staircaseEvidenceFromLevel(String level) {
    return 'Стъпала от $level; съпоставете с този етаж.';
  }

  @override
  String get staircaseSupportConflict =>
      'Съществуващи опори навлизат в зоната на стълбата. Преместете ги или коригирайте зоната.';

  @override
  String staircaseCloseZone(int count) {
    return 'Запази зоната ($count точки)';
  }

  @override
  String get staircaseUseOpening => 'Прегледай контура на отвора';

  @override
  String staircaseArms(int count) {
    return '$count рамена';
  }

  @override
  String get architectStudio => 'Architect Studio';

  @override
  String get architectStudioSubtitle => '3D Идеен проект, стени, врати и етажи';

  @override
  String get architectNewProject => 'Нов архитектурен проект';

  @override
  String get architectProjectName => 'Име на проект';

  @override
  String get architectProjectNameHint => 'напр. Вила Алфа';

  @override
  String get architectUnits => 'Мерни единици';

  @override
  String get architectUnitMeters => 'Метри (m)';

  @override
  String get architectUnitCm => 'Сантиметри (cm)';

  @override
  String get architectStoreys => 'Етажност';

  @override
  String get architectStoreyCount => 'Брой етажи';

  @override
  String get architectStoreyHeight => 'Етажна височина (m)';

  @override
  String get architectGroundHeight => 'Височина на партер (m)';

  @override
  String get architectDynamicGridAxes => 'Динамични координатни оси';

  @override
  String get architectGridAxesX => 'Оси по X';

  @override
  String get architectGridAxesY => 'Оси по Y';

  @override
  String get architectGridSpacingX => 'Разстояние X (m)';

  @override
  String get architectGridSpacingY => 'Разстояние Y (m)';

  @override
  String get architectCategoryPlan => 'План';

  @override
  String get architectCategoryBuild => 'Строеж';

  @override
  String get architectCategoryDrawing => 'Чертане';

  @override
  String get architectToolCategories => 'Категории';

  @override
  String get architectToolSelect => 'Избор';

  @override
  String get architectToolWall => 'Стена';

  @override
  String get architectToolDoor => 'Врата';

  @override
  String get architectToolMeasure => 'Измерване';

  @override
  String get architectWallThickness => 'Деб.';

  @override
  String get architectWallSingle => 'Една';

  @override
  String get architectWallChained => 'Свързани';

  @override
  String get architectFinishChained => 'Край';

  @override
  String get architectDoorWidth => 'Шир.';

  @override
  String get architectDoorHeight => 'Вис.';

  @override
  String get architectDoorSill => 'Праг (h)';

  @override
  String get architectDoorHingeLeft => 'Лява';

  @override
  String get architectDoorHingeRight => 'Дясна';

  @override
  String get architectDoorSwingIn => 'Навътре';

  @override
  String get architectDoorSwingOut => 'Навън';

  @override
  String get architectDoorSelectWallPrompt =>
      'Докоснете стена, за да поставите вратата';

  @override
  String get architectDoorSpecId => 'Марка (ID)';

  @override
  String get architectDoorHingeSide => 'Панти';

  @override
  String get architectDoorSwingDirection => 'Отваряне';

  @override
  String get architectDoorFlipSwing => 'Обръщане навътре/навън';

  @override
  String get architectDoorFlipHinge => 'Обръщане на пантите (лява/дясна)';

  @override
  String get architectWallDrawPrompt =>
      'Докоснете за начало, докоснете отново за край на стената';

  @override
  String get architectView2D => '2D План';

  @override
  String get architectView3D => '3D Модел';

  @override
  String get architectResetView => 'Центрирай';

  @override
  String get architectCreateProject => 'Създай проект';

  @override
  String get architectToolZone => 'Зони';

  @override
  String get architectZoneDragPrompt => 'Изтеглете с влачене за нова зона';

  @override
  String get architectZoneDrawPrompt => 'Точки → затвори';

  @override
  String get architectZoneTapFirstPoint =>
      'Докоснете за поставяне на първа точка (1)';

  @override
  String architectZoneNextPointPrompt(int count) {
    return 'Точка $count: Докоснете за следваща точка или изберете 1 за затваряне';
  }

  @override
  String get architectZoneClose => 'Готово';

  @override
  String get architectZoneUndoPoint => 'Отмени точка';

  @override
  String get architectZoneCancelDraft => 'Отказ';

  @override
  String get architectZonePointSnapStart => 'Затваряне на зона (1-ва точка)';

  @override
  String get architectZoneSelfIntersectError =>
      'Невалиден полигон с пресичащи се страни';

  @override
  String get architectZoneMinPointsError => 'Зоната трябва да има поне 3 точки';

  @override
  String architectZoneExtrudeOffset(String dist) {
    return 'Изтеглена отсечка: $dist m';
  }

  @override
  String architectZoneCleaned(int count) {
    return 'Премахнати $count излишни / сираци точки';
  }

  @override
  String architectZonePointsCount(int count) {
    return 'Точки: $count';
  }

  @override
  String get architectZoneAlignH => 'Изправена 0°';

  @override
  String get architectZoneAlignV => 'Изправена 90°';

  @override
  String architectZoneCreated(String name, String area) {
    return 'Зона $name ($area m²) създадена';
  }

  @override
  String get architectZoneDeleted => 'Зоната е изтрита';

  @override
  String get architectZoneMerged => 'Точките са обединени';

  @override
  String get architectZoneProperties => 'Свойства на зоната';

  @override
  String get architectZoneName => 'Име на помещение';

  @override
  String get architectZoneCategory => 'Категория';

  @override
  String get architectZoneTargetArea => 'Целева площ';

  @override
  String get architectZoneAreaLabel => 'Площ';

  @override
  String get architectZonePerimeterLabel => 'Периметър';

  @override
  String get architectDeleteZone => 'Изтрий зона';

  @override
  String get architectZoneAutoAlign => 'Изправи ъгли (90°)';

  @override
  String get architectZoneUndoAlign => 'Откажи изправянето';

  @override
  String get architectZoneAutoAlignSuccess => 'Ъглите са изправени на 90°';

  @override
  String get architectZoneRotate => 'Ротация';

  @override
  String get architectZoneMove => 'Премести зона';

  @override
  String get architectZoneOffset => 'Отместване';

  @override
  String get architectZoneSave => 'Запази';

  @override
  String get architectZoneCancel => 'Откажи';

  @override
  String get architectZoneEditMode => 'Корекция на зона';

  @override
  String get architectZoneUndoAction => 'Отмени';

  @override
  String get architectZoneRedoAction => 'Повтори';

  @override
  String architectZoneMovedDistance(String dist) {
    return 'Преместено: $dist м';
  }

  @override
  String get architectZoneQuickRect => 'Правоъгълник';

  @override
  String get architectZoneQuickPoly => 'Свободен полигон';

  @override
  String get architectZoneNumber => '№ на помещение';

  @override
  String get architectZoneNumberPrompt => '№';

  @override
  String get architectZoneFinishes => 'Финишни покрития';

  @override
  String get architectZoneFloorFinish => 'Под / Настилка';

  @override
  String get architectZoneWallFinish => 'Стени';

  @override
  String get architectZoneCeilingFinish => 'Таван';

  @override
  String get architectZoneClearHeight => 'Светла височина (m)';

  @override
  String get architectZoneBoundaryAuto => 'Динамични граници';

  @override
  String get architectZoneBoundaryAutoDesc =>
      'Динамично изменяне при промяна на стените';

  @override
  String get architectZoneBoundaryManual => 'Ръчна корекция';

  @override
  String get architectZoneBoundaryManualDesc =>
      'Фиксирани граници без динамично изменяне';

  @override
  String get architectZoneModeAuto => 'Авто';

  @override
  String get architectZoneModeManual => 'Ръчна';

  @override
  String get architectZoneAutoPrompt =>
      'Кликнете в готово помещение за автоматично разпознаване';

  @override
  String get architectZoneAutoFailed =>
      'Помещението не е напълно затворено от стени';

  @override
  String get architectZoneMergeDialogTitle => 'Обединяване на помещения';

  @override
  String architectZoneMergeDialogMessage(String zoneA, String zoneB) {
    return 'Стената между \"$zoneA\" и \"$zoneB\" беше премахната. Желаете ли да ги обедините в едно общо помещение?';
  }

  @override
  String get architectZoneMergeConfirm => 'Обедини';

  @override
  String get architectZoneMergeKeepSeparate => 'Запази отделни';

  @override
  String architectZoneMergedSuccess(String name) {
    return 'Помещенията са обединени в $name';
  }

  @override
  String get architectZoneScheduleTitle => 'Таблица на помещенията';

  @override
  String get architectZoneScheduleTotalArea => 'Обща чиста площ';

  @override
  String get architectZoneScheduleRoomCount => 'Брой помещения';

  @override
  String get architectZoneSchedulePlaceOnDrawing => 'Постави на чертежа';

  @override
  String get architectZoneScheduleRemoveFromDrawing => 'Премахни от чертежа';

  @override
  String get architectZoneScheduleTablePlaced =>
      'Таблицата е поставена на чертежа';

  @override
  String get architectZoneScheduleCopy => 'Копирай таблица';

  @override
  String get architectZoneScheduleCopied =>
      'Таблицата на помещенията е копирана';

  @override
  String get architectZoneScheduleNoRooms =>
      'Няма създадени зони в текущия етаж';

  @override
  String get architectZoneScheduleColNo => '№';

  @override
  String get architectZoneScheduleColName => 'Помещение';

  @override
  String get architectZoneScheduleColArea => 'Площ (m²)';

  @override
  String get architectZoneScheduleColPerimeter => 'Обик. (m)';

  @override
  String get architectZoneScheduleColFloor => 'Под';

  @override
  String get architectZoneScheduleColWalls => 'Стени';

  @override
  String get architectZoneScheduleColCeiling => 'Таван';

  @override
  String get architectZoneScheduleColHeight => 'H (m)';

  @override
  String get architectToolZoneTable => 'Таблица зони';

  @override
  String get architectToolZoneTableTooltip =>
      'Поставяне на таблица с помещенията върху чертежа';

  @override
  String get architectZoneTableBarTitle => 'Таблица на помещенията';

  @override
  String get architectZoneTableBarHint =>
      'Кликнете върху чертежа, за да поставите таблицата';

  @override
  String get architectZoneTableBarMoveHint =>
      'Влачете таблицата по чертежа за преместване';

  @override
  String get architectZoneTablePlaced => 'Таблицата е поставена върху чертежа';

  @override
  String get architectZoneTableRemoved => 'Таблицата е премахната от чертежа';

  @override
  String get architectZoneTableRemove => 'Премахни таблица';

  @override
  String get architectZoneTableBackToZones => 'Към помещенията';

  @override
  String get architectZoneTableActionPlace => 'Постави таблица';

  @override
  String get architectZoneFloorLaminate => 'Ламинат';

  @override
  String get architectZoneFloorGranite => 'Гранитогрес';

  @override
  String get architectZoneFloorTerracotta => 'Теракота';

  @override
  String get architectZoneFloorParquet => 'Паркет';

  @override
  String get architectZoneFloorCarpet => 'Мокет';

  @override
  String get architectZoneFloorConcrete => 'Шлайфан бетон';

  @override
  String get architectZoneWallLatex => 'Латекс';

  @override
  String get architectZoneWallFaience => 'Фаянс';

  @override
  String get architectZoneWallPlaster => 'Декор. мазилка';

  @override
  String get architectZoneWallWallpaper => 'Тапети';

  @override
  String get architectZoneWallExposedBrick => 'Видима тухла';

  @override
  String get architectZoneCeilingLatex => 'Латекс';

  @override
  String get architectZoneCeilingGypsum => 'Гипсокартон';

  @override
  String get architectZoneCeilingSuspended => 'Окачен таван';

  @override
  String get architectZoneCeilingConcrete => 'Видим бетон';

  @override
  String get staircaseAutoGenerate => 'Генерирай отвори за стълби';

  @override
  String staircaseAutoAdded(int count) {
    return 'Добавени отвори за стълби: $count';
  }

  @override
  String get staircaseAutoExisting => 'Отворите за стълби вече са поставени.';

  @override
  String get staircaseAutoNotFound =>
      'Не е открит отвор. Очертай го с инструмента „Стълбище“.';

  @override
  String staircaseAutoMissing(String levels) {
    return 'Липсва отвор за стълби на кота $levels.';
  }

  @override
  String get bimToolGroupUnderlay => 'Подложка';

  @override
  String get bimToolGroupStructure => 'Конструкция';

  @override
  String get bimToolGroupChecks => 'Проверки';

  @override
  String get bimGenerateSupportsAction => 'Генерирай колони и шайби';

  @override
  String get bimSupportSpacingAction => 'Разстояния';

  @override
  String get architectToolAxis => 'Оси';

  @override
  String get architectAxisDrawPrompt =>
      'Докоснете начало и край за нова осова линия';

  @override
  String get architectAxesResequenced => 'Осите са преномерирани успешно';

  @override
  String get architectAxesAligned => 'Осите са подравнени';

  @override
  String get architectAxisAligned => 'Оста е подравнена спрямо успоредните оси';

  @override
  String architectAxisRenamed(String name) {
    return 'Оста е преименувана на $name';
  }

  @override
  String get resequenceGridAxesAction => 'Преномерирай осите';

  @override
  String get alignGridAxesAction => 'Подравни осите';

  @override
  String get alignGridAxisAction => 'Подравни';

  @override
  String get architectAxisOrientationV => 'Вертикална';

  @override
  String get architectAxisOrientationH => 'Хоризонтална';

  @override
  String get architectAxisDeleted => 'Оста е изтрита';

  @override
  String get architectAxisMoved => 'Оста е преместена';

  @override
  String get architectDebugLogs => 'Диагностичен лог';

  @override
  String get architectClearLogs => 'Изчисти';

  @override
  String get architectCopyLogs => 'Копирай';

  @override
  String get architectNoLogs => 'Няма записани логове';

  @override
  String architectDoorPlaced(String specId, int width, int height) {
    return 'Врата $specId ($width/$height) поставена';
  }

  @override
  String get bimProjectType => 'Тип на проекта';

  @override
  String get bimProjectStructural => 'Конструктивен BiM';

  @override
  String get bimProjectArchitectural => 'Архитектурен BiM';

  @override
  String get bimProjectStructuralDesc =>
      'Носещи елементи, колони, греди, шайби, плочи, сеизмичен анализ и носимоспособност';

  @override
  String get bimProjectArchitecturalDesc =>
      'Стени, врати, прозорци, помещения, стълби, пълно архитектурно чертане';

  @override
  String get bimProjectFilterAll => 'Всички';

  @override
  String get bimProjectFilterStructural => 'Конструктивни';

  @override
  String get bimProjectFilterArchitectural => 'Архитектурни';

  @override
  String get architectToolWindow => 'Прозорец';

  @override
  String get architectToolColumn => 'Колона';

  @override
  String get architectToolBeam => 'Греда';

  @override
  String get architectToolSlab => 'Плоча';

  @override
  String get architectToolOpening => 'Отвор';

  @override
  String get architectToolStair => 'Стълби';

  @override
  String get architectToolDimension => 'Размери';

  @override
  String get architectToolLevel => 'Кота';

  @override
  String get architectToolText => 'Текст';

  @override
  String get architectToolCadLine => 'Линия';

  @override
  String get architectToolCadRect => 'Правоъгълник';

  @override
  String get architectToolCadCircle => 'Окръжност';

  @override
  String get architectWindowWidth => 'Шир.';

  @override
  String get architectWindowHeight => 'Височина';

  @override
  String get architectWindowSill => 'Подпр.';

  @override
  String get architectWindowFlipSide => 'Обръщане на външна/вътрешна страна';

  @override
  String get architectColumnShape => 'Форма';

  @override
  String get architectColumnRect => 'Правоъг.';

  @override
  String get architectColumnCircle => 'Кръгла';

  @override
  String get architectColumnSize => 'Размер';

  @override
  String get architectBeamSize => 'Размер';

  @override
  String get architectStairWidth => 'Шир.';

  @override
  String get architectStairSteps => 'Стъпала';

  @override
  String get architectOpeningType => 'Тип';

  @override
  String get architectOpeningShaft => 'Шахта';

  @override
  String get architectOpeningVoid => 'Плоча';

  @override
  String get architectLevelElevation => 'Кота';

  @override
  String get architectAnnotationText => 'Текст';

  @override
  String get architectUnderlayToggle => 'CAD Подложка';

  @override
  String architectWindowPlaced(String specId, int width, int height) {
    return 'Прозорец $specId ($width/$height) поставен';
  }

  @override
  String architectColumnPlaced(String label) {
    return 'Колона $label поставена';
  }

  @override
  String get architectBeamPlaced => 'Греда поставена';

  @override
  String get architectStairPlaced => 'Стълбище поставено';

  @override
  String get architectOpeningPlaced => 'Отвор поставен';

  @override
  String get architectDimensionPlaced => 'Размерна линия поставена';

  @override
  String get architectLevelPlaced => 'Нивова кота поставена';

  @override
  String get architectAnnotationPlaced => 'Анотация поставена';

  @override
  String get architectCadShapePlaced => 'CAD фигура поставена';

  @override
  String get architectCategoryStructure => 'Конструкция';

  @override
  String get architectCategorySpaces => 'Пространства';

  @override
  String get architectCategoryAnnotations => 'Надписи';

  @override
  String get architectCategoryCad => 'CAD Чертане';

  @override
  String selectedElement(String id) {
    return 'Избран: $id';
  }

  @override
  String get architectWizardTitle => 'Нов архитектурен проект';

  @override
  String get architectWizardSubtitle => 'Бърз параметричен стартов магьосник';

  @override
  String get architectWizardSectionStoreys => 'Етажи и височини';

  @override
  String get architectWizardSectionGrid => 'Координатна мрежа (Оси)';

  @override
  String get architectWizardSectionWalls => 'Типове стени и парапет';

  @override
  String get architectWizardParapetTitle => 'Балконен парапет (борд 12 cm)';

  @override
  String architectWizardParapetHeightInfo(String height, String level) {
    return 'Нормативна височина: $height m ($level)';
  }

  @override
  String get architectWizardParapetUnder5 => 'до 5-ти етаж';

  @override
  String get architectWizardParapetOver5 => 'над 5-ти етаж / >20m';

  @override
  String get architectWizardParapetFinishCap => 'С предпазна шапка';

  @override
  String get architectWizardParapetFinishPipe =>
      'С метална тръба на колонки (+15 cm)';

  @override
  String get architectWizardCreateAction => 'Създай проект и започни';

  @override
  String get wallTypeExt25Eps12 => 'Външна 25+12 EPS (37 cm)';

  @override
  String get wallTypeInt12Partition => 'Преградна 12 cm';

  @override
  String get wallTypeExt25Brick => 'Тухла 25 cm (без изолация)';

  @override
  String get wallTypeParapet12 => 'Борд 12 cm';

  @override
  String get architectDefaultProjectName => 'Архитектурен проект';

  @override
  String architectStoreyCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count етажа',
      one: '1 етаж',
    );
    return '$_temp0';
  }

  @override
  String get architectLaunchWizard => 'Стартирай с Архитектурен магьосник';

  @override
  String get architectUnitMm => 'Милиметри (mm)';

  @override
  String get architectUnitFeet => 'Футове (ft)';

  @override
  String get architectUnitInches => 'Инчове (in)';

  @override
  String get architectUnitSystem => 'Система от мерни единици';

  @override
  String get architectUnitSystemMetric => 'Метрична (m, cm, mm)';

  @override
  String get architectUnitSystemImperial => 'Имперска (ft, in)';

  @override
  String get architectWizardStep1 => '1. Единици';

  @override
  String get architectWizardStep2 => '2. Оси';

  @override
  String get architectWizardStep3 => '3. Етажи';

  @override
  String get architectWizardStep1Subtitle => 'Име на проект и мерни единици';

  @override
  String get architectWizardStep2Subtitle => 'Оси и разстояния';

  @override
  String get architectWizardStep3Subtitle => 'Коти и етажни височини';

  @override
  String get architectWizardNext => 'Напред';

  @override
  String get architectWizardBack => 'Назад';

  @override
  String get architectWallCore => 'Основна дебелина';

  @override
  String get architectWallInsulation => 'Топлоизолация EPS';

  @override
  String architectWallTotalThickness(String thickness) {
    return 'Общо: $thickness';
  }

  @override
  String get architectParapetCurb => 'Дебелина борд';

  @override
  String get architectParapetHeightLabel => 'Височина';

  @override
  String get architectWallLength => 'Размер';

  @override
  String get architectWallDirection => 'Посока';

  @override
  String get architectWallEnd => 'Край';

  @override
  String get architectWallContinue => 'Продължи';

  @override
  String get architectWallReferenceCenter => 'Ос';

  @override
  String get architectWallReferenceLeft => 'Ляво';

  @override
  String get architectWallReferenceRight => 'Дясно';

  @override
  String get architectWallInsertPoint => 'Точка';

  @override
  String get architectWallParallelHelp =>
      'Тап за местене напречно без промяна на ъгъла. Задръж за точен отстъп със знак.';

  @override
  String architectWallEndpointValue(int endpoint, String distance) {
    return '$endpoint · $distance';
  }

  @override
  String get architectWallEndpointClearance => 'Отстъп на край';

  @override
  String get architectMagnetHelp =>
      'Прилепване към стени, оси и точки от чертежа.';

  @override
  String get architectWallParallel => 'Успоредно';

  @override
  String get architectWallDraftHint => 'Задръж → точка · 2 пръста → мащаб';

  @override
  String get architectColumnPlacementHint =>
      'Задръж → постави · Тап → избор · X → отказ';

  @override
  String get architectEditHoldHint => 'Задръж → редакция · по-дълго → меню';

  @override
  String get architectNavigationHint =>
      'Плъзни за местене; посочи обект за редакция.';

  @override
  String get architectWallEditRejected => 'Отвор или твърде къса стена.';

  @override
  String get architectSaveFailed => 'Записът не успя. Проверете паметта.';

  @override
  String get architectWallExterior => 'Външна';

  @override
  String get architectWallPartition => 'Преградна';

  @override
  String get architectWallBrick => 'Тухла';

  @override
  String get architectWallConcrete => 'Бетон';

  @override
  String get architectWallParapet => 'Борд';

  @override
  String get architectWallReferenceInner => 'Вътре';

  @override
  String get architectWallReferenceOuter => 'Вън';

  @override
  String get architectWallFlipSide => 'Обърни външната страна';

  @override
  String get architectSelectionMulti => 'Много';

  @override
  String get architectSelectionMove => 'Влачене';

  @override
  String get architectSelectConnected => 'Свързани';

  @override
  String get architectSelectSimilar => 'Всички от типа';

  @override
  String get architectContextMenu => 'Меню';

  @override
  String architectSelectionCount(int count) {
    return '$count елемента';
  }

  @override
  String architectSelectionWallsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стени',
      one: '1 стена',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionColumnsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count колони',
      one: '1 колона',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionBeamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count греди',
      one: '1 греда',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionSlabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count плочи',
      one: '1 плоча',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionMixedSummary(int count, String details) {
    return '$count елемента: $details';
  }

  @override
  String get architectDeselect => 'Деселектирай';

  @override
  String get architectProperties => 'Свойства';

  @override
  String get architectWallExtend => 'Удължи';

  @override
  String get architectWallJoin => 'Свържи';

  @override
  String get architectOperationRejected => 'Не може тук.';

  @override
  String get architectPropertyHeight => 'Вис.';

  @override
  String get architectPropertyWidth => 'Шир.';

  @override
  String get architectPropertyDepth => 'Дълб.';

  @override
  String get architectPropertyThickness => 'Деб.';

  @override
  String get architectPropertyCore => 'Ядро';

  @override
  String get architectPropertyInsulation => 'Изол.';

  @override
  String get architectPropertyAngle => 'Ъгъл';

  @override
  String get architectPropertySteps => 'Стъпала';

  @override
  String get architectPropertySill => 'hp';

  @override
  String get architectPropertyOffset => 'Отстъп';

  @override
  String get architectPropertyBaseOffset => 'Кота H';

  @override
  String get architectPropertyCutDisplay => 'Срез';

  @override
  String get architectCutDisplayAuto => 'Авто';

  @override
  String get architectCutDisplayProjected => 'Поглед';

  @override
  String get architectCutDisplayCut => 'Срязан';

  @override
  String get architectCutDisplayOverhead => 'Над срез';

  @override
  String get architectStoreyCutPlane => 'Разрез H';

  @override
  String get architectPropertySize => 'Размер';

  @override
  String get architectPropertyName => 'Име';

  @override
  String get architectWallExtendHint => 'Посочи цел';

  @override
  String get architectWallCut => 'Срежи';

  @override
  String get architectWallCutHint => 'Посочи участък между пресичания';

  @override
  String get architectWallDetach => 'Отдели';

  @override
  String get architectWallAttach => 'Свържи';

  @override
  String get architectWallMagnet => 'Магнит';

  @override
  String get architectWallAlign => 'Подравни';

  @override
  String get architectWallMirror => 'Обърни';

  @override
  String get architectWallSplit => 'Раздели';

  @override
  String get architectWallSplitHint => 'Срез: две точки през стените';

  @override
  String get architectWallSplitSurfaceHint =>
      'Кликнете за потвърждение на повърхността';

  @override
  String get architectWallSplitDirectionHint => 'Кликнете за посока на среза';

  @override
  String get architectWallSplitPromptPickFirst =>
      'Посочете първа точка на среза';

  @override
  String get architectWallSplitPromptPickSecond =>
      'Посочете втора точка на среза';

  @override
  String get architectWallSplitPromptPickSide =>
      'Кликнете от страната, която да остане селектирана';

  @override
  String get architectWallSplitPerpendicular => 'Перпендикуляр';

  @override
  String get architectWallSplitSide1 => 'Страна 1';

  @override
  String get architectWallSplitSide2 => 'Страна 2';

  @override
  String get architectWallSplitBoth => 'И двете';

  @override
  String get architectWallClearance => 'Светло';

  @override
  String get architectGridNone => 'Без оси';

  @override
  String get architectGridCustom => 'Свободно';

  @override
  String architectGridBays(int x, int y) {
    return 'Полета $x × $y';
  }

  @override
  String get architectGridPickerHelp =>
      'Изтегли за брой полета. Осите във всяка посока са с една повече. Докосни размер върху мрежата за редакция.';

  @override
  String get architectGridFewer => 'По-малко полета';

  @override
  String get architectGridMore => 'Повече полета';

  @override
  String get architectWizardUnitsShort => 'Единици';

  @override
  String get architectWizardGridShort => 'Оси';

  @override
  String get architectWizardWallsShort => 'Стени';

  @override
  String get architectWizardTitleShort => 'Нов проект';

  @override
  String architectGridSpanLabel(String axes, String value) {
    return 'Междуосие $axes: $value';
  }

  @override
  String get architectGridParkingHelp => 'Паркинг';

  @override
  String get architectGridResidentialHelp => 'Жилищна схема';

  @override
  String get architectGridVillaHelp => 'Къща';

  @override
  String get architectGridModularHelp => 'Офис';

  @override
  String get architectGridNoneHelp => 'Без начални оси';

  @override
  String get architectRadius => 'Радиус';

  @override
  String get architectShapeWidth => 'Ширина';

  @override
  String get architectShapeHeight => 'Височина';

  @override
  String get architectFenestrationEditor => 'Редактор на дограма';

  @override
  String get architectFenestrationCreateNew => 'Създай нов';

  @override
  String get architectFenestrationEditStyle => 'Редактирай модел';

  @override
  String get architectFenestrationStyle => 'Модел на дограма';

  @override
  String get architectFenestrationSave => 'Запази в библиотека';

  @override
  String get architectFenestrationSaveSuccess =>
      'Моделът е запазен в библиотеката';

  @override
  String get architectFenestrationLibrary => 'Библиотека дограма';

  @override
  String get architectFenestrationCasing => 'Обрамчване / Обшивка';

  @override
  String get architectFenestrationCasingWidth => 'Ширина на обрамчването';

  @override
  String get architectFenestrationCasingProjection => 'Издаване пред стената';

  @override
  String get architectFenestrationCasingPlacement => 'Позиция на обшивката';

  @override
  String get architectFenestrationCasingExterior => 'Външна (фасадна)';

  @override
  String get architectFenestrationCasingInterior => 'Вътрешна';

  @override
  String get architectFenestrationCasingBoth => 'Двустранно';

  @override
  String get architectFenestrationFrame5Chamber => '5-камерен профил (70 mm)';

  @override
  String get architectFenestrationFrameFaceWidth => 'Лицева ширина на каса';

  @override
  String get architectFenestrationGlazingDouble =>
      'Двуслоен стъклопакет (24 mm)';

  @override
  String get architectFenestrationGlazingThickness => 'Дебелина на стъклопакет';

  @override
  String get architectFenestrationSplitH => 'Хоризонтален делител';

  @override
  String get architectFenestrationSplitV => 'Вертикален делител';

  @override
  String get architectFenestrationRemoveSplit => 'Премахни делител';

  @override
  String get architectFenestrationPaneType => 'Тип на полето';

  @override
  String get architectFenestrationPaneFixed => 'Глухо (фиксно)';

  @override
  String get architectFenestrationPaneTurnLeft => 'Отваряемо наляво';

  @override
  String get architectFenestrationPaneTurnRight => 'Отваряемо надясно';

  @override
  String get architectFenestrationPaneTiltTurn => 'Двуосно отваряне';

  @override
  String get architectFenestrationPaneTopHopper => 'Горно падащо (фрамуга)';

  @override
  String get architectFenestrationPaneDoorLeaf => 'Вратно крило';

  @override
  String get architectFenestrationPaneSolidPanel => 'Плътен термопанел';

  @override
  String get architectFenestrationDimensions => 'Размери';

  @override
  String get architectFenestrationProfile => 'Профил и стъкло';

  @override
  String get architectFenestrationDivisions => 'Растер и полета';

  @override
  String get architectFenestrationPresets => 'Шаблони';

  @override
  String get architectFenestrationViewElevation => 'Фасаден изглед';

  @override
  String get architectFenestrationView3D => '3D Изглед';

  @override
  String get architectFenestrationViewPlan => 'План (2D)';

  @override
  String get architectFenestrationIncludeBottomCasing =>
      'Обрамчване и под прозореца';

  @override
  String get architectFenestrationWallContextHelp =>
      'Обрамчването ляга по външната стена и изолацията, без да реже зида';

  @override
  String get architectFenestrationApplyToProject => 'Приложи към проекта';

  @override
  String get architectFenestrationCustom => 'Потребителски';

  @override
  String get architectFenestrationPreset => 'Стандартен образец';

  @override
  String get architectFenestrationSelectStyle => 'Избор на модел дограма';

  @override
  String get architectFenestrationStep1 => '1. Рамка и растер';

  @override
  String get architectFenestrationStep2 => '2. Отваряемост';

  @override
  String get architectFenestrationStep3 => '3. Пълнеж и шпроси';

  @override
  String get architectFenestrationNextStep => 'Следваща стъпка';

  @override
  String get architectFenestrationPrevStep => 'Предишна стъпка';

  @override
  String get architectFenestrationMuntins => 'Шпроси (растер на стъклото)';

  @override
  String get architectFenestrationMuntinCols => 'Вертикални шпроси';

  @override
  String get architectFenestrationMuntinRows => 'Хоризонтални шпроси';

  @override
  String get architectFenestrationMuntinWidth => 'Широчина на шпросите';

  @override
  String get architectFenestrationMuntinNone => 'Без шпроси';

  @override
  String get architectFenestrationMuntinClassic => 'Класик 2х2';

  @override
  String get architectFenestrationMuntinVictorian => 'Растер 2х3';

  @override
  String get architectFenestrationMuntinGrid3x3 => 'Каре 3х3';

  @override
  String get architectFenestrationSashProfile => 'Вътрешна рамка на крилото';

  @override
  String get architectFenestrationExactDimension => 'Задай точен размер';

  @override
  String get architectFenestrationLeafWidth => 'Широчина на крилото';

  @override
  String get architectFenestrationLeafHeight => 'Височина на крилото';

  @override
  String get architectFenestrationInfillGlazing => 'Стъклопакет';

  @override
  String get architectFenestrationInfillSolid => 'Плътен термопанел';

  @override
  String get architectFenestrationAddTransom => 'Добави фрамуга (хор.)';

  @override
  String get architectFenestrationAddMullion => 'Добави делител (верт.)';

  @override
  String get architectFenestrationSelectedLeaf => 'Маркирано поле';

  @override
  String get architectFenestrationCasingColor => 'Цвят на обрамчването';

  @override
  String get architectFenestrationMountingPlane => 'Монтажна равнина';

  @override
  String get architectFenestrationMountingPlaneHelp =>
      'В средата на тухления зид с фасадни обрамчвания';

  @override
  String get architectFenestrationWithCasing => 'С обрамчване';

  @override
  String get architectRadialMove => 'Влачене';

  @override
  String get snapAlignPoint1 => 'Подравняване с Точка 1';

  @override
  String get architectRadialEdit => 'Редакция';

  @override
  String get architectRadialDelete => 'Изтрий';

  @override
  String get architectRadialDuplicate => 'Дублирай';

  @override
  String get architectRadialRename => 'Име';

  @override
  String get architectRadialRotate => 'Завърти';

  @override
  String get architectRadialFlip => 'Обърни';

  @override
  String get architectRadialProperties => 'Свойства';

  @override
  String get architectRadialSplit => 'Раздели';

  @override
  String get architectRadialCut => 'Срежи';

  @override
  String get architectRadialOffset => 'Офсет';

  @override
  String get architectMirrorMove => 'Огледало';

  @override
  String get architectMirrorMoveTooltip => 'Огледално преместване';

  @override
  String get architectMirrorCopy => 'Огледало+';

  @override
  String get architectMirrorCopyTooltip => 'Огледално копиране';

  @override
  String get architectMirrorPromptPickAnchor => 'Избери опорна точка';

  @override
  String get architectMirrorPromptPickAxis => 'Избери втора точка на оста';

  @override
  String get architectMirrorAxisVertical => 'Вертикална';

  @override
  String get architectMirrorAxisHorizontal => 'Хоризонтална';

  @override
  String get architectEdgeDistance => 'Разстояние';

  @override
  String get architectEdgeSelectHint => 'Избери ръб';

  @override
  String get architectEdgeDistanceHint =>
      'Задай разстоянието чрез преместване на избрания ръб.';

  @override
  String get architectEdgeMoveHint =>
      'Мести ръба успоредно, заедно с двата му края.';

  @override
  String get architectEdgePullHint =>
      'Изтегли ръба със запазване на старите върхове.';

  @override
  String get dragDuplicateAction => 'Drag+';

  @override
  String get dragDuplicateHint => 'Плъзни, за да поставиш копието';

  @override
  String get structuralBeamNamePrefix => 'Г';

  @override
  String get bimUnderlayReviewCompleteAction => 'Проверено';

  @override
  String get bimUnderlayReviewCompleteTooltip =>
      'Отбележи запазените елементи и отвори като проверени';

  @override
  String get bimNewPoint => 'Нова точка';

  @override
  String get bimNewPointHint => 'Посочете позиция по ръба за новата точка';

  @override
  String get architectNewPointPrompt =>
      'Посочете позиция по ръба за новата точка';

  @override
  String get bimWallNewPointHelp =>
      'Добавя свързани сегменти. Срежи прекъсва връзката.';

  @override
  String get architectCanvasLight => 'Светъл фон';

  @override
  String get architectCanvasDark => 'Тъмен фон';

  @override
  String get architectWallType => 'Тип стена';

  @override
  String get architectWallFollowStorey => 'По етаж';

  @override
  String get architectWallLeadingLine => 'Водеща линия';

  @override
  String get architectWallCoreThickness => 'Дебелина ядро';

  @override
  String get architectPropertyTotal => 'Общо';

  @override
  String get architectMaterialBrick => 'Тухла';

  @override
  String get architectMaterialConcrete => 'Бетон';

  @override
  String get architectMaterialTimber => 'Дърво';

  @override
  String get architectMaterialPanel => 'Термопанел';

  @override
  String get architectInsulationXps => 'XPS';

  @override
  String get architectInsulationEps => 'EPS';

  @override
  String get architectInsulationStoneWool => 'Каменна вата';

  @override
  String get architectSettings => 'Настройки';

  @override
  String get architectGhostStoreys => 'Съседни етажи';

  @override
  String get architectUpperOverhangs => 'Еркери и балкони от горен етаж';

  @override
  String get architectUpperOverhangsHelp =>
      'Автоматично показване на еркери и балкони от горния етаж с пунктирана линия';

  @override
  String get architectOverhangErker => 'Еркер';

  @override
  String get architectOverhangBalcony => 'Балкон';

  @override
  String get architectDrawingGrid => 'Мрежа';

  @override
  String get architectSnap => 'Прилепване';

  @override
  String get architectHandleOffsetLength => 'Дължина на изнесената линия';

  @override
  String get architectAxesWallThickness => 'Ядро за оси';

  @override
  String get architectAxesFromWallsHelp =>
      'Постави оси през ядрата на стените на този етаж. Задай дебелината на ядрото в Настройки.';

  @override
  String get architectAxesNoMatchingWalls =>
      'Няма стени с избраната дебелина на ядрото.';

  @override
  String architectAxesGenerated(int count) {
    return 'Добавени оси: $count';
  }

  @override
  String get architectDimensionChain => 'Верига';

  @override
  String get architectDimensionScale => 'Мащаб на размерите';

  @override
  String get architectDimensionSingle => 'Единичен';

  @override
  String get architectDimensionExterior => 'Външен';

  @override
  String get architectDimensionExteriorHelp =>
      'Редове: отвори, стенни участъци, общ размер на ядрото с отделна крайна изолация, оси. Разстоянието между редовете следва мащаба и големината на текста. Фасадните отвори и перпендикулярните оси се включват автоматично; изборът по изолацията се отнася към ядрото.';

  @override
  String get architectDimensionInterior => 'Вътрешен';

  @override
  String get architectDimensionInteriorHint =>
      'Избери крайни стени и прегради, после постави линията.';

  @override
  String get architectDimensionInteriorHelp =>
      'Една линия измерва между вътрешните лица на крайните успоредни стени, с двете лица на междинните прегради.';

  @override
  String get architectDimensionAddWalls => 'Добави стени';

  @override
  String get architectDimensionEditPoints => 'Редактирай точки';

  @override
  String get architectDimensionEditPointsHint =>
      'Тапни стена за добавяне или минус за премахване. Зеленото тикче запазва.';

  @override
  String get architectDimensionRemoveReference => 'Премахни от размера';

  @override
  String get architectDimensionKeepReferences =>
      'Добави друга опорна точка, преди да премахнеш тази; размерът изисква два различни края.';

  @override
  String get architectDimensionConfirm => 'Запази показания размер';

  @override
  String get architectDimensionAddWallsHint =>
      'Избери пропуснатите успоредни стени и потвърди. Размерната линия остава на място.';

  @override
  String get architectDimensionStartHint => 'Избери първата измервана точка.';

  @override
  String get architectDimensionEndHint =>
      'Избери втората измервана точка, после постави размерната линия.';

  @override
  String get architectDimensionContinue => 'Продължи';

  @override
  String get architectDimensionFinish => 'Завърши';

  @override
  String get architectDimensionPlace => 'Постави';

  @override
  String get architectDimensionChainHint =>
      'Избери стени или точки. Зеленото тикче запазва, минусът премахва.';

  @override
  String get architectDimensionDirectionHint =>
      'Избери стена или линия, успоредна на размерната линия.';

  @override
  String get architectDimensionPositionHint =>
      'Посочи място за размерната линия или въведи точно отстояние.';

  @override
  String get architectSelectionCycleHelp =>
      'Тап за избор; повторен тап обхожда застъпванията. Задръж за меню.';

  @override
  String get architectDimensionOverall => 'Общ размер';

  @override
  String get architectDimensionSnap30cm => '30 см';

  @override
  String get architectDimensionSnap40cm => '40 см';

  @override
  String get architectDimensionNewPoint => 'Нова точка';

  @override
  String get architectStoreyGround => 'Партер';

  @override
  String get architectStoreyFloor => 'Етаж';

  @override
  String architectSelectionDoorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count врати',
      one: '1 врата',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionWindowsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прозореца',
      one: '1 прозорец',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionZonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count зони',
      one: '1 зона',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionAxesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count оси',
      one: '1 ос',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionCadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count CAD',
      one: '1 CAD',
    );
    return '$_temp0';
  }

  @override
  String get snapCorner => 'Ъгъл';

  @override
  String get snapEdge => 'Ръб';

  @override
  String get snapMerge => 'Обединяване';

  @override
  String get snapDoorJamb => 'Каса на врата';

  @override
  String get snapWindowJamb => 'Каса на прозорец';

  @override
  String get architectDoorSillNone => 'Без праг';

  @override
  String get architectDoorSillStep => 'Праг: 15 cm';

  @override
  String get architectZoneCatLiving => 'Дневна';

  @override
  String get architectZoneCatBedroom => 'Спалня';

  @override
  String get architectZoneCatKitchen => 'Кухня';

  @override
  String get architectZoneCatCorridor => 'Коридор';

  @override
  String get architectZoneCatBathroom => 'Баня / WC';

  @override
  String get architectZoneCatTerrace => 'Тераса';

  @override
  String get architectZoneCatStorage => 'Склад / Мокро';

  @override
  String get architectZoneCatOffice => 'Кабинет / Офис';

  @override
  String get architectZoneCatCustom => 'Помещение';

  @override
  String get architectFenestrationPresetSingleCasement =>
      'Еднокрил 80/140 (5-камерен)';

  @override
  String get architectFenestrationPresetDoubleCasement =>
      'Двукрил 140/140 (5-камерен)';

  @override
  String get architectFenestrationPresetDoubleWithCasing =>
      'Двукрил 140/140 с обрамчване';

  @override
  String get architectFenestrationPresetTripleCasement =>
      'Трикрил 210/140 (фикс + 2 крила)';

  @override
  String get architectFenestrationPresetWithTransom =>
      'Прозорец с надстройка 140/180';

  @override
  String get architectFenestrationPresetDoorInterior =>
      'Интериорна врата 90/200';

  @override
  String get architectFenestrationPresetDoorEntranceCasing =>
      'Входна врата с обрамчване 100/210';

  @override
  String get architectFenestrationPresetDoorBalconyGlass =>
      'Балконска остъклена врата 90/210';

  @override
  String architectWallParapetPipe(int thickness, String height) {
    return 'Борд $thickness cm (тръба h=${height}m)';
  }

  @override
  String architectWallParapetCap(int thickness, String height) {
    return 'Борд $thickness cm (шапка h=${height}m)';
  }

  @override
  String get stairShape => 'Форма';

  @override
  String get stairStraight => 'Право';

  @override
  String get stairQuarterTurn => 'Г-образно';

  @override
  String get stairHalfTurn => 'П-образно';

  @override
  String get stairSpiral => 'Вито';

  @override
  String get stairSpiralOverlap => 'Вито с припокриване';

  @override
  String get stairWinders => 'Забежни стъпала';

  @override
  String get stairWindersHelp =>
      'Заменя площадката със стъпала в завоя. Броят и светлият вътрешен радиус се подбират автоматично, с минимум 23 cm по линията на 30 cm от тесния край като проектна цел. Нормативната приложимост зависи от предназначението и евакуацията. Завоят не заменя задължителната площадка по височина.';

  @override
  String get stairWinderCorner => 'В ъгъла';

  @override
  String get stairWinderCornerTread => 'Стъпало';

  @override
  String get stairWinderCornerRiser => 'Чело';

  @override
  String get stairWinderCornerHelp =>
      'Стъпало: едно стъпало преминава през външния ъгъл. Чело: границата между две стъпала е по ъглополовящата. И двата варианта имат светъл вътрешен радиус; опирането и армировката се проектират отделно.';

  @override
  String get stairWinderCount => 'Стъпала на 90°';

  @override
  String get stairWinderCountAuto => 'Автоматичен брой в завоя';

  @override
  String get stairWinderRadiusAuto => 'Автоматичен радиус в завоя';

  @override
  String get stairOverlapHelp =>
      'Повече от един оборот. Светлата височина се проверява между застъпващите се части с отчитане на бетона и настилката.';

  @override
  String get stairTurnLeft => 'Завой наляво';

  @override
  String get stairTurnRight => 'Завой надясно';

  @override
  String get stairPlaceHelp =>
      'Посочи първия подстъп, после посоката на изкачване. Дължината и стъпалата се изчисляват от котите.';

  @override
  String get stairCode => 'Нормативна база';

  @override
  String get stairCodeBulgaria => 'България · BG-2025.1';

  @override
  String get stairCodeGeometry => 'Само геометрия';

  @override
  String get stairUse => 'Предназначение';

  @override
  String get stairUsePrivate => 'В жилище';

  @override
  String get stairUseCommon => 'Нова многофамилна';

  @override
  String get stairUsePublic => 'Обществена сграда';

  @override
  String get stairUseAssembly => 'Обществено, над 200 души';

  @override
  String get stairUseOutdoor => 'Нов градски маршрут';

  @override
  String get stairEvacuation => 'Евакуация';

  @override
  String get stairUnspecified => 'Неуточнено';

  @override
  String get stairNoEvacuation => 'Извън евакуационен път';

  @override
  String get stairUpTo15 => 'До 15 души';

  @override
  String get stair16To50 => '16–50 души';

  @override
  String get stairOver50 => 'Над 50 души';

  @override
  String get stairRise => 'Изкачване';

  @override
  String get stairFollowStoreys => 'От етажите';

  @override
  String get stairHeightMode => 'Височина';

  @override
  String get stairHeightManual => 'Ръчно';

  @override
  String get stairHeightModeHelp =>
      'От етажите: изкачването се изчислява до горния етаж от зададеното начало. Ръчно: въвеждате общото изкачване и то се запазва при промяна на етажите.';

  @override
  String get stairStartOffset => 'Начало от кота';

  @override
  String get stairStartOffsetHelp =>
      'Височина на началото спрямо етажната кота. 0 е на етажа, положителна стойност е над него, отрицателна — под него. Изкачването се измерва от това начало.';

  @override
  String get stairUpperStorey => 'Горен етаж';

  @override
  String get stairFloorHeight => 'Височина на етажа';

  @override
  String get stairClearWidth => 'Светла широчина';

  @override
  String get stairRisers => 'Подстъпи';

  @override
  String get stairRiser => 'Височина на стъпало';

  @override
  String get stairGoing => 'Широчина на стъпало';

  @override
  String get stairLanding => 'Дълбочина на площадка';

  @override
  String get stairInnerRadius => 'Светъл вътрешен радиус';

  @override
  String get stairSweep => 'Ъгъл на завъртане';

  @override
  String get stairAutomatic => 'Авто';

  @override
  String get stairFit => 'Преизчисли';

  @override
  String get stairFitHelp =>
      'Подбира подстъпи, стъпка, широчина и вътрешен радиус за избрания профил. Запазва височината и посоката.';

  @override
  String get stairAdvanced => 'Размери';

  @override
  String get stairChecks => 'Проверки';

  @override
  String get stairCheckPass => 'Изпълнено';

  @override
  String get stairCheckError => 'Нарушение';

  @override
  String get stairCheckAdvice => 'Препоръка за удобство';

  @override
  String get stairCheckReview => 'Непроверено';

  @override
  String get stairDraft => 'Запази като чернова';

  @override
  String get stairDraftHelp =>
      'Черновите могат да съдържат нарушения и се чертаят в червено.';

  @override
  String get stairIncomplete =>
      'Проверява се геометрията. Просветът, парапетите, настилките и целият евакуационен път изискват проектна проверка.';

  @override
  String get stairCheckSlope => 'Наклон на рамото';

  @override
  String get stairCheckFlightRise => 'Височина на рамо';

  @override
  String get stairCheckInner30 => 'Стъпало на 30 см';

  @override
  String get stairCheckInner => 'Стъпало при тесния край';

  @override
  String get stairCheckDiameter => 'Светъл вътрешен диаметър';

  @override
  String get stairCheckComfort => 'Удобство · 2h + b';

  @override
  String get stairCheckCapacity => 'Капацитет и пожарен клас';

  @override
  String get stairCheckHeadroom => 'Просвет и отвор в плочата';

  @override
  String get stairCheckHandrails => 'Парапети и ръкохватки';

  @override
  String get stairCheckFinishes => 'Чела, тактилни ивици и настилки';

  @override
  String get stairCheckAccessibility => 'Достъпност на вити стъпала';

  @override
  String get stairCheckScope => 'Други приложими изисквания';

  @override
  String get stairCheckVersion => 'Непозната версия на нормите';

  @override
  String get stairCheckUpperStorey =>
      'Проверете горната кота: липсва етаж или изкачването е извън 0–30 м';

  @override
  String get stairRulesSources => 'Нормативни източници';

  @override
  String get stairFireSource => 'Пожарна безопасност · Iз-1971, редакция 2025';

  @override
  String get stairAccessSource => 'Достъпност · РД-02-20-2/2021, чл. 18 и 55';

  @override
  String get stairClearDimensionsHelp =>
      'Размерите са светли, между ограничаващите проекции на ръкохватките. Вътрешният радиус започва от ограничаващия вътрешен ръб или проекцията на парапета.';

  @override
  String get stairUnsupported =>
      'Невалидни размери на стълбата. Проверете въведените стойности.';

  @override
  String get stairLegacy =>
      'Схематично стълбище. Преизчисли, за да го превърнеш в параметрично.';

  @override
  String get stairCheckGroupSteps => 'Подстъпи в група';

  @override
  String architectWallOvershootDetected(int distance) {
    return 'Изскачащ край: $distance cm';
  }

  @override
  String get architectWallOvershootTrim => 'Изчисти';

  @override
  String get architectWallOvershootDismiss => 'Отказ';

  @override
  String architectWallOvershootTrimmed(int distance) {
    return 'Изскачащият край е изчистен ($distance cm)';
  }

  @override
  String get architectWallOvershootTooltip =>
      'Изчистване на изскачащия край до ъгъла';

  @override
  String get architectRadialJoin => 'Свържи';

  @override
  String get architectWallJoinTooltip => 'Съединяване на стени (Join)';

  @override
  String get architectWallJoinSelectSecond =>
      'Изберете втора стена за съединяване';

  @override
  String get architectWallJoinSuccess => 'Стените са съединени';

  @override
  String get architectWallJoinIncompatible => 'Стените не могат да се съединят';

  @override
  String get architectWallStraighten => 'Изправи';

  @override
  String get architectWallStraightened => 'Стената е изправена';

  @override
  String get architectWallAlreadyStraight => 'Стената вече е права';

  @override
  String get stairRailing => 'Парапет';

  @override
  String get stairSmartRailingHelp =>
      'Парапет при отворени страни, ръкохватка до висока стена. При врати, прозорци и ниски стени се запазва парапетът.';

  @override
  String get stairLabel => 'Надпис';

  @override
  String stairPlanStepsLabel(int count, String going, String riser) {
    return '$count ст. $going/$riser см';
  }

  @override
  String stairPlanRiseLabel(String height) {
    return 'H=$height м';
  }

  @override
  String get stairDetails => 'Детайл';

  @override
  String get stairGuardHeight => 'Височина на парапета';

  @override
  String get stairHandrailHeight => 'Височина на ръкохватката';

  @override
  String get stairConcreteThickness => 'Бетонна плоча';

  @override
  String get stairFinishThickness => 'Настилка';

  @override
  String get stairNosing => 'Издаване на ръба';

  @override
  String get stairDetailsHelp =>
      'Дебелината на плочата е вертикална. Размерите са за изчертаване; проверете конструктивната дебелина, светлата широчина между ръкохватките и приложимите изисквания.';

  @override
  String get stairSection => 'Разрез';

  @override
  String get stairSectionHint =>
      'Посочи две точки в плана, за да преместиш и завъртиш разреза.';

  @override
  String get stairSectionReset => 'Начален разрез';

  @override
  String get stairSectionEmpty =>
      'Разрезът не пресича стълбата. Посочи две нови точки в плана.';

  @override
  String get stairSectionPlan => 'Разрез в плана';

  @override
  String get stairSectionCutHeight => 'Хоризонтален срез';

  @override
  String get slabLayers => 'Слоеве';

  @override
  String get slabAssembly => 'Състав';

  @override
  String get slabAbove => 'Над бетона';

  @override
  String get slabBelow => 'Под бетона';

  @override
  String get slabCore => 'Бетон';

  @override
  String get slabCoreOffset => 'Отместване бетон';

  @override
  String get slabFinishedLevel => 'Готов под';

  @override
  String get slabBottomLevel => 'Долна кота';

  @override
  String get slabPreset => 'Зареди състав';

  @override
  String get slabAllUsages => 'Всички';

  @override
  String get slabOnlyThis => 'Само тази';

  @override
  String get slabShared => 'Промени общия тип';

  @override
  String get slabSharedHelp =>
      'Записът обновява всички плочи с този тип. Избери „Само тази“ за отделен вариант.';

  @override
  String get slabNewType => 'Нов състав';

  @override
  String get slabLibrary => 'Лична библиотека';

  @override
  String get slabLibrarySaved => 'Съставът е запазен в библиотеката.';

  @override
  String get slabSaveLibrary => 'Запази в библиотеката';

  @override
  String get slabLibraryFailed => 'Библиотеката не е записана.';

  @override
  String get slabPresetHelp =>
      'Редактируеми начални дебелини, без изчисление за сградата. Фундамент: хидроизолация под бетона; под върху терен: над бетона. Студен таван: непроходима изолация. Изолиран таван: окачена облицовка. Покривите и терасите имат едно поле за наклон; връзките и отводняването се детайлират отделно.';

  @override
  String get slabAddLayer => 'Добави слой';

  @override
  String get slabEditLayer => 'Слой';

  @override
  String get slabMaterial => 'Материал';

  @override
  String get slabRole => 'Функция';

  @override
  String get slabThicknessMm => 'Дебелина (mm)';

  @override
  String get slabSlope => 'Наклон (%)';

  @override
  String get slabDirection => 'Посока на оттичане';

  @override
  String get slabDirectionHelp =>
      'Посочи две точки в плана — от високото към ниското.';

  @override
  String get slabDirectionRequired => 'Задай посока на оттичане в прегледа.';

  @override
  String get slabInvalid =>
      'Провери дебелините, имената и наклона. Само един горен слой може да е с наклон.';

  @override
  String get slabDuplicate => 'Дублирай слой';

  @override
  String get slabMoveUp => 'Нагоре';

  @override
  String get slabMoveDown => 'Надолу';

  @override
  String get slabFinish => 'Покритие';

  @override
  String get slabFinishTile => 'Плочки';

  @override
  String get slabFinishParquet => 'Паркет';

  @override
  String get slabFinishWet => 'Мокро';

  @override
  String get slabNaturalGround => 'Естествен терен';

  @override
  String get buildingSections => 'Разрези';

  @override
  String get buildingSection => 'Разрез';

  @override
  String get buildingSectionNew => 'Нов разрез';

  @override
  String get buildingSectionCut => 'Промени сечението';

  @override
  String get buildingSectionHint =>
      'Задай линията на разреза, после посоката на гледане.';

  @override
  String get buildingSectionEmpty => 'Няма пресечени елементи.';

  @override
  String get slabDetail => 'Детайл — настилки';

  @override
  String get slabDetailPick => 'Посочи плоча, после постави надписите.';

  @override
  String get slabDetailMove => 'Посочи място за надписите.';

  @override
  String get slabDetailLost => 'Загубена връзка';

  @override
  String get slabDetailReattach => 'Свържи отново';

  @override
  String get slabDetailHere => 'тук';

  @override
  String get slabDetailSide => 'Обърни надписите';

  @override
  String get slabDetailRemove => 'Премахни детайла';

  @override
  String get slabSectionDelete => 'Изтрий разреза';

  @override
  String get slabMatConcrete => 'Стоманобетон';

  @override
  String get slabMatTile => 'Плочки';

  @override
  String get slabMatTileAdhesive => 'Лепило за плочки';

  @override
  String get slabMatParquet => 'Паркет';

  @override
  String get slabMatUnderlay => 'Подложка за паркет';

  @override
  String get slabMatScreed => 'Циментова замазка';

  @override
  String get slabMatPeFoil => 'Разделително PE фолио';

  @override
  String get slabMatXps => 'XPS';

  @override
  String get slabMatFloorInsulation => 'Твърда подова топлоизолация';

  @override
  String get slabMatAcousticWool => 'Ударна шумоизолация';

  @override
  String get slabMatMineralWool => 'Минерална вата';

  @override
  String get slabMatRoofInsulation => 'Твърда покривна топлоизолация';

  @override
  String get slabMatWaterproofing => 'Хидроизолация';

  @override
  String get slabMatVapourBarrier => 'Пароизолация';

  @override
  String get slabMatBreathableMembrane => 'Паропропусклива защита';

  @override
  String get slabMatGeotextile => 'Геотекстил';

  @override
  String get slabMatGravel => 'Чакъл';

  @override
  String get slabMatBallast => 'Баластра';

  @override
  String get slabMatCompactedFill => 'Уплътнен насип';

  @override
  String get slabMatBlindingConcrete => 'Подложен бетон';

  @override
  String get slabMatPlaster => 'Таванска мазилка';

  @override
  String get slabMatProtectiveRender => 'Защитна армирана шпакловка';

  @override
  String get slabMatPlasterboard => 'Гипсокартонена облицовка';

  @override
  String get slabMatAdhesive => 'Лепило за изолация';

  @override
  String get slabMatCustom => 'Друг материал';

  @override
  String get slabUseFoundation => 'Фундаментна';

  @override
  String get slabUseGround => 'Върху терен';

  @override
  String get slabUseBasement => 'Над сутерен';

  @override
  String get slabUseIntermediate => 'Междуетажна';

  @override
  String get slabUseColdAttic => 'Под студен таван';

  @override
  String get slabUseInsulatedCeiling => 'Изолация отдолу';

  @override
  String get slabUseWarmRoof => 'Класически покрив';

  @override
  String get slabUseInvertedRoof => 'Обърнат покрив';

  @override
  String get slabUseTerrace => 'Тераса над отопляем обем';

  @override
  String get slabRoleFinish => 'Покритие';

  @override
  String get slabRoleAdhesive => 'Залепване';

  @override
  String get slabRoleScreed => 'Замазка';

  @override
  String get slabRoleSeparation => 'Разделяне';

  @override
  String get slabRoleInsulation => 'Топлоизолация';

  @override
  String get slabRoleAcoustic => 'Шумоизолация';

  @override
  String get slabRoleWaterproofing => 'Хидроизолация';

  @override
  String get slabRoleVapourControl => 'Пароконтрол';

  @override
  String get slabRoleSlope => 'Наклон';

  @override
  String get slabRoleCeiling => 'Таван';

  @override
  String get slabRoleBase => 'Основа';

  @override
  String get slabRoleFill => 'Насип';

  @override
  String get slabRoleProtection => 'Защита';

  @override
  String get architectFacades => 'Фасади';

  @override
  String get architectFacade => 'Фасада';

  @override
  String get architectFacadeNew => 'Нова фасада';

  @override
  String get architectFacadeEdit => 'Редактирай маркера';

  @override
  String get architectFacadeReverse => 'Обърни изгледа';

  @override
  String get architectFacadePlan => 'План';

  @override
  String get architectFacadeStartHint =>
      'Посочи първата точка на маркера извън сградата.';

  @override
  String get architectFacadeEndHint =>
      'Посочи втората точка, успоредно на фасадата.';

  @override
  String get architectFacadeSideHint =>
      'Посочи страната към сградата за посока на гледане.';

  @override
  String get architectFacadeEmpty =>
      'Няма елементи в изгледа. Провери обхвата и посоката на маркера.';

  @override
  String get architectNorth => 'Север';

  @override
  String get architectNorthPlace => 'Постави север';

  @override
  String get architectNorthHelp =>
      'Завърти знака, за да зададеш север. Имената на фасадите се обновяват автоматично.';

  @override
  String get architectNorthAngle => 'Ъгъл';

  @override
  String get architectNorthAngleHelp =>
      'Ъгъл по часовника от горната посока на плана (0°).';

  @override
  String get architectNorthInvalidAngle => 'Въведи валиден ъгъл.';

  @override
  String get architectNorthPositionHint => 'Посочи мястото на знака за север.';

  @override
  String get architectNorthDirectionHint => 'Посочи точка към север.';

  @override
  String get architectNorthSymbolLetter => 'С';

  @override
  String get architectFacadeNorth => 'Север';

  @override
  String get architectFacadeNorthEast => 'Североизток';

  @override
  String get architectFacadeEast => 'Изток';

  @override
  String get architectFacadeSouthEast => 'Югоизток';

  @override
  String get architectFacadeSouth => 'Юг';

  @override
  String get architectFacadeSouthWest => 'Югозапад';

  @override
  String get architectFacadeWest => 'Запад';

  @override
  String get architectFacadeNorthWest => 'Северозапад';

  @override
  String get architectToolRoof => 'Покрив';

  @override
  String get architectRoofs => 'Покриви';

  @override
  String get architectRoofPlane => 'Покривен скат';

  @override
  String get architectRoofDrawRect => 'Правоъг.';

  @override
  String get architectRoofDrawPoly => 'Полигон';

  @override
  String get architectRoofAuto => 'Авто-покрив';

  @override
  String get architectRoofAutoGable => 'Двускатен';

  @override
  String get architectRoofAutoHip => 'Четирискатен';

  @override
  String get architectRoofAutoShed => 'Едноскатен';

  @override
  String get architectRoofAutoFlat => 'Плосък';

  @override
  String architectRoofAutoCreated(int count) {
    return 'Генерирани са $count покривни ската';
  }

  @override
  String get architectRoofAutoNoWalls =>
      'Първо начертай външни стени за автоматичен покрив.';

  @override
  String get architectRoofSlope => 'Наклон';

  @override
  String get architectRoofOverhang => 'Стреха';

  @override
  String get architectRoofManualSupport => 'Ръчно положение на опората';

  @override
  String get architectRoofSupportDistance => 'От стрехата';

  @override
  String get architectRoofManualSupportHelp =>
      'Хоризонтално разстояние от ръба на стрехата до оста на пояса и дървената греда. Махнете отметката, за да следват носещата стена автоматично.';

  @override
  String get architectRoofSupportDistanceInvalid =>
      'Въведете разстояние в рамките на ската.';

  @override
  String get architectRoofBaseElev => 'Кота стреха';

  @override
  String get architectRoofRidgeElev => 'Кота било';

  @override
  String get architectRoofSwitchEaves => 'Смени стреха';

  @override
  String get architectRoofSwitchEavesTooltip =>
      'Смени кой ръб е долната стреха (или докосни ръб в чертежа)';

  @override
  String get architectRoofLayers => 'Пластове и дърво';

  @override
  String get architectRoofLayersShort => 'Детайл';

  @override
  String get architectRoofPresetPitchedTiles =>
      'Класически дървен покрив с керемиди';

  @override
  String get architectRoofPresetWarmPitched => 'Топъл скатен покрив (обитаем)';

  @override
  String get architectRoofPresetStandingSeam =>
      'Скатен покрив с фалцова ламарина';

  @override
  String get architectRoofPresetFlatWarm =>
      'Плосък топъл стоманобетонен покрив';

  @override
  String get architectRoofPresetCustom => 'Потребителски покривен пакет';

  @override
  String get architectRoofRoleCovering => 'Покритие';

  @override
  String get architectRoofRoleBattens => 'Летви';

  @override
  String get architectRoofRoleCounterBattens => 'Контралетви';

  @override
  String get architectRoofRoleUnderlayment => 'Дишаща мембрана';

  @override
  String get architectRoofRoleBoarding => 'Дъсчена обшивка';

  @override
  String get architectRoofRoleRafters => 'Ребра';

  @override
  String get architectRoofRoleInsulation => 'Топлоизолация';

  @override
  String get architectRoofRoleVapourBarrier => 'Пароизолация';

  @override
  String get architectRoofRoleStructure => 'Носеща плоча';

  @override
  String get architectRoofRoleInterior => 'Вътрешна обшивка';

  @override
  String get architectRoofMatClayTiles => 'Керемиди';

  @override
  String get architectRoofMatConcreteTiles => 'Бетонни керемиди';

  @override
  String get architectRoofMatMetalSeam => 'Фалцова ламарина';

  @override
  String get architectRoofMatBitumenShingles => 'Битумни керемиди';

  @override
  String get architectRoofMatTimberBoarding => 'Дъсчена обшивка';

  @override
  String get architectRoofMatOsb => 'OSB плоскост';

  @override
  String get architectRoofMatBreathableMembrane => 'Паропропусклива мембрана';

  @override
  String get architectRoofMatVapourBarrier => 'Пароизолационно фолио';

  @override
  String get architectRoofMatMineralWool => 'Минерална вата';

  @override
  String get architectRoofMatXps => 'Екструдиран полистирен XPS';

  @override
  String get architectRoofMatWaterproofing => 'Хидроизолационна мембрана';

  @override
  String get architectRoofMatSlopeScreed => 'Замазка за наклон';

  @override
  String get architectRoofMatRcSlab => 'Стоманобетон';

  @override
  String get architectRoofMatPlasterboard => 'Гипсокартон';

  @override
  String get architectRoofTimberSection => 'Дървена конструкция и сечения';

  @override
  String get architectRoofBattensLabel => 'Летви';

  @override
  String get architectRoofCounterBattensLabel => 'Контралетви';

  @override
  String get architectRoofRaftersLabel => 'Ребра';

  @override
  String get architectRoofWallPlateLabel => 'Мауерлат';

  @override
  String get architectRoofRidgePurlinLabel => 'Билова столица';

  @override
  String get architectRoofFasciaLabel => 'Челна дъска при стрехата';

  @override
  String get architectRoofEavesCutLabel => 'Оформление на стрехата';

  @override
  String get architectRoofEavesCutPlumb => 'Вертикален срез';

  @override
  String get architectRoofEavesCutSquare => 'Перпендикулярен';

  @override
  String get architectRoofEavesCutBox => 'Хоризонтален сачак';

  @override
  String get architectRoofStepLabel => 'Стъпка';

  @override
  String get architectRoofHintStart =>
      'Задръж и плъзни за първи ъгъл на ската или избери Авто-покрив.';

  @override
  String architectRoofHintNext(int count) {
    return 'Избери следващ ъгъл ($count т.). Натисни Готово за затваряне.';
  }

  @override
  String get architectRoofSectionDetailTitle => 'Покривен детайл';

  @override
  String get architectSectionStartHint => 'Посочи началото на разреза.';

  @override
  String get architectViewEndHint => 'Посочи края по водачите за подравняване.';

  @override
  String get architectViewDirectionHint =>
      'Посочи посоката и кликни крайната граница на гледката.';

  @override
  String architectSectionNumber(int number) {
    return 'Разрез $number';
  }

  @override
  String get architectManageViews => 'Управление';

  @override
  String get architectViewDrawingEmpty =>
      'Изберете или създайте изглед от менюто.';

  @override
  String get architectOpeningClearance => 'Чисто разстояние (простенок)';

  @override
  String architectOpeningModularSnap(int step) {
    return 'Модулна стъпка ($step cm)';
  }

  @override
  String get architectRoofSetEavesHere => 'Стреха тук';

  @override
  String get architectRoofSetEavesHereTooltip =>
      'Задай избраната отсечка като долна стреха (скатът се изкачва от нея)';

  @override
  String get architectRoofFlipSlope => 'Обърни 180°';

  @override
  String get architectRoofFlipSlopeTooltip =>
      'Обърни посоката на наклона на ската на 180°';

  @override
  String get architectRoofRotateSlope => 'Посока скат';

  @override
  String get architectRoofAttachToWalls => 'Прикрепи към стените';

  @override
  String get architectRoofAttachToWallsSubtitle =>
      'Автоматично прикрепя покрива към най-високата точка на стените с конструктивен детайл';

  @override
  String get architectRoofAlignOnce => 'По стените';

  @override
  String get architectRoofAlignOnceHelp =>
      'Задава еднократно височината по носещите стени. Ръчните премествания запазват зададената височина.';

  @override
  String get architectRoofRingBeamLabel => '10 см стоманобетонен пояс';

  @override
  String get architectRoofMetalFlashingLabel => 'Метална обшивка (капелник)';

  @override
  String get architectRoofMoveVerticalAction => 'Премести нагоре / надолу';

  @override
  String get architectRoofSnapToWallsAction => 'Прикрепи към стени';

  @override
  String get architectRoofPropertiesAction => 'Свойства';

  @override
  String get architectRoofPlan => 'Покривни линии';

  @override
  String get architectAddRoofPlan => 'Добави Покривни линии';

  @override
  String get architectRoofPlanUnderlay => 'Пунктир на ограждащите стени';

  @override
  String get architectRoofPlanSubtitle =>
      'Генерален покривен план с пунктир на фасадните стени';

  @override
  String architectRoofLowerLevelBadge(String level) {
    return 'Кота $level';
  }

  @override
  String get architectRoofDrawMultiPitch => 'Многоскатен';

  @override
  String get architectRoofDrawMansard => 'Мансарден';

  @override
  String get architectRoofIsMansard => 'Мансарден';

  @override
  String get architectRoofMakeMansard => 'Пречупи скат';

  @override
  String get architectRoofUpperSlope => 'Горен наклон';

  @override
  String get architectRoofBreakDistance => 'Пречупване';

  @override
  String get architectRoofMansardKnuckleTooltip =>
      'Провлачете за преместване на линията на пречупване';

  @override
  String get architectRoofKnucklePurlin => 'Междинна столица';

  @override
  String get architectRoofSnap45Degrees => '45° Скат / Било';

  @override
  String get architectRoofLinkedSlopes => 'Свързани скатове';

  @override
  String get architectRoofLinkedSlopesTooltip =>
      'Всички скатове в тази покривна група споделят общ наклон и височина на стрехата';

  @override
  String get architectRoofIndependentSlope => 'Индивидуален наклон';

  @override
  String get architectRoofIndependentSlopeTooltip =>
      'Този скат има индивидуален наклон (отключен от групата)';

  @override
  String get architectRoofToggleSlopeLockTooltip =>
      'Превключване между свързан наклон и индивидуален наклон';

  @override
  String get architectRoofMatchRidge => 'Изравни по било';

  @override
  String get architectRoofMatchRidgeTooltip =>
      'Напасва наклона, за да съвпадне с височината на главното било';

  @override
  String architectRoofRidgeHeightMatched(String degrees, String height) {
    return 'Наклонът е напаснат на $degrees° за кота било ${height}m';
  }

  @override
  String architectRoofSnapHipAngle(String angle) {
    return '$angle° Скат / Мавия';
  }

  @override
  String get architectRoofSnapHipIntersection => 'Пресечна точка на маии (45°)';

  @override
  String get architectRoofSnapCornerHipIntersection =>
      'Пресечна точка с 45° от ръб';

  @override
  String get architectRoofSnapPerpToCorner => 'Перпендикуляр към вътрешен ръб';

  @override
  String get architectRoofSnapRidgeAlignment => 'Подравняване по било / ръб';

  @override
  String get cad3dOrbit => 'Завъртане';

  @override
  String get cad3dPan => 'Преместване';

  @override
  String get cad3dWalk => 'Разходка';

  @override
  String get cad3dNativeDepthOn => 'Ускорено 3D';

  @override
  String get cad3dNativeDepthOff => 'Съвместим режим';

  @override
  String get cad3dShadingSmooth => 'Осветен';

  @override
  String get cad3dShadingFlat => 'Плосък';

  @override
  String get cad3dShadingXray => 'Прозрачен';

  @override
  String get cad3dCamera => 'Изглед';

  @override
  String get cad3dInvertY => 'Обърни вертикалното оглеждане';

  @override
  String get cad3dViewIsometric => 'Изометрия';

  @override
  String get cad3dViewTop => 'Отгоре';

  @override
  String get cad3dViewFront => 'Отпред';

  @override
  String get cad3dViewRight => 'Отдясно';

  @override
  String get cad3dViewBottom => 'Отдолу';

  @override
  String get cad3dViewBack => 'Отзад';

  @override
  String get cad3dThemeBlueprint => 'Чертеж';

  @override
  String get cad3dThemeStudio => 'Студио';

  @override
  String get cad3dThemeBlack => 'Черен';

  @override
  String get cad3dThemeWhite => 'Бял';

  @override
  String get architectProjectionInvalid =>
      'Елементът не се побира. Провери отвора, стената и разстоянията.';

  @override
  String get architectProjectionLeft => 'Вляво';

  @override
  String get architectProjectionRight => 'Вдясно';

  @override
  String get architectProjectionHead => 'До плоча';

  @override
  String get architectProjectionHorizontal => 'Мести странично';

  @override
  String get architectProjectionAlignSill => 'Подравни долу';

  @override
  String get architectProjectionAlignHead => 'Подравни горе';

  @override
  String get architectProjectionNoSlab => 'Няма горна плоча';

  @override
  String get architectProjectionAlignLeft => 'Подравни вляво';

  @override
  String get architectProjectionAlignRight => 'Подравни вдясно';

  @override
  String get architectDistancePrecision => 'Знаци след запетаята';

  @override
  String get architectWizardExample => 'Пример:';

  @override
  String get architectWizardStoreysShort => 'Етажи';

  @override
  String get architectWizardElevation => 'Кота';

  @override
  String get architectWizardHeight => 'H=';

  @override
  String get architectWizardStoreyHeightHelp =>
      'Височина до следващия етаж, от готов под до готов под. Промяната мести горните етажи. Настилките и таваните определят отделно светлата височина.';

  @override
  String get architectWizardElevationHelp =>
      'Кота готов под спрямо проектната нула. Промяната запазва другите коти и преизчислява съседните височини.';

  @override
  String get architectWizardInvalidLevel => 'Проверете котите и височините.';

  @override
  String get architectWizardCreateShort => 'Създай';

  @override
  String get architectWizardHeightReference => 'готов под → готов под';

  @override
  String architectWallConcreteCode(String thickness) {
    return 'СБ $thickness';
  }

  @override
  String architectWallParapetCode(String thickness) {
    return 'Борд $thickness';
  }

  @override
  String architectWallTypeThicknessHint(String name, String thickness) {
    return '$name · $thickness cm';
  }

  @override
  String get architectWallQuickCore => 'Ядро';

  @override
  String get architectWallQuickInsulation => 'Изолация';

  @override
  String get architectWallInvalidThickness => 'Въведете валидна дебелина.';

  @override
  String get architectWallQuickThickness => 'Дебелина';

  @override
  String get wallTypesTitle => 'Типове стени';

  @override
  String get wallNewType => 'Нов тип';

  @override
  String get wallCompositionName => 'Име';

  @override
  String get wallLocation => 'Предназначение';

  @override
  String get wallExterior => 'Външна';

  @override
  String get wallInterior => 'Вътрешна';

  @override
  String get wallLayerCore => 'Ядро';

  @override
  String get wallLayerInsulation => 'Изолация';

  @override
  String get wallLayerFinish => 'Покритие';

  @override
  String get wallLayerRole => 'Роля на слоя';

  @override
  String get wallLayerAdd => 'Добави слой';

  @override
  String get wallLayerUp => 'Нагоре';

  @override
  String get wallLayerDown => 'Надолу';

  @override
  String get wallLayerOutsideInside => 'Вън → вътре';

  @override
  String get wallLayerSides => 'A → B';

  @override
  String get wallLayerInvalid =>
      'Задайте положителни дебелини и непрекъснато ядро.';

  @override
  String get wallSelectedScope => 'Само избраните стени';

  @override
  String wallTypeApply(int count) {
    return 'Приложи към типа ($count)';
  }

  @override
  String get wallTypeReplacement => 'Замени с';

  @override
  String get wallTypeInUse => 'Изберете заместител за стените с този тип.';

  @override
  String get wallCompositionAction => 'Конструкция';

  @override
  String get wallManageTypes => 'Редактирай типовете';

  @override
  String get wallMaterialPlaster => 'Мазилка';

  @override
  String get wallMaterialRender => 'Фасадна мазилка';

  @override
  String get wallMaterialBoard => 'Гипсокартон';

  @override
  String get wallMaterialStone => 'Камък';

  @override
  String get wallPlinth => 'Цокъл';

  @override
  String get wallPlinthFinish => 'Завършек';

  @override
  String get wallPlinthBase => 'Базова кота (m)';

  @override
  String get wallPlinthBaseHelp =>
      'Проектна кота на долния ръб; H се измерва нагоре.';

  @override
  String get wallAdvanced => 'Още';

  @override
  String get wallTypeCopy => 'Копирай типа';

  @override
  String get wallMixedValue => 'Различни';

  @override
  String get wallArc => 'Заоблена стена';

  @override
  String get wallArcPickEnd => 'Посочи края на дъгата';

  @override
  String get wallArcPickThrough => 'Посочи точка на извивката';

  @override
  String get wallArcInvalidRadius => 'Радиусът е твърде малък за тази стена.';

  @override
  String get wallArcPickStart => 'Посочи началото на дъгата';

  @override
  String get wallPlinthEnabled => 'Включен';

  @override
  String get wallArcMode => 'Дъга';

  @override
  String get architectZonePresets => 'Имена и покрития';

  @override
  String get architectZoneManualHelp =>
      'Ръчна: редактиране по точки и отсечки. Махнете отметката за повторно откриване на помещението по стените.';

  @override
  String get architectZoneBoundaryOpen =>
      'Не е открито затворено помещение. Проверете стените за пролуки.';

  @override
  String get architectZoneCrossingRepairHint =>
      'Пресичанията ще се коригират при затваряне.';

  @override
  String get architectZoneBoundaryRepaired =>
      'Пресичанията на границите са коригирани.';

  @override
  String get architectSheets => 'Листове';

  @override
  String get architectModel => 'Модел';

  @override
  String get architectSheetName => 'Лист';

  @override
  String get architectSheetPlan => 'План';

  @override
  String get architectSheetAdd => 'Добави лист';

  @override
  String get architectSheetProperties => 'Свойства на листа';

  @override
  String get architectSheetPlace => 'Постави изглед';

  @override
  String get architectSheetEdit => 'Свойства';

  @override
  String get architectSheetDuplicate => 'Дублирай';

  @override
  String get architectSheetDelete => 'Изтрий';

  @override
  String get architectSheetLock => 'Заключи';

  @override
  String get architectSheetUnlock => 'Отключи';

  @override
  String get architectSheetTemplate => 'Антетка';

  @override
  String get architectSheetExport => 'Експорт PDF';

  @override
  String get architectSheetPrint => 'Печат';

  @override
  String get architectSheetMissingSource =>
      'Липсва източник. Свържи или премахни чертежа преди експорт.';

  @override
  String get architectSheetMixedScales => 'Различни';

  @override
  String get architectSheetFormat => 'Формат';

  @override
  String get architectSheetCustom => 'Собствен';

  @override
  String get architectSheetWidth => 'Ширина (mm)';

  @override
  String get architectSheetHeight => 'Височина (mm)';

  @override
  String get architectSheetMargin => 'Поле (mm)';

  @override
  String get architectSheetNumber => 'Номер';

  @override
  String get architectSheetAuthor => 'Автор';

  @override
  String get architectSheetDate => 'Дата';

  @override
  String get architectSheetNameField => 'Име';

  @override
  String get architectSheetSave => 'Запази';

  @override
  String get architectSheetCancel => 'Отказ';

  @override
  String get architectSheetScale => 'Мащаб';

  @override
  String get architectSheetX => 'X (mm)';

  @override
  String get architectSheetY => 'Y (mm)';

  @override
  String get architectSheetAnchorX => 'Източник X';

  @override
  String get architectSheetAnchorY => 'Източник Y';

  @override
  String get architectSheetRotation => 'Завъртане (°)';

  @override
  String get architectSheetTitle => 'Показвай заглавие';

  @override
  String get architectSheetSource => 'Източник';

  @override
  String get architectSheetAlign => 'Подравни';

  @override
  String get architectSheetLeft => 'Вляво';

  @override
  String get architectSheetRight => 'Вдясно';

  @override
  String get architectSheetTop => 'Горе';

  @override
  String get architectSheetBottom => 'Долу';

  @override
  String get architectSheetSelect => 'Избери листове по реда за експорт';

  @override
  String get architectSheetInvalid =>
      'Въведи валидни положителни размери и поле в листа.';

  @override
  String get architectSheetExportFailed => 'Неуспешен PDF експорт.';

  @override
  String get architectSheetNoViews => 'Няма налични изгледи.';

  @override
  String get architectSheetAddCell => 'Добави поле';

  @override
  String get architectSheetField => 'Поле';

  @override
  String get architectSheetBorder => 'Рамка';

  @override
  String get architectSheetText => 'Текст';

  @override
  String get architectSheetProject => 'Проект';

  @override
  String get architectSheetDrawing => 'Чертеж';

  @override
  String get architectPrintPreview => 'Преглед за печат';

  @override
  String get architectAnnotationSettings => 'Означения';

  @override
  String get architectAnnotationSize => 'Размер на хартия (mm)';

  @override
  String get architectAnnotationReset => 'По профил';

  @override
  String get architectAnnotationProfile => 'Профил';

  @override
  String get architectAnnotationElement => 'Отделно означение';

  @override
  String get architectAnnotationOrdinary => 'Надписи';

  @override
  String get architectAnnotationDimension => 'Размери';

  @override
  String get architectAnnotationArea => 'Квадратури';

  @override
  String get architectAnnotationRoomName => 'Имена на помещения';

  @override
  String get architectAnnotationTitle => 'Заглавия';

  @override
  String get architectAnnotationTable => 'Таблици';

  @override
  String get architectAnnotationSymbol => 'Символи';

  @override
  String get architectSheetVisibility => 'Видимост';

  @override
  String get architectSheetAxes => 'Оси';

  @override
  String get architectSheetZones => 'Зони';

  @override
  String get architectSheetDimensions => 'Размери';

  @override
  String get architectSheetAnnotations => 'Текст';

  @override
  String get architectSheetMarkers => 'Маркери';

  @override
  String get architectSheetEmpty =>
      'Създай лист и постави план, разрез или фасада.';

  @override
  String get architectSheetSaveView => 'Запази изглед';

  @override
  String get architectSheetTemplateName => 'Име на шаблона';

  @override
  String architectAreaWithUnit(String unit) {
    return 'Площ ($unit²)';
  }

  @override
  String get architectSheetTemplateOverflow =>
      'Текстът излиза от полето в антетката. Увеличи полето преди експорт.';

  @override
  String get snapMidpointAlignment => 'По средна точка';

  @override
  String get architectComponentLibraryTitle => 'Библиотека';

  @override
  String get architectComponentStudioTitle => 'Компонентно студио';

  @override
  String get architectComponentStudioBtn => 'Код';

  @override
  String get architectCategorySanitary => 'Санитария';

  @override
  String get architectCategoryFurniture => 'Мебели';

  @override
  String get architectCategoryKitchen => 'Кухня';

  @override
  String get architectCategoryStorage => 'Съхранение';

  @override
  String get architectCategoryOffice => 'Офис';

  @override
  String get architectCategoryEquipment => 'Оборудване';

  @override
  String get architectCategoryLighting => 'Осветление';

  @override
  String get architectCategoryOutdoor => 'Екстериор';

  @override
  String get architectComponentRotateBtn => 'Завърти на 90° (R)';

  @override
  String get architectComponentSavedMsg =>
      'Обектът е запазен в потребителската библиотека!';

  @override
  String get architectComponentCompileBtn => 'Преглед';

  @override
  String get architectComponentSaveBtn => 'Запази';

  @override
  String get architectComponentTemplateHint => 'Избери шаблон...';

  @override
  String get architectComponentExportDartTooltip =>
      'Копирай Dart клас в клипборда';

  @override
  String get architectComponentExportDartMsg =>
      'Dart кодът е копиран в клипборда!';

  @override
  String get architect2dPlanSymbol => '2D Символ за план';

  @override
  String get architect3dSolidMesh => '3D Солиден меш';

  @override
  String get architectPlacementModeWall => 'До стена';

  @override
  String get architectPlacementModeFree => 'Свободно стоящ';

  @override
  String get architectLayerFurniture => 'Слой Обзавеждане';

  @override
  String get architectComponentNoItems => 'Няма намерени елементи';

  @override
  String get architectFurnishing => 'Обзавеждане';

  @override
  String get architectLibrary => 'Библиотека';

  @override
  String get architectLibraryAll => 'Всички';

  @override
  String get architectLibrarySourceAll => 'Всички източници';

  @override
  String get architectLibraryBuiltIn => 'Служебни';

  @override
  String get architectLibraryCustom => 'Мои обекти';

  @override
  String get architectLibraryImport => 'Импорт JSON';

  @override
  String get architectLibraryImportHelp =>
      'Импортирайте параметричен обект (.json) с размери в метри. Прегледайте и запазете в студиото.';

  @override
  String get architectLibraryImportError =>
      'Обектът не може да бъде импортиран.';

  @override
  String get architectComponentInvalid =>
      'Проверете кода, размерите и поддържаните форми на обекта.';

  @override
  String get architectComponentCustomName => 'Потребителски обект';

  @override
  String get architectComponentCode => 'Код';

  @override
  String get architectComponentPreview => 'Преглед';

  @override
  String get architectComponentLockRatio => 'Заключи X:Y:Z';

  @override
  String get architectComponentLockRatioHelp =>
      'Промяната на един размер мащабира и трите с един и същ коефициент.';

  @override
  String get architectComponentDimensionError =>
      'Въведете размер от 0,1 до 10000 cm.';

  @override
  String get architectComponentDefaults => 'Начален размер';

  @override
  String get architectTemplateDesk => 'Бюро';

  @override
  String get architectTemplateBasin => 'Умивалник';

  @override
  String get architectComponentToiletWall => 'Конзолна тоалетна';

  @override
  String get architectComponentToiletFloor => 'Стояща тоалетна';

  @override
  String get architectComponentVanity => 'Шкаф с умивалник';

  @override
  String get architectComponentBathtub => 'Вана';

  @override
  String get architectComponentShower => 'Душ кабина';

  @override
  String get architectComponentBedDouble => 'Двойно легло';

  @override
  String get architectComponentBedSingle => 'Единично легло';

  @override
  String get architectComponentWardrobe => 'Гардероб';

  @override
  String get architectComponentDining => 'Маса със столове';

  @override
  String get architectComponentSofa => 'Диван';

  @override
  String get architectComponentDesk => 'Бюро';

  @override
  String get architectComponentKitchenBase => 'Долен шкаф';

  @override
  String get architectComponentKitchenSink => 'Шкаф с мивка';

  @override
  String get architectComponentFridge => 'Хладилник';

  @override
  String get architectComponentCooktop => 'Котлони с фурна';

  @override
  String get architectComponentExportJsonTooltip => 'Копирай JSON';

  @override
  String get architectComponentExportJsonMsg => 'JSON е копиран';

  @override
  String get architectComponentView2d => '2D изглед';

  @override
  String get architectComponentView3d => '3D изглед';

  @override
  String get architectApartment => 'Апартамент';

  @override
  String get architectRoom => 'Помещение';

  @override
  String get architectApartmentRooms => 'Помещения';

  @override
  String get architectUnassignedRooms => 'Без апартамент';

  @override
  String get architectApartmentAutoAssignment => 'Автоматично';

  @override
  String get architectApartmentNoRooms => 'Няма помещения в контура.';

  @override
  String get architectApartmentBoundaryHelp =>
      'Начертайте ръчно по осите на вътрешните стени и външните лица на външните стени.';

  @override
  String get architectApartmentGross => 'Площ по контур';

  @override
  String get architectApartmentNet => 'Чиста площ';

  @override
  String get architectApartmentRoomsHelp =>
      'Помещенията се включват автоматично според най-голямата обща площ с апартамента. Всяко помещение се отчита изцяло само веднъж. При равни площи се запазва текущият апартамент. Помещенията извън всички апартаменти остават без апартамент.';

  @override
  String get architectLineParallelHelp =>
      'Докоснете за успоредно местене на линията. Задръжте за въвеждане на отместване със знак.';

  @override
  String get architectLineJoinSuccess => 'Линиите са свързани';

  @override
  String get architectLineJoinIncompatible => 'Линиите не могат да се свържат';

  @override
  String get architectLineJoinSelectSecond =>
      'Изберете втора линия за свързване';

  @override
  String get architectLineEditRejected => 'Линията трябва да е поне 1 mm.';

  @override
  String get architectLineStyle => 'Вид линия';

  @override
  String get architectLineSolid => 'Непрекъсната';

  @override
  String get architectLineDashed => 'Прекъсната';

  @override
  String get architectLineShortDashed => 'Къси тирета';

  @override
  String get architectLineLongDashed => 'Дълги тирета';

  @override
  String get architectLineDotted => 'Точкова';

  @override
  String get architectLineSparseDotted => 'Редки точки';

  @override
  String get architectLineDashDot => 'Тире–точка';

  @override
  String get architectLineDashDoubleDot => 'Тире–две точки';

  @override
  String get architectLineLongDashDot => 'Дълго тире–точка';

  @override
  String get architectLineLongShortDash => 'Дълго–късо тире';

  @override
  String get architectLineDoubleDashDot => 'Две тирета–точка';

  @override
  String get architectLinePatternEditor => 'Собствена шарка';

  @override
  String get architectLineDash => 'Тире';

  @override
  String get architectLineGap => 'Пауза';

  @override
  String get architectLinePatternHint =>
      'Тирета, паузи и символи. Размерите са върху листа.';

  @override
  String get architectLinePatternRange => 'Въведете 0.1–100 mm.';

  @override
  String get architectLinePatternAdd => 'Добави двойка';

  @override
  String get architectLinePatternRemove => 'Премахни двойка';

  @override
  String get architectLinePowerLine => 'Далекопровод';

  @override
  String get architectLineSymbol => 'Символ';

  @override
  String get architectLineSymbolNone => 'Без';

  @override
  String get architectLineSymbolLightning => 'Светкавица';

  @override
  String get architectLineSymbolCircle => 'Кръг';

  @override
  String get architectLineSymbolSquare => 'Квадрат';

  @override
  String get architectLineSymbolTriangle => 'Триъгълник';

  @override
  String get architectLineSymbolDiamond => 'Ромб';

  @override
  String get architectLineSymbolCross => 'Кръст';

  @override
  String get architectLineSymbolArrow => 'Стрелка';

  @override
  String get architectLineSymbolChevron => 'Шеврон';

  @override
  String get architectLineSymbolCustom => 'Собствена форма';

  @override
  String get architectLineSymbolSettings => 'Поставяне';

  @override
  String get architectLineSymbolDraw => 'Редактирай формата';

  @override
  String get architectLineSymbolSize => 'Размер';

  @override
  String get architectLineSymbolSpacing => 'Повторение';

  @override
  String get architectLineSymbolFollow => 'По посоката на линията';

  @override
  String get architectLineSymbolClearLine => 'Пауза около знака';

  @override
  String get architectLineSymbolDrawHint =>
      'Поставете възли или рисувайте свободно. Може да добавяте отделни щрихи.';

  @override
  String get architectLineSymbolPoints => 'С възли';

  @override
  String get architectLineSymbolFreehand => 'Свободно';

  @override
  String get architectToolHatch => 'Щриховка';

  @override
  String architectSelectionHatchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count щриховки',
      one: '1 щриховка',
    );
    return '$_temp0';
  }

  @override
  String get architectHatchPattern => 'Шарка';

  @override
  String get architectHatchCustom => 'Собствена щриховка';

  @override
  String get architectHatchHint =>
      'Слоеве от линии или символи. Стъпката и размерите са в mm върху листа.';

  @override
  String get architectHatchDiagonal => 'Диагонална';

  @override
  String get architectHatchReverseDiagonal => 'Обратна диагонална';

  @override
  String get architectHatchHorizontal => 'Хоризонтална';

  @override
  String get architectHatchVertical => 'Вертикална';

  @override
  String get architectHatchCross => 'Мрежа';

  @override
  String get architectHatchDiagonalCross => 'Кръстосана';

  @override
  String get architectHatchBrick => 'Тухли';

  @override
  String get architectHatchConcrete => 'Бетон';

  @override
  String get architectHatchDots => 'Точки';

  @override
  String get architectHatchEarth => 'Почва';

  @override
  String get architectHatchScale => 'Мащаб';

  @override
  String get architectHatchBorder => 'Контур';

  @override
  String architectHatchLayer(int number) {
    return 'Слой $number';
  }

  @override
  String get architectHatchAddLayer => 'Добави слой';

  @override
  String get architectHatchSpacing => 'Стъпка';

  @override
  String get architectHatchPhase => 'Отместване';

  @override
  String get architectHatchShift => 'Разминаване';

  @override
  String get architectHatchSymbolsOnly => 'Само символи';

  @override
  String get architectHatchFinish => 'Завърши';

  @override
  String get architectHatchDrawHint =>
      'Поставете поне три възела и затворете контура.';

  @override
  String get architectLineHatchBrickJoint => 'Фуги';

  @override
  String get architectLineHatchAggregate => 'Камъчета';

  @override
  String get architectLineHatchGrain => 'Зърна';

  @override
  String get architectLineHatchDots => 'Точки';

  @override
  String get architectLineHatchEarth => 'Почва';

  @override
  String get architectLineSymbolNewStroke => 'Нов щрих';

  @override
  String get architectLineSymbolCloseStroke => 'Затвори щриха';

  @override
  String architectLineSymbolRange(String minimum, String maximum, String unit) {
    return 'Въведете от $minimum до $maximum $unit.';
  }

  @override
  String get architectViewUnlimited => 'Без ограничение';

  @override
  String get architectViewDepth => 'Обхват';

  @override
  String get architectViewDepthInvalid => 'Въведи крайно разстояние поне 1 cm.';

  @override
  String get architectDrainageTitle => 'Отводняване';

  @override
  String get architectDrainageGutter => 'Улук';

  @override
  String get architectDrainagePipes => 'Водосточни тръби';

  @override
  String get architectDrainagePipe => 'ВТ';

  @override
  String get architectDrainageSmart => 'Смарт ВТ';

  @override
  String get architectDrainageProfile => 'Профил';

  @override
  String get architectDrainageHalfRound => 'Полукръгъл';

  @override
  String get architectDrainageBox => 'Правоъгълен';

  @override
  String get architectDrainageMaterial => 'Материал';

  @override
  String get architectDrainageSteel => 'Поцинкована стомана';

  @override
  String get architectDrainageAluminium => 'Алуминий';

  @override
  String get architectDrainagePvc => 'PVC';

  @override
  String get architectDrainageCopper => 'Мед';

  @override
  String get architectDrainageWidth => 'Ширина';

  @override
  String get architectDrainageDepth => 'Дълбочина';

  @override
  String get architectDrainageAdd => 'Добави ВТ';

  @override
  String get architectDrainagePlace => 'Посочи в плана';

  @override
  String get architectDrainagePrompt => 'Посочи място върху стрехата.';

  @override
  String get architectDrainageOffset => 'От началото на стрехата';

  @override
  String get architectDrainageDiameter => 'Диаметър';

  @override
  String get architectDrainageClearance => 'От фасадата';

  @override
  String get architectDrainageOutlet => 'Кота на изхода';

  @override
  String get architectDrainageBend => 'Ъгъл на колената';

  @override
  String get architectDrainageFacade => 'Фасада';

  @override
  String get architectDrainageWall => 'Стена';

  @override
  String get architectDrainageAuto => 'Автоматично';

  @override
  String get architectDrainageWaypoints => 'Междинни точки';

  @override
  String get architectDrainageWaypointsHelp =>
      'Празно: автоматично трасе. За ръчно: един ред за точка — отместване навътре; абсолютна кота (m), отгоре надолу.';

  @override
  String get architectDrainageInvalid => 'Невалидна стойност.';

  @override
  String get architectDrainageReady => 'Трасето е свободно.';

  @override
  String get architectDrainageNoFacade => 'Не е намерена фасада. Избери стена.';

  @override
  String get architectDrainageBlocked =>
      'Недостатъчно място за трасе. Промени мястото или междинните точки.';

  @override
  String get architectDrainageOutside => 'Мястото е извън свободната стреха.';

  @override
  String get architectDrainageNoRoof => 'Първо създай покрив.';

  @override
  String get architectRoofTimberTab => 'Конструкция';

  @override
  String get architectViewStep => 'Добави чупка';

  @override
  String get architectViewEditHint =>
      'Преместете краищата, чупките или далечната граница и приложете.';

  @override
  String get architectViewDepthBehindSteps =>
      'Поставете далечната граница след всички сегменти.';

  @override
  String get architectViewStraight => 'Изправи';

  @override
  String get architectViewStepHint =>
      'Посочете точка до маркера за мястото и отместването на чупката. Повторете „Добави чупка“ за още сегменти.';

  @override
  String get stairConstruction => 'Конструкция';

  @override
  String get stairSteel => 'Стомана';

  @override
  String get stairTreadThickness => 'Дебелина на стъпалото';

  @override
  String get stairStringerWidth => 'Ширина на косоура/тетивата';

  @override
  String get stairStringerDepth => 'Височина на косоура/тетивата';

  @override
  String get architectHatchWood => 'Дърво';

  @override
  String get architectHatchMetal => 'Метал';

  @override
  String get architectHatchGenerator => 'Генератор на модел';

  @override
  String get architectHatchGeneratorHint =>
      'Начертай мотив с отсечки. Задай размер и разстояние между редовете; прегледът се обновява при чертане.';

  @override
  String get architectSketchOrtho => 'Ортогонални линии';

  @override
  String get architectSketchPreview => 'Преглед на повторението';

  @override
  String get architectTerrain => 'Линия терен';

  @override
  String get architectTerrainHint =>
      'Поставяй точки отляво надясно. Потвърди, за да скриеш сградата под линията в тази фасада.';

  @override
  String get architectRoofPitchEdit => 'Наклон на покрив';

  @override
  String get architectRoofPitchHint =>
      'Мести зелената точка за наклона; тя прилепва към съседния покрив. Натисни върху ската за неподвижна ос. Приближавай с два пръста или колелцето на мишката.';

  @override
  String get architectRoofPitchAxis => 'Ос при стрехата';

  @override
  String get architectStrokeWeight => 'Дебелина на линия';

  @override
  String get architectCutOpening => 'Изрежи отвор';

  @override
  String get architectCutOpeningHint =>
      'Очертайте затворен контур вътре в избрания елемент и потвърдете.';

  @override
  String get architectCutOpeningInvalid =>
      'Отворът трябва да е вътре в елемента, без да докосва границата му или друг отвор.';

  @override
  String get architectHatchAutoHint =>
      'Запълване: посочете вътре в затворен контур.';

  @override
  String get architectHatchAutoFailed =>
      'Не е намерен затворен контур. Затворете границата или я очертайте ръчно.';

  @override
  String get appSettingsTitle => 'Настройки';

  @override
  String get uiSettingsCategory => 'UI';

  @override
  String get contextMenuTitle => 'Контекстно меню';

  @override
  String get contextMenuLayout => 'Подредба';

  @override
  String get contextMenuCircle => 'Постоянен кръг';

  @override
  String get contextMenuGrid => 'Постоянна решетка';

  @override
  String get contextMenuCombination => 'Комбинация';

  @override
  String get contextMenuDefault => 'Стандартна';

  @override
  String get contextMenuSaveAs => 'Нова комбинация';

  @override
  String get contextMenuEdit => 'Редактирай';

  @override
  String get contextMenuName => 'Име';

  @override
  String get contextMenuEmpty => 'Празно';

  @override
  String get contextMenuMore => 'Още';

  @override
  String get contextMenuAssignHint =>
      'Посочете място, за да изберете команда. Ако тя вече присъства, двете места се разменят. Останалите команди са в „Още“.';

  @override
  String contextMenuPage(int page, int total) {
    return 'Още команди: страница $page от $total. Натиснете за следващата.';
  }

  @override
  String get uiSettingsSaveFailed =>
      'Настройките не могат да се запазят. Опитайте отново.';

  @override
  String get architectViewVisibility => 'Видимост';

  @override
  String get architectSectionVisibility => 'Видимост в разрез';

  @override
  String get architectSectionProjectRules => 'За проекта';

  @override
  String get architectSectionViewRules => 'Този разрез';

  @override
  String get architectSectionInherit => 'По проекта';

  @override
  String get architectSectionCutAndView => 'Разрез и изглед';

  @override
  String get architectSectionCutOnly => 'Само разрез';

  @override
  String get architectSectionHidden => 'Скрито';

  @override
  String get architectSectionVisibilityHelp =>
      'Настройките за проекта важат за всички разрези, освен ако конкретен разрез има изключение. „Само разрез“ показва действителното сечение с разрезната равнина и пропуска изгледа зад нея. 3D и фасадите запазват обичайната си видимост.';

  @override
  String get bimGroup => 'Групирай';

  @override
  String get bimUngroup => 'Разгрупирай';

  @override
  String get bimEditGroup => 'Редактирай групата';

  @override
  String get bimInsideGroup => 'В група';

  @override
  String get bimGroupDone => 'Готово';

  @override
  String get bimGroupLabel => 'Група';

  @override
  String get bimOffsetDistance => 'Разстояние';

  @override
  String get bimOffsetCopy => 'Копие';

  @override
  String get bimOffsetSide => 'Посочи страна';

  @override
  String get bimOffsetInvalid =>
      'Невъзможен офсет. Провери избора, разстоянието и страната.';

  @override
  String get bimOffsetHelp =>
      'Въведи разстояние и посочи страна. Копие създава успоредни елементи; без отметката променя избраните. Свързаните отсечки се срещат в общи ъгли. Отворите в затворени контури се запазват. Копие на цяла група създава нова група; при редактиране на група копията остават в нея. За разклонени вериги или групи с текстове и символи избери приложимите отсечки без разклонение чрез Редактирай групата.';

  @override
  String get architectToolFloorDrain => 'Сифон';

  @override
  String get architectDrainRound => 'Кръгъл';

  @override
  String get architectDrainLinear => 'Линеен';

  @override
  String get architectDrainSlope => 'Наклон';

  @override
  String get architectDrainDiameter => 'Диаметър';

  @override
  String get architectDrainLength => 'Дължина';

  @override
  String get architectDrainWidth => 'Ширина';

  @override
  String get architectDrainFromRoom => 'Помещение';

  @override
  String get architectDrainOutline => 'Контур';

  @override
  String get architectDrainHint =>
      'Кликни първата точка или зеленото тикче за потвърждение на пода. Дръпни дръжката, за да преместиш сифона.';

  @override
  String get architectDrainOutsideFloor => 'Сифонът е извън пода';

  @override
  String get architectDrainNearDoor => 'Сифонът е близо до врата';

  @override
  String get architectDrainRoomNotFound => 'Тук няма затворено помещение';

  @override
  String get architectDrainInvalid => 'Сифонът не може да се постави тук';

  @override
  String architectSelectionDrainsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сифона',
      one: '1 сифон',
    );
    return '$_temp0';
  }

  @override
  String get architectComponentLinearDrain => 'Линеен сифон';

  @override
  String get architectComponentFloorDrain => 'Подов сифон';

  @override
  String get architectFloorDrainLibraryDesc =>
      'Чертане на под с наклони и коти към сифон';

  @override
  String get architectCategoryViews => 'Изгледи';

  @override
  String get architectToolSection => 'Разрез';

  @override
  String get architectToolElevation => 'Фасада';

  @override
  String get architectOpenView => 'Отвори изглед';

  @override
  String get architectOpenSection => 'Отвори разрез';

  @override
  String get architectOpenElevation => 'Отвори фасада';

  @override
  String get architectViewRename => 'Преименувай';

  @override
  String get architectSectionHint => 'Две точки → посока';

  @override
  String get architectElevationHint => 'Две точки → посока';

  @override
  String get architectSelectModeRect => 'Рамка';

  @override
  String get architectSelectModePolygon => 'Полигон';

  @override
  String get architectSelectMarqueeHint =>
      'Посочи срещуположни ъгли за селекция';

  @override
  String get architectSelectFinish => 'Селектирай';

  @override
  String get architectFillSolid => 'Плътно';

  @override
  String get architectDrawingColor => 'Цвят';

  @override
  String get architectColorGeneral => 'Основни';

  @override
  String get architectColorBgOup => 'България · ОУП';

  @override
  String get architectColorBgPup => 'България · ПУП';

  @override
  String get architectColorGermany => 'Германия · PlanZV';

  @override
  String get architectColorSearch => 'Код или име';

  @override
  String get architectColorCustom => 'Собствен';

  @override
  String get architectColorOpacity => 'Непрозрачност';

  @override
  String get architectColorInfo => 'За палитрата';

  @override
  String get architectColorHexError => 'Въведете шест шестнадесетични цифри.';

  @override
  String get architectColorApprox =>
      'Екранните цветове са приблизителни. RAL кодът се пази отделно; за точно съвпадение при печат използвайте калибрирана палитра.';

  @override
  String get architectColorBgInfo =>
      'Наредба № 8, приложение № 2: таблица 1 за ОУП, таблица 2 за ПУП. + и ++ означават изсветляване, − означава потъмняване. Палитрата съдържа цветове, а пълните условни знаци може да изискват контури, ивици и надписи. За ПУП оцветяването на зоните е за ПРЗ/ПЗ.';

  @override
  String get architectColorDeInfo =>
      'Цветови групи за FNP/B-Plan по PlanZV. Наредбата задава цветови наименования, а не задължителни RGB или RAL кодове. Нюансите тук са работни приближения; пълните означения включват и линии, щрихи и надписи.';

  @override
  String get architectColorBlack => 'Черно';

  @override
  String get architectColorWhite => 'Бяло';

  @override
  String get architectColorGray => 'Сиво';

  @override
  String get architectColorRed => 'Червено';

  @override
  String get architectColorBlue => 'Синьо';

  @override
  String get architectColorGreen => 'Зелено';

  @override
  String get architectColorYellow => 'Жълто';

  @override
  String get architectColorOrange => 'Оранжево';

  @override
  String get architectColorResidential => 'Жилищни функции';

  @override
  String get architectColorPublicServices => 'Обществено обслужване';

  @override
  String get architectColorIndustrial => 'Производствени дейности';

  @override
  String get architectColorStorage => 'Складови дейности';

  @override
  String get architectColorGreenSpace => 'Озеленяване';

  @override
  String get architectColorArable => 'Ниви';

  @override
  String get architectColorPerennial => 'Трайни насаждения';

  @override
  String get architectColorUncultivated => 'Необработваеми земи';

  @override
  String get architectColorForest => 'Гори';

  @override
  String get architectColorRecreationalForest => 'Рекреационни гори';

  @override
  String get architectColorWater => 'Водни площи';

  @override
  String get architectColorTransport => 'Транспорт';

  @override
  String get architectColorUtilities => 'Техническа инфраструктура';

  @override
  String get architectColorHousingLowHigh => 'Жилищни зони · Жм/Жг';

  @override
  String get architectColorHousingMediumComplex => 'Жилищни зони · Жс/Жк';

  @override
  String get architectColorVillas => 'Вилни зони · фон';

  @override
  String get architectColorSpecialPurpose => 'Специално предназначение';

  @override
  String get architectColorCulturalLand => 'Терени на културното наследство';

  @override
  String get architectColorPrimaryRoad => 'Първостепенни улици';

  @override
  String get architectColorSecondaryRoad => 'Второстепенни улици';

  @override
  String get architectColorCollectingRoad => 'Събирателни улици';

  @override
  String get architectColorServingRoad => 'Обслужващи улици и паркинги';

  @override
  String get architectColorPedestrian => 'Тротоари и пешеходни площи';

  @override
  String get architectColorHousingExisting => 'Жилищни сгради · съществуващи';

  @override
  String get architectColorHousingNew => 'Жилищни сгради · нови';

  @override
  String get architectColorPublicExisting => 'Обществени сгради · съществуващи';

  @override
  String get architectColorPublicNew => 'Обществени сгради · нови';

  @override
  String get architectColorHeritageBuilding => 'Сгради · културни ценности';

  @override
  String get architectColorMixedUse => 'Смесено предназначение';

  @override
  String get architectColorSpecialUse => 'Специални строителни територии';

  @override
  String get architectColorRailway => 'Железопътни терени';

  @override
  String get architectColorAgriculture => 'Земеделски площи';

  @override
  String get architectRotationPivot => 'Избери център';

  @override
  String get architectRotationReference => 'Избери точка от елемента';

  @override
  String get architectRotationTarget => 'Избери ъгъл';

  @override
  String get architectRotationPickPivot => 'Избери друг център';

  @override
  String get architectMirrorPickAnchor => 'Избери друга опорна точка';

  @override
  String get architectViewChooseArrow => 'Избери стрелка';

  @override
  String get architectVisibleInSection => 'Видим в разрез';

  @override
  String architectViewDirectionSide(int side) {
    return 'Посока на гледане $side';
  }

  @override
  String get wallPickerTitle => 'Стени';

  @override
  String get wallCategoryExterior => 'Външни';

  @override
  String get wallCategoryInterior => 'Вътрешни';

  @override
  String get wallCategoryParapet => 'Парапети';

  @override
  String get wallFavorites => 'Любими';

  @override
  String get wallFavoriteToggle => 'Любим тип';

  @override
  String get wallPickerSearch => 'Тип, материал, дебелина';

  @override
  String get wallPickerEmpty => 'Няма резултати';

  @override
  String wallVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count варианта',
      one: '1 вариант',
    );
    return '$_temp0';
  }

  @override
  String get wallVariant => 'Вариант';

  @override
  String get wallNewVariant => 'Нов вариант';

  @override
  String get wallTypesShort => 'Типове';

  @override
  String get wallNoInsulation => 'Без изолация';

  @override
  String get wallParapetCap => 'С шапка';

  @override
  String get wallParapetHandrail => 'С ръкохват';

  @override
  String wallMaterialThickness(String material, String thickness) {
    return '$material $thickness';
  }

  @override
  String get wallNewTypeScope => 'Нов тип · съществуващите стени се запазват';

  @override
  String get wallOptionalName => 'Незадължително';

  @override
  String get wallSaveToCatalog => 'Запази като тип';

  @override
  String get wallLayerDetails => 'Данни за слоя';

  @override
  String get wallTypeDetails => 'Данни за типа';

  @override
  String get wallLayerPosition => 'Позиция';

  @override
  String wallLayerBefore(String layer) {
    return 'Преди $layer';
  }

  @override
  String get wallLayerAtEnd => 'Накрая';

  @override
  String get wallLayerMaterial => 'Материал';

  @override
  String get wallLayerCoatings => 'Покрития';

  @override
  String get wallCopyFinish => 'Копирай A → B';

  @override
  String get wallCopyFinishHelp =>
      'Копирай покритията от A към непокритата страна B';

  @override
  String get wallLayerCoreError =>
      'Ядрото трябва да е непрекъснато и от основни материали.';

  @override
  String get wallDrawingMode => 'Режим на чертане';

  @override
  String get wallParapetDefaultHeight => 'Височина по подразбиране';

  @override
  String get wallCreate => 'Създай';

  @override
  String get wallLayerLimit => 'Допускат се до 20 слоя.';

  @override
  String get wallInvalidHeight => 'Въведете положителна височина.';

  @override
  String wallParapetGroup(String finish, String material) {
    return '$finish · $material';
  }

  @override
  String get roofUiShape => 'Форма';

  @override
  String get roofUiAssembly => 'Състав';

  @override
  String get roofUiDetails => 'Детайли';

  @override
  String get roofUiSettings => 'Настройки';

  @override
  String get roofUiMethod => 'Начин';

  @override
  String get roofUiOnlyPlane => 'Този скат';

  @override
  String roofUiWholeRoof(int count) {
    return 'Покривът ($count)';
  }

  @override
  String get roofUiNewScope => 'За нови покриви';

  @override
  String get roofUiSaveDefaults => 'За следващите покриви';

  @override
  String get roofUiScopeHelp =>
      'Променят се само редактираните полета. Местата на тръбите остават към своя скат.';

  @override
  String get roofUiIndependentHelp =>
      'Промяната на един наклон прави ската независим.';

  @override
  String get roofUiPreview => 'Схема';

  @override
  String get roofUiPreviewHelp =>
      'Сечението следва текущите настройки. Докоснете за мащабиране.';

  @override
  String get roofUiNumericInvalid => 'Въведете валидна стойност.';

  @override
  String get roofUiLayerPosition => 'Позиция';

  @override
  String roofUiBeforeLayer(String layer) {
    return 'Преди $layer';
  }

  @override
  String get roofUiLayerEnd => 'Накрая';

  @override
  String get roofUiAbove => 'Над ребрата';

  @override
  String get roofUiBetween => 'Между ребрата';

  @override
  String get roofUiBelow => 'Под ребрата';

  @override
  String get roofUiLayerActions => 'Действия за слоя';

  @override
  String get roofUiLayerEdit => 'Слой';

  @override
  String get roofUiStructureZone => 'Конструктивна зона';

  @override
  String get roofUiInsulationFit =>
      'Изолацията между ребрата надвишава височината им.';

  @override
  String get roofUiParallelZone =>
      'Използвайте един запис за зоната на ребрата и изолацията между тях.';

  @override
  String get roofUiAutoBreak => 'Автоматично пречупване';

  @override
  String roofUiPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count точки',
      one: '1 точка',
    );
    return '$_temp0';
  }

  @override
  String get roofUiAutoPreview => 'Нов покрив';

  @override
  String get roofUiAddRoof => 'Добави';

  @override
  String roofUiReplaceRoof(int index, int count) {
    return 'Замени покрив $index ($count)';
  }

  @override
  String get roofUiCreate => 'Създай';

  @override
  String get roofUiReplace => 'Замени';

  @override
  String get roofUiTarget => 'Прилагане';

  @override
  String roofUiGeneratedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ската',
      one: '1 скат',
    );
    return '$_temp0';
  }

  @override
  String get roofUiReviewHelp => 'Останалите покриви се запазват.';

  @override
  String get roofUiUntouched => 'Запази текущото';

  @override
  String roofUiReplaceFloor(int count) {
    return 'Всички на етажа ($count)';
  }

  @override
  String get roofUiNewLegend => 'Нов';

  @override
  String get roofUiKeptLegend => 'Запазени';

  @override
  String get architectHatchTransformHelp =>
      'Плъзнете за посока и мащаб на щриховката. Мащабът се захваща през 10%, а посоката — през 45°.';

  @override
  String get wallSystem => 'Система';

  @override
  String get wallSystemLayered => 'Слоеста';

  @override
  String get wallSystemLogs => 'Трупи';

  @override
  String get wallSystemFrame => 'Гипсокартон';

  @override
  String get wallSystemPanels => 'Термопанели';

  @override
  String get wallMaterialSteel => 'Стомана';

  @override
  String get wallMaterialPir => 'PIR';

  @override
  String get wallLogOverlap => 'Застъпване (%)';

  @override
  String get wallLogTail => 'Издаване (× диаметър)';

  @override
  String get wallLogPitch => 'Височина на реда';

  @override
  String get wallStudSpacing => 'Стъпка на профилите';

  @override
  String get wallStudWidth => 'Ширина на профила';

  @override
  String get wallMetalThickness => 'Дебелина на метала';

  @override
  String get wallCavityInsulation => 'Вата в кухината';

  @override
  String get wallSupportDepth => 'Подконструкция';

  @override
  String get wallPanelModule => 'Ширина на панела';

  @override
  String get wallPanelMount => 'Монтаж';

  @override
  String get wallPanelInFront => 'Пред колоните';

  @override
  String get wallPanelBetween => 'Между колоните';

  @override
  String get wallPanelsHorizontal => 'Хоризонтални панели';

  @override
  String get wallSystemInvalid => 'Проверете размерите на системата.';

  @override
  String get wallSystemStraightOnly => 'Тази система използва прави стени.';

  @override
  String get wallLogHelp =>
      'В план се показва номиналният диаметър. Разрезите и 3D запазват кръглите трупи, застъпването и разминатите редове в ъглите.';

  @override
  String get wallFrameHelp =>
      'Плоскостите, профилите и ватата имат отделни размери.';

  @override
  String get wallPanelHelp =>
      'Панелът и подконструкцията имат отделни дебелини. Опорите се закрепват към избраните лица на колоните.';

  @override
  String get wallColumnSupports => 'Опори към колони';

  @override
  String get wallMountingOffset => 'Монтажен отстъп';

  @override
  String get wallMissingSupports =>
      'Липсва опорна колона. Изберете заместител.';

  @override
  String get wallLogCasing => 'Обсада на отвори';

  @override
  String get wallLogCasingWidth => 'Ширина на обсадата';

  @override
  String get wallLogSettlement => 'Място за слягане';

  @override
  String get architectRoofPresetLogTimber => 'Дървен · трупи';

  @override
  String get wallLogDiameter => 'Диаметър';

  @override
  String get wallRemoveMissingSupports => 'Премахни липсващите';

  @override
  String get roofPanelPitched => 'Термопанели · скатен';

  @override
  String get roofPanelMembrane => 'Термопанели · мембрана';

  @override
  String get roofPanelThickness => 'Панел';

  @override
  String get roofPanelSkin => 'Обшивка';

  @override
  String get roofPanelModule => 'Модул';

  @override
  String get roofPanelRib => 'Височина на профила';

  @override
  String get roofPanelMinSlope => 'Мин. наклон';

  @override
  String get roofPanelFrame => 'Метална конструкция';

  @override
  String get roofPanelBeamDepth => 'Височина на гредата';

  @override
  String get roofPanelBeamWidth => 'Ширина на гредата';

  @override
  String get roofPanelWeb => 'Стебло';

  @override
  String get roofPanelFlange => 'Пояс';

  @override
  String get roofPanelFramesSpacing => 'Стъпка на рамките';

  @override
  String get roofPanelPurlinDepth => 'Височина на столицата';

  @override
  String get roofPanelPurlinWidth => 'Пояс на столицата';

  @override
  String get roofPanelPurlinMetal => 'Метал на столицата';

  @override
  String get roofPanelPurlinSpacing => 'Стъпка на столиците';

  @override
  String get roofPanelCutback => 'Отдръпване на ядрото';

  @override
  String get roofPanelUpstand => 'Борд';

  @override
  String get roofPanelInvalid =>
      'Проверете размерите на панела и конструкцията.';

  @override
  String get roofPanelSlopeInvalid =>
      'Наклонът е под минимума за избраната система.';

  @override
  String get roofPanelHelp =>
      'Цели панели по ската върху Z-столици и I-греди. Размерите и минималният наклон се задават за избраната система.';

  @override
  String get roofPanelColumns => 'Опорни колони';

  @override
  String get roofGutterPosition => 'Разположение';

  @override
  String get roofGutterExternal => 'Външен';

  @override
  String get roofGutterInternal => 'Вътрешен';

  @override
  String get roofGutterInternalHelp =>
      'Открито кутиеобразно корито в края на покрива. Тръбата се спуска вертикално; при пресичане с конструкцията е нужен друг изход или отвор.';

  @override
  String get architectOffsetOuterContour => 'Външен контур';

  @override
  String get architectOffsetInnerContour => 'Контур на отвор';

  @override
  String get architectOffsetContourHint =>
      'Офсет на всички отсечки на избрания контур. Положителните стойности го разширяват, отрицателните го свиват.';

  @override
  String get architectToolPan => 'Навигация';

  @override
  String get architectSelectionClear => 'Изчисти';

  @override
  String get architectSelectRectangleHint =>
      'Посочи два срещуположни ъгъла или издърпай рамка. Два пръста преместват изгледа.';

  @override
  String get architectSelectPolygonHint =>
      'Постави точки и затвори полигона с първата точка или с отметката.';

  @override
  String get architectCategoryEdit => 'Редакция';

  @override
  String get architectSelectReplace => 'Замени';

  @override
  String get architectSelectAdd => 'Добави';

  @override
  String get architectSelectRemove => 'Премахни';

  @override
  String get architectSelectCrossing => 'Пресича';

  @override
  String get architectSelectContained => 'Вътре';

  @override
  String get architectSelectCrossingHelp =>
      'Избира елементите вътре или пресичащи границата на селекцията.';

  @override
  String get architectSelectContainedHelp =>
      'Избира само елементите изцяло вътре в границата на селекцията.';

  @override
  String architectSelectPreviewCount(int count) {
    return 'След избора: $count';
  }

  @override
  String wallLogSize(String size) {
    return 'Диаметър $size';
  }

  @override
  String get wallChooseType => 'Избор на тип';

  @override
  String get wallSystemOptions => 'Детайли на конструкцията';

  @override
  String architectDrawSelectedType(String tool) {
    return 'Започни чертане: $tool';
  }

  @override
  String get architectToolComponent => 'Обект';

  @override
  String get architectProjectionLoading => 'Изчисляване на изгледа…';

  @override
  String get architectProjectionLoadFailed => 'Изгледът не може да се изчисли.';

  @override
  String get wallMaterialAeratedConcrete => 'Газобетон';

  @override
  String get wallAutomatic => 'Авто';

  @override
  String get wallManual => 'Ръчно';

  @override
  String get wallExteriorSideLabel => 'Външна страна';

  @override
  String get wallLocationAutoHelp =>
      'Определя предназначението по затворените контури на етажа.';

  @override
  String get wallSideAutoHelp =>
      'Насочва външната страна навън. Ръчното обръщане запазва избраната страна.';

  @override
  String get wallTypeLocationHint =>
      'Начална стойност; автоматиката я уточнява по контура.';

  @override
  String get wallExteriorUnresolved =>
      'Някои стени изискват уточняване на предназначението или страната.';

  @override
  String get wallExteriorReview => 'Уточни';
}
