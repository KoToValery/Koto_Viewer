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
  String get structuralDesigner => 'Конструктивен Модел';

  @override
  String get structural3dView => '3D Конструкция';

  @override
  String get snapEnabledTooltip => 'Прилепване (Snap): Включено';

  @override
  String get snapDisabledTooltip => 'Прилепване (Snap): Изключено';

  @override
  String get undoAction => 'Отмени последно действие';

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
  String get structuralFilterActive =>
      'Филтър подложка: Само стени и оси (Вкл.)';

  @override
  String get structuralFilterInactive =>
      'Филтър подложка: Всички слоеве (Изкл.)';

  @override
  String get structuralFilterNoWallsFound =>
      'Няма разпознати специфични слоеве за стени; показани са всички слоеве';
}
