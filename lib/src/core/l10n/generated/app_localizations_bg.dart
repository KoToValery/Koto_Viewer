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
}
