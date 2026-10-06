import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bg.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bg'),
    Locale('en'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'KoToViewer'**
  String get appTitle;

  /// Language label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Select Language dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Use system language default
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Generic Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Generic OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Generic Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Generic Search label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Generic Share label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Generic Copy button text
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Generic Copied feedback text
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Generic Clear button text
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Generic Error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Toggle dark/light theme
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get toggleTheme;

  /// About dialog button
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Support developer action
  ///
  /// In en, this message translates to:
  /// **'Support Developer'**
  String get supportDeveloper;

  /// Coordinate system settings action
  ///
  /// In en, this message translates to:
  /// **'Coordinate System Settings'**
  String get coordinateSettings;

  /// Banner title on home screen
  ///
  /// In en, this message translates to:
  /// **'Open Drawings, Models & Documents'**
  String get homeBannerTitle;

  /// Button to pick and open files
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get browseFiles;

  /// Recent files tab / section
  ///
  /// In en, this message translates to:
  /// **'Recent Files'**
  String get recentFiles;

  /// Custom folder tab
  ///
  /// In en, this message translates to:
  /// **'Custom Folder'**
  String get customFolder;

  /// Add folder button
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No files empty state text
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get noFilesFound;

  /// Search input placeholder
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get searchFilesHint;

  /// Sort menu label
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// Sort by date modified
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get sortByDate;

  /// Sort by file name
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get sortByName;

  /// Categories section title
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// All files category
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// 2D CAD files category
  ///
  /// In en, this message translates to:
  /// **'2D CAD'**
  String get categoryCad2d;

  /// 3D Models category
  ///
  /// In en, this message translates to:
  /// **'3D Models'**
  String get categoryCad3d;

  /// PCB category
  ///
  /// In en, this message translates to:
  /// **'PCB & Hardware'**
  String get categoryPcb;

  /// Routes & Maps category
  ///
  /// In en, this message translates to:
  /// **'Routes & Maps'**
  String get categoryRoutes;

  /// Subtitle below Recent Files header
  ///
  /// In en, this message translates to:
  /// **'Recently opened files'**
  String get recentlyOpenedSubtitle;

  /// Documents category
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get categoryDocuments;

  /// Medical DICOM files category
  ///
  /// In en, this message translates to:
  /// **'Medical (DICOM)'**
  String get categoryMedical;

  /// Images & Photos files category
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get categoryImages;

  /// Video & Animations files category
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get categoryVideo;

  /// Default file loading title
  ///
  /// In en, this message translates to:
  /// **'Loading file...'**
  String get loadingFile;

  /// Loading PDF title
  ///
  /// In en, this message translates to:
  /// **'Loading PDF document...'**
  String get loadingPdf;

  /// Loading PPTX presentation title
  ///
  /// In en, this message translates to:
  /// **'Loading presentation...'**
  String get loadingPresentation;

  /// Loading CAD DXF/DWG title
  ///
  /// In en, this message translates to:
  /// **'Loading CAD drawing...'**
  String get loadingCad;

  /// Converting and loading DWG title
  ///
  /// In en, this message translates to:
  /// **'Converting & loading DWG...'**
  String get convertingDwg;

  /// Loading DOC/DOCX document title
  ///
  /// In en, this message translates to:
  /// **'Loading Word document...'**
  String get loadingWordDoc;

  /// Loading XLSX spreadsheet title
  ///
  /// In en, this message translates to:
  /// **'Loading spreadsheet...'**
  String get loadingSpreadsheet;

  /// Loading 3D model title
  ///
  /// In en, this message translates to:
  /// **'Loading 3D model...'**
  String get loading3dModel;

  /// Loading e-book title
  ///
  /// In en, this message translates to:
  /// **'Loading e-book...'**
  String get loadingEbook;

  /// Loading FB2 book title
  ///
  /// In en, this message translates to:
  /// **'Loading book (FB2)...'**
  String get loadingEbookFb2;

  /// Loading comic book title
  ///
  /// In en, this message translates to:
  /// **'Loading comic book...'**
  String get loadingComic;

  /// Loading DICOM medical study title
  ///
  /// In en, this message translates to:
  /// **'Loading DICOM study...'**
  String get loadingDicom;

  /// PDF preparing status
  ///
  /// In en, this message translates to:
  /// **'Preparing and analyzing pages...'**
  String get statusPreparingPages;

  /// DICOM scanning status
  ///
  /// In en, this message translates to:
  /// **'Scanning series, slices & metadata...'**
  String get statusScanningSeries;

  /// 3D mesh processing status
  ///
  /// In en, this message translates to:
  /// **'Triangulating and building polygon mesh...'**
  String get statusTriangulatingMesh;

  /// Spreadsheet indexing status
  ///
  /// In en, this message translates to:
  /// **'Indexing worksheets, cells, and formulas...'**
  String get statusIndexingWorksheet;

  /// Ebook decoding status
  ///
  /// In en, this message translates to:
  /// **'Decoding text, chapters, and content...'**
  String get statusDecodingEbook;

  /// CAD analyzing status
  ///
  /// In en, this message translates to:
  /// **'Analyzing CAD layers, blocks, and geometry...'**
  String get statusAnalyzingCad;

  /// Word doc parsing status
  ///
  /// In en, this message translates to:
  /// **'Parsing pages, formatting, and tables...'**
  String get statusParsingWord;

  /// Opening file status
  ///
  /// In en, this message translates to:
  /// **'Opening file...'**
  String get statusOpeningFile;

  /// Extracting archive structure status
  ///
  /// In en, this message translates to:
  /// **'Extracting archive structure...'**
  String get statusExtractingStructure;

  /// Extracting specific page status
  ///
  /// In en, this message translates to:
  /// **'Extracting page {current} of {total}...'**
  String statusExtractingPage(int current, int total);

  /// Finalizing pages status
  ///
  /// In en, this message translates to:
  /// **'Finalizing pages...'**
  String get statusFinalizingPages;

  /// Indexing pages status
  ///
  /// In en, this message translates to:
  /// **'Indexing pages...'**
  String get statusIndexingPages;

  /// Reading file status with size
  ///
  /// In en, this message translates to:
  /// **'Reading file ({sizeMb} MB)...'**
  String statusReadingFile(String sizeMb);

  /// Fit Width viewer control tooltip
  ///
  /// In en, this message translates to:
  /// **'Fit Width'**
  String get fitWidth;

  /// Fit Page viewer control tooltip
  ///
  /// In en, this message translates to:
  /// **'Fit Page'**
  String get fitPage;

  /// Fit Height viewer control tooltip
  ///
  /// In en, this message translates to:
  /// **'Fit Height'**
  String get fitHeight;

  /// Jump to page dialog/button
  ///
  /// In en, this message translates to:
  /// **'Jump to Page'**
  String get jumpToPage;

  /// Go to first page tooltip
  ///
  /// In en, this message translates to:
  /// **'First Page'**
  String get firstPage;

  /// Go to last page tooltip
  ///
  /// In en, this message translates to:
  /// **'Last Page'**
  String get lastPage;

  /// Previous page tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get previousPage;

  /// Next page tooltip
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get nextPage;

  /// Page indicator text
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageIndicator(int current, int total);

  /// Jump to page prompt text
  ///
  /// In en, this message translates to:
  /// **'Enter page number (1 - {total})'**
  String enterPageNumber(int total);

  /// Zoom in control tooltip
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// Zoom out control tooltip
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// Reset zoom control tooltip
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get resetZoom;

  /// Rotate control tooltip
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// Reflow reading mode toggle
  ///
  /// In en, this message translates to:
  /// **'Reading Mode (Reflow)'**
  String get reflowMode;

  /// Document outline / bookmarks
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outline;

  /// Page thumbnails
  ///
  /// In en, this message translates to:
  /// **'Thumbnails'**
  String get thumbnails;

  /// CAD layers sheet
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layers;

  /// Display settings sheet
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettings;

  /// Coordinate system label
  ///
  /// In en, this message translates to:
  /// **'Coordinate System'**
  String get coordinateSystem;

  /// Export DXF action
  ///
  /// In en, this message translates to:
  /// **'Export DXF'**
  String get exportDxf;

  /// CAD measure tool
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get measure;

  /// CAD annotations
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get annotations;

  /// 3D wireframe render mode
  ///
  /// In en, this message translates to:
  /// **'Wireframe'**
  String get wireframe;

  /// 3D shaded render mode
  ///
  /// In en, this message translates to:
  /// **'Shaded'**
  String get shaded;

  /// Reset 3D camera view
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get resetView;

  /// Raster preview subtitle
  ///
  /// In en, this message translates to:
  /// **'Raster Preview (Embedded)'**
  String get rasterPreview;

  /// Preview only badge / text
  ///
  /// In en, this message translates to:
  /// **'Preview-only'**
  String get previewOnly;

  /// Text encoding picker
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get encoding;

  /// Wrap lines toggle
  ///
  /// In en, this message translates to:
  /// **'Wrap Lines'**
  String get wrapLines;

  /// Font size setting
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// Line spacing setting
  ///
  /// In en, this message translates to:
  /// **'Line Spacing'**
  String get lineSpacing;

  /// Font family setting
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontFamily;

  /// Theme setting
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Table of contents sheet
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// Spreadsheet sheet tab
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get sheet;

  /// Columns label
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// Rows label
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rows;

  /// DICOM window level tool
  ///
  /// In en, this message translates to:
  /// **'Window / Level'**
  String get windowLevel;

  /// DICOM invert colors tool
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get invert;

  /// Pan and zoom tool
  ///
  /// In en, this message translates to:
  /// **'Pan / Zoom'**
  String get panZoom;

  /// Toast message indicating resumed reading page
  ///
  /// In en, this message translates to:
  /// **'Resumed at Page {page} of {total}'**
  String resumedAtPage(int page, int total);

  /// Error message when file is missing or inaccessible
  ///
  /// In en, this message translates to:
  /// **'File not found or cannot be accessed.'**
  String get fileNotFoundOrInaccessible;

  /// Error message when RAR5 archive is encountered
  ///
  /// In en, this message translates to:
  /// **'This CBR file is compressed using RAR5, which is not supported by the built-in decompressor. Please convert to .cbz (ZIP) for full compatibility.'**
  String get comicRar5NotSupported;

  /// Error message when legacy RAR archive is encountered
  ///
  /// In en, this message translates to:
  /// **'This CBR file uses RAR compression, which is not supported by the built-in decompressor. Please convert to .cbz (ZIP) format.'**
  String get comicRarNotSupported;

  /// Error message when comic archive cannot be extracted
  ///
  /// In en, this message translates to:
  /// **'Comic book archive is corrupted or unreadable.'**
  String get comicArchiveCorrupted;

  /// Autoplay mode toggle or title
  ///
  /// In en, this message translates to:
  /// **'Autoplay'**
  String get comicAutoplay;

  /// Tooltip to start autoplay
  ///
  /// In en, this message translates to:
  /// **'Start Autoplay'**
  String get comicAutoplayStart;

  /// Tooltip to pause autoplay
  ///
  /// In en, this message translates to:
  /// **'Pause Autoplay'**
  String get comicAutoplayPause;

  /// Tooltip to resume autoplay
  ///
  /// In en, this message translates to:
  /// **'Resume Autoplay'**
  String get comicAutoplayResume;

  /// Tooltip to stop autoplay
  ///
  /// In en, this message translates to:
  /// **'Stop Autoplay'**
  String get comicAutoplayStop;

  /// Title for comic autoplay settings sheet
  ///
  /// In en, this message translates to:
  /// **'Autoplay Settings'**
  String get comicAutoplaySettings;

  /// Label for page duration slider
  ///
  /// In en, this message translates to:
  /// **'Page Duration'**
  String get comicAutoplayPageDuration;

  /// Label for webtoon scroll speed slider
  ///
  /// In en, this message translates to:
  /// **'Webtoon Scroll Speed'**
  String get comicAutoplayScrollSpeed;

  /// Seconds display format
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String comicAutoplaySeconds(int seconds);

  /// Pixels per second scroll speed display
  ///
  /// In en, this message translates to:
  /// **'{speed} px/s'**
  String comicAutoplaySpeedPx(int speed);

  /// Switch label to loop comic reading
  ///
  /// In en, this message translates to:
  /// **'Loop from Beginning'**
  String get comicAutoplayLoop;

  /// Switch label to pause autoplay while zooming in
  ///
  /// In en, this message translates to:
  /// **'Pause when Zoomed'**
  String get comicAutoplayPauseOnZoom;

  /// Snackbar message when reaching end of comic in autoplay
  ///
  /// In en, this message translates to:
  /// **'Reached the end of the comic.'**
  String get comicAutoplayEndReached;

  /// Badge text when autoplay is paused due to zoom
  ///
  /// In en, this message translates to:
  /// **'Paused (Zoomed)'**
  String get comicAutoplayPausedForZoom;

  /// Error message when opening a file with unsupported format
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format: {name}'**
  String unsupportedFileFormat(String name);

  /// Title for DWG conversion dialog
  ///
  /// In en, this message translates to:
  /// **'Converting DWG...'**
  String get convertingDwgTitle;

  /// Message for DWG conversion dialog
  ///
  /// In en, this message translates to:
  /// **'Converting DWG to DXF for viewing'**
  String get convertingDwgMessage;

  /// Title for PPTX conversion dialog
  ///
  /// In en, this message translates to:
  /// **'Converting Presentation...'**
  String get convertingPresentationTitle;

  /// Message for PPTX conversion dialog
  ///
  /// In en, this message translates to:
  /// **'Converting presentation to PDF for viewing'**
  String get convertingPresentationMessage;

  /// Error message when loading spreadsheet fails
  ///
  /// In en, this message translates to:
  /// **'Error loading Excel file: {error}'**
  String errorLoadingSpreadsheet(String error);

  /// Error message when loading markdown fails
  ///
  /// In en, this message translates to:
  /// **'Error loading markdown: {error}'**
  String errorLoadingMarkdown(String error);

  /// Error message when loading docx fails
  ///
  /// In en, this message translates to:
  /// **'Error reading Word document: {error}'**
  String errorReadingWordDocument(String error);

  /// Error message when loading text file fails
  ///
  /// In en, this message translates to:
  /// **'Error reading text file: {error}'**
  String errorReadingTextFile(String error);

  /// Toast message indicating resumed reading position
  ///
  /// In en, this message translates to:
  /// **'Resumed reading position'**
  String get resumedReadingPosition;

  /// Error message when opening unsupported font format
  ///
  /// In en, this message translates to:
  /// **'WOFF/WOFF2 preview is not supported. Please convert to TTF or OTF first.'**
  String get woffNotSupported;

  /// Error message when loading 3D model fails
  ///
  /// In en, this message translates to:
  /// **'Error loading 3D model: {error}'**
  String errorLoading3dModel(String error);

  /// Error message when 3D geometry is empty or invalid
  ///
  /// In en, this message translates to:
  /// **'Failed to parse 3D mesh.'**
  String get failedToParse3dMesh;

  /// Generic Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Tooltip for BIM storeys and categories button
  ///
  /// In en, this message translates to:
  /// **'BIM Storeys & Categories'**
  String get bimStoreysAndCategories;

  /// Tooltip for 3D model properties button
  ///
  /// In en, this message translates to:
  /// **'3D Properties'**
  String get properties3d;

  /// Drag and pan interaction mode for 3D viewer
  ///
  /// In en, this message translates to:
  /// **'Drag / Pan'**
  String get dragMode;

  /// Rotate and orbit interaction mode for 3D viewer
  ///
  /// In en, this message translates to:
  /// **'Rotate / Orbit'**
  String get orbitMode;

  /// Tooltip indicating dragging will move/pan the 3D model
  ///
  /// In en, this message translates to:
  /// **'Drag to move model'**
  String get dragModelTooltip;

  /// Tooltip indicating dragging will rotate the 3D model
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate model'**
  String get rotateModelTooltip;

  /// Badge indicator when drag/pan mode is active
  ///
  /// In en, this message translates to:
  /// **'Drag Mode Active'**
  String get dragModeActive;

  /// Walkthrough and fly interaction mode for 3D viewer
  ///
  /// In en, this message translates to:
  /// **'Walk / Fly'**
  String get flyMode;

  /// Tooltip indicating walkthrough / fly mode
  ///
  /// In en, this message translates to:
  /// **'Free fly & walkthrough mode (ArchiCAD / BIMx)'**
  String get flyModeTooltip;

  /// Badge indicator when walkthrough fly mode is active
  ///
  /// In en, this message translates to:
  /// **'Walk / Fly Mode (BIMx)'**
  String get flyModeActive;

  /// Error message when opening DXF file fails
  ///
  /// In en, this message translates to:
  /// **'Error opening DXF file: {error}'**
  String errorLoadingDxf(String error);

  /// Error message when saving DXF file fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save DXF: {error}'**
  String failedToSaveDxf(String error);

  /// Success message when DXF file is saved
  ///
  /// In en, this message translates to:
  /// **'Saved DXF: {name}'**
  String savedDxf(String name);

  /// Error message when importing DXF entities fails
  ///
  /// In en, this message translates to:
  /// **'Error importing DXF: {error}'**
  String errorImportingDxf(String error);

  /// Success message when DXF entities are imported
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} entities from {name}'**
  String importedDxfSuccess(int count, String name);

  /// Button label to fit drawing to screen
  ///
  /// In en, this message translates to:
  /// **'Fit Screen'**
  String get fitScreen;

  /// Error message when print preview fails
  ///
  /// In en, this message translates to:
  /// **'Print preview unavailable: {error}'**
  String printPreviewUnavailable(String error);

  /// Error message when reading HPGL file fails
  ///
  /// In en, this message translates to:
  /// **'Error reading HPGL plotter file: {error}'**
  String errorReadingHpgl(String error);

  /// Error message when reading PCB project fails
  ///
  /// In en, this message translates to:
  /// **'Error reading PCB project: {error}'**
  String errorReadingPcb(String error);

  /// Error message when reading CorelDRAW file fails
  ///
  /// In en, this message translates to:
  /// **'Error reading CorelDRAW file: {error}'**
  String errorReadingCdr(String error);

  /// Error message when PNG export fails
  ///
  /// In en, this message translates to:
  /// **'Could not export PNG: {error}'**
  String couldNotExportPng(String error);

  /// Error message when printing fails
  ///
  /// In en, this message translates to:
  /// **'Print error: {error}'**
  String printError(String error);

  /// Error message when reading EPS file fails
  ///
  /// In en, this message translates to:
  /// **'Error reading EPS file: {error}'**
  String errorReadingEps(String error);

  /// Error message when loading SVG file fails
  ///
  /// In en, this message translates to:
  /// **'Error loading SVG: {error}'**
  String errorLoadingSvg(String error);

  /// Error message when loading GPS route file fails
  ///
  /// In en, this message translates to:
  /// **'Could not load route file: {error}'**
  String errorLoadingRoute(String error);

  /// Snackbar notification when map is centered on a waypoint
  ///
  /// In en, this message translates to:
  /// **'Centered on: {name}'**
  String centeredOnWaypoint(String name);

  /// Error message when parsing DICOM fails
  ///
  /// In en, this message translates to:
  /// **'DICOM Parse Error: {error}'**
  String dicomParseError(String error);

  /// Error message when loading DICOM study fails
  ///
  /// In en, this message translates to:
  /// **'Error loading DICOM study: {error}'**
  String errorLoadingDicom(String error);

  /// Tooltip/label for toggling DICOM scout / localizer cross-reference lines
  ///
  /// In en, this message translates to:
  /// **'Cross-Reference Lines'**
  String get dicomReferenceLines;

  /// Label for selecting multi-viewport grid layout in DICOM viewer
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get dicomLayout;

  /// Error message when loading e-book fails
  ///
  /// In en, this message translates to:
  /// **'Error loading e-book: {error}'**
  String errorLoadingEbook(String error);

  /// Error message when PSD composite decoding fails
  ///
  /// In en, this message translates to:
  /// **'Could not decode PSD composite image.'**
  String get couldNotDecodePsd;

  /// Error message when custom folder picking fails
  ///
  /// In en, this message translates to:
  /// **'Error picking folder: {error}'**
  String errorPickingFolder(String error);

  /// Notification message when user selects an unsupported file
  ///
  /// In en, this message translates to:
  /// **'Please select a supported CAD, PCB, 3D, Vector, or Document file.'**
  String get pleaseSelectSupportedFile;

  /// Error message when opening system file picker fails
  ///
  /// In en, this message translates to:
  /// **'Could not open file picker: {error}'**
  String couldNotOpenFilePicker(String error);

  /// Error message when native sharing fails
  ///
  /// In en, this message translates to:
  /// **'Error sharing file: {error}'**
  String errorSharingFile(String error);

  /// Tooltip for toggling to continuous mode from single page mode
  ///
  /// In en, this message translates to:
  /// **'Single Page Mode (Tap for Continuous)'**
  String get singlePageModeTooltip;

  /// Tooltip for toggling to single page mode from continuous mode
  ///
  /// In en, this message translates to:
  /// **'Continuous Mode (Tap for Single Page)'**
  String get continuousModeTooltip;

  /// Label for single page mode
  ///
  /// In en, this message translates to:
  /// **'Single Page'**
  String get singlePageLabel;

  /// Label for continuous scroll mode
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get continuousLabel;

  /// Label for view mode row
  ///
  /// In en, this message translates to:
  /// **'View Mode:'**
  String get viewMode;

  /// Label for single page swipe mode
  ///
  /// In en, this message translates to:
  /// **'Single Page (Swipe)'**
  String get singlePageSwipe;

  /// Label for continuous scroll mode
  ///
  /// In en, this message translates to:
  /// **'Continuous Scroll'**
  String get continuousScroll;

  /// Header for archive files list
  ///
  /// In en, this message translates to:
  /// **'Archive Files ({count})'**
  String archiveFilesCount(int count);

  /// Button or label to open a file from archive
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openArchiveFile;

  /// Notice when a file inside archive cannot be opened directly
  ///
  /// In en, this message translates to:
  /// **'Direct preview is not supported for this file format.'**
  String get unsupportedArchiveFormat;

  /// Message while extracting and opening a file from archive
  ///
  /// In en, this message translates to:
  /// **'Opening {name}...'**
  String extractingFile(String name);

  /// Title for video viewer screen
  ///
  /// In en, this message translates to:
  /// **'Video Player'**
  String get videoViewerTitle;

  /// Notification when video loop is enabled
  ///
  /// In en, this message translates to:
  /// **'Loop enabled'**
  String get videoLoopOn;

  /// Notification when video loop is disabled
  ///
  /// In en, this message translates to:
  /// **'Loop disabled'**
  String get videoLoopOff;

  /// Button to start sequential project presentation
  ///
  /// In en, this message translates to:
  /// **'Start Presentation'**
  String get presentationMode;

  /// Button to go to next item in project
  ///
  /// In en, this message translates to:
  /// **'Next File'**
  String get nextProjectItem;

  /// Button to go to previous item in project
  ///
  /// In en, this message translates to:
  /// **'Previous File'**
  String get prevProjectItem;

  /// Overview label for project assets
  ///
  /// In en, this message translates to:
  /// **'Project Assets'**
  String get projectOverview;

  /// Button to upload files via Wi-Fi
  ///
  /// In en, this message translates to:
  /// **'Upload via Wi-Fi'**
  String get uploadViaWifi;

  /// Title for receive files via Wi-Fi dialog
  ///
  /// In en, this message translates to:
  /// **'Receive Files'**
  String get receiveFiles;

  /// Subtitle explaining how to upload files from browser
  ///
  /// In en, this message translates to:
  /// **'Upload files from browser over local network'**
  String get receiveFilesSubtitle;

  /// Header for list of received files
  ///
  /// In en, this message translates to:
  /// **'Received Files'**
  String get receivedFiles;

  /// Button label to open a received file
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// Tooltip/button to hide or skip a file from the presentation
  ///
  /// In en, this message translates to:
  /// **'Hide from presentation'**
  String get hideFromPresentation;

  /// Tooltip/button to include a previously hidden file in the presentation
  ///
  /// In en, this message translates to:
  /// **'Include in presentation'**
  String get includeInPresentation;

  /// Badge/label indicating a file is skipped from presentation
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hiddenInPresentation;

  /// Snackbar notification when a file is hidden
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" hidden from presentation'**
  String fileHiddenNotification(String name);

  /// Snackbar notification when a file is included
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" included in presentation'**
  String fileIncludedNotification(String name);

  /// Action to include all hidden files in the presentation
  ///
  /// In en, this message translates to:
  /// **'Include all files'**
  String get unhideAllFiles;

  /// Notification when all files are included
  ///
  /// In en, this message translates to:
  /// **'All files are now included in the presentation'**
  String get allFilesIncludedNotification;

  /// Filter tab/chip label showing number of hidden files
  ///
  /// In en, this message translates to:
  /// **'Hidden ({count})'**
  String hiddenFilesFilter(int count);

  /// Warning when trying to start presentation with all files hidden
  ///
  /// In en, this message translates to:
  /// **'All files are hidden from the presentation. Please include at least one file.'**
  String get allFilesHiddenWarning;

  /// Subtitle tag shown in presentation bar when current file is hidden
  ///
  /// In en, this message translates to:
  /// **'Skipped in presentation'**
  String get fileSkippedInPresentation;

  /// Button or menu item to check for application updates
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// Status message while checking for updates
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// Dialog or snackbar title when a new version is found
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// Message informing user that an update is available
  ///
  /// In en, this message translates to:
  /// **'A new version of KoToViewer is available on Google Play.'**
  String get updateAvailableMessage;

  /// Button to start update process
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Snackbar notifying user that flexible update is ready to install
  ///
  /// In en, this message translates to:
  /// **'A new version has been downloaded. Restart the app to apply it.'**
  String get updateDownloadedSnackbar;

  /// Button label to restart and apply the downloaded update
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartToUpdate;

  /// Notification that no updates are available
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version of KoToViewer.'**
  String get appUpToDate;

  /// Notification when update check fails
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates via Google Play.'**
  String get updateCheckFailed;

  /// Button to open application page in Google Play Store
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get openPlayStore;

  /// Developer informational note in debug mode
  ///
  /// In en, this message translates to:
  /// **'In debug / local build, Google Play In-App Updates require installation via Play Store (Internal Testing track or Internal App Sharing).'**
  String get debugTestingNote;

  /// Debug button to test update UI and restart flow
  ///
  /// In en, this message translates to:
  /// **'Simulate Update (Debug)'**
  String get simulateUpdate;

  /// Label for the local app storage folder where files received via Wi-Fi are stored
  ///
  /// In en, this message translates to:
  /// **'Uploaded Files'**
  String get localAppFolder;

  /// Subtitle for local app storage folder
  ///
  /// In en, this message translates to:
  /// **'App local storage'**
  String get localAppFolderSubtitle;

  /// Title of delete file dialog
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFileTitle;

  /// Confirmation message when deleting a file from app storage
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete \"{name}\" from app storage?'**
  String deleteFileConfirm(String name);

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Notification that file was deleted
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// Tooltip for removing file from recent list
  ///
  /// In en, this message translates to:
  /// **'Remove from recent'**
  String get removeFromRecent;

  /// Title/action for filling PDF AcroForms
  ///
  /// In en, this message translates to:
  /// **'Fill PDF Form'**
  String get pdfFormFilling;

  /// Number of form fields in the document
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String pdfFormFieldsCount(int count);

  /// Notice when PDF has no AcroForm fields
  ///
  /// In en, this message translates to:
  /// **'This document contains no interactive form fields.'**
  String get pdfNoFormFields;

  /// Success message when form is saved
  ///
  /// In en, this message translates to:
  /// **'Form saved successfully!'**
  String get pdfFormSaved;

  /// Option to convert form fields to static text
  ///
  /// In en, this message translates to:
  /// **'Flatten form after saving (Lock fields)'**
  String get pdfFormFlatten;

  /// Tooltip explaining flattening
  ///
  /// In en, this message translates to:
  /// **'Values will become static text and fields cannot be edited further.'**
  String get pdfFormFlattenTooltip;

  /// Save copy of filled form
  ///
  /// In en, this message translates to:
  /// **'Save as new file...'**
  String get pdfFormSaveAsCopy;

  /// Overwrite existing file with filled form
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get pdfFormSaveOverwrite;

  /// Title for certificate and digital signature viewer
  ///
  /// In en, this message translates to:
  /// **'Digital Certificates & Signatures'**
  String get pdfDigitalCertificates;

  /// Notice when no certificates/signatures found
  ///
  /// In en, this message translates to:
  /// **'This document does not contain a digital certificate or embedded electronic signature.'**
  String get pdfNoDigitalCertificates;

  /// Label for certificate signer
  ///
  /// In en, this message translates to:
  /// **'Signed by:'**
  String get pdfSignedBy;

  /// Label for certificate authority
  ///
  /// In en, this message translates to:
  /// **'Issuer (CA):'**
  String get pdfIssuer;

  /// Label for signature timestamp
  ///
  /// In en, this message translates to:
  /// **'Signing Date:'**
  String get pdfSignDate;

  /// Label for certificate start date
  ///
  /// In en, this message translates to:
  /// **'Valid from:'**
  String get pdfValidFrom;

  /// Label for certificate expiration date
  ///
  /// In en, this message translates to:
  /// **'Valid to:'**
  String get pdfValidTo;

  /// Status badge for valid certificate
  ///
  /// In en, this message translates to:
  /// **'Valid Certificate'**
  String get pdfSignatureValid;

  /// Status badge for expired certificate
  ///
  /// In en, this message translates to:
  /// **'Expired Certificate'**
  String get pdfSignatureExpired;

  /// Button to inspect external .cer or .pfx certificate
  ///
  /// In en, this message translates to:
  /// **'Check external certificate file'**
  String get pdfCheckExternalCert;

  /// Tooltip for entering fullscreen mode
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// Tooltip for exiting fullscreen mode
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get exitFullscreen;

  /// Tooltip to lock screen rotation
  ///
  /// In en, this message translates to:
  /// **'Lock Rotation'**
  String get lockRotation;

  /// Tooltip to unlock screen rotation
  ///
  /// In en, this message translates to:
  /// **'Unlock Rotation'**
  String get unlockRotation;

  /// Snackbar message when rotation is locked
  ///
  /// In en, this message translates to:
  /// **'Screen rotation locked'**
  String get rotationLocked;

  /// Snackbar message when rotation is unlocked
  ///
  /// In en, this message translates to:
  /// **'Auto-rotation restored'**
  String get rotationUnlocked;

  /// Error message when DWG conversion exceeds device memory limits
  ///
  /// In en, this message translates to:
  /// **'This DWG drawing requires more memory than available on this device. Please convert it to DXF on a PC or clean it with the PURGE command in CAD software.'**
  String get dwgMemoryLimitError;

  /// Error message when DWG file conversion fails
  ///
  /// In en, this message translates to:
  /// **'Could not convert DWG file: {error}'**
  String dwgConversionFailed(String error);

  /// Tooltip / button for opening Structural Designer (BIM) module
  ///
  /// In en, this message translates to:
  /// **'Structural Model (BIM)'**
  String get structuralDesignerBim;

  /// Option to show structural BIM elements over architectural drawing
  ///
  /// In en, this message translates to:
  /// **'Show Structural BIM Elements'**
  String get showBimOverlay;

  /// Option to hide structural BIM elements over architectural drawing
  ///
  /// In en, this message translates to:
  /// **'Hide Structural BIM Elements'**
  String get hideBimOverlay;

  /// Title of Structural Designer screen
  ///
  /// In en, this message translates to:
  /// **'Structural Model'**
  String get structuralDesigner;

  /// Tooltip for opening 3D structural model view
  ///
  /// In en, this message translates to:
  /// **'3D Structure'**
  String get structural3dView;

  /// Tooltip when snap is active
  ///
  /// In en, this message translates to:
  /// **'Snap: Enabled'**
  String get snapEnabledTooltip;

  /// Tooltip when snap is inactive
  ///
  /// In en, this message translates to:
  /// **'Snap: Disabled'**
  String get snapDisabledTooltip;

  /// General undo action label for snackbars
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// Trace reference storey indicator pill
  ///
  /// In en, this message translates to:
  /// **'Trace Reference: {storey}'**
  String traceReferenceLayer(String storey);

  /// Navigation tool mode label
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get toolNavigation;

  /// Column tool mode label
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get toolColumn;

  /// Shear Wall tool mode label
  ///
  /// In en, this message translates to:
  /// **'Shear Wall'**
  String get toolShearWall;

  /// Slab tool mode label
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get toolSlab;

  /// Slab opening cutout drawing tool
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get toolOpening;

  /// Cantilever analysis button label
  ///
  /// In en, this message translates to:
  /// **'Cantilevers'**
  String get toolCantilevers;

  /// Preset circular column label
  ///
  /// In en, this message translates to:
  /// **'Ø{diameter} circular'**
  String circularColumnPreset(int diameter);

  /// Tooltip to rotate column 90 degrees
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get rotate90;

  /// Label for wall thickness selector
  ///
  /// In en, this message translates to:
  /// **'Wall thickness: '**
  String get wallThicknessLabel;

  /// Tooltip to undo last drawn point
  ///
  /// In en, this message translates to:
  /// **'Undo point'**
  String get undoPoint;

  /// Button to close slab polygon with vertex count
  ///
  /// In en, this message translates to:
  /// **'Close ({count})'**
  String closeSlab(int count);

  /// Title of storey manager sheet
  ///
  /// In en, this message translates to:
  /// **'Storey Manager (Levels & Layers)'**
  String get storeyManagerTitle;

  /// Header for Trace Reference settings
  ///
  /// In en, this message translates to:
  /// **'Trace Reference (Ghost Underlay)'**
  String get traceReferenceTitle;

  /// Option to disable Trace Reference
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get traceRefNone;

  /// Trace reference from floor below
  ///
  /// In en, this message translates to:
  /// **'Storey Below'**
  String get traceRefBelow;

  /// Trace reference from floor above
  ///
  /// In en, this message translates to:
  /// **'Storey Above'**
  String get traceRefAbove;

  /// Storey subtitle showing elevation and element counts
  ///
  /// In en, this message translates to:
  /// **'Z: +{elevation} m • H: {height} m • {columns} cols, {walls} walls'**
  String storeyElevationSub(
    String elevation,
    String height,
    int columns,
    int walls,
  );

  /// Tooltip to edit storey clear height
  ///
  /// In en, this message translates to:
  /// **'Change height H'**
  String get changeHeightH;

  /// Tooltip to delete storey
  ///
  /// In en, this message translates to:
  /// **'Delete storey'**
  String get deleteStorey;

  /// Button to add a new storey level
  ///
  /// In en, this message translates to:
  /// **'New Storey'**
  String get newStorey;

  /// Button to duplicate storey elements to new level
  ///
  /// In en, this message translates to:
  /// **'Duplicate Typical'**
  String get duplicateTypical;

  /// Dialog title for changing storey height
  ///
  /// In en, this message translates to:
  /// **'Storey clear height (m)'**
  String get storeyClearHeight;

  /// Title of cantilever analysis sheet
  ///
  /// In en, this message translates to:
  /// **'Cantilever Analysis (Overhangs & Deflection)'**
  String get cantileverAnalysisTitle;

  /// Stat card title for total cantilevers
  ///
  /// In en, this message translates to:
  /// **'Total cantilevers'**
  String get totalCantilevers;

  /// Stat card title for corner cantilevers
  ///
  /// In en, this message translates to:
  /// **'Corner 2-way'**
  String get cornerCantilevers;

  /// Stat card title for critical risk zones
  ///
  /// In en, this message translates to:
  /// **'Critical zones'**
  String get criticalZones;

  /// Stat card title for max deflection
  ///
  /// In en, this message translates to:
  /// **'Max. deflection'**
  String get maxDeflection;

  /// Eurocode SLS info banner
  ///
  /// In en, this message translates to:
  /// **'EN 1992-1-1 (EC2): Deflection limit flim = Lcant / 250. Concrete creep φ = 2.5 and facade load included.'**
  String get eurocodeStandardInfo;

  /// Empty state when building has no cantilevers
  ///
  /// In en, this message translates to:
  /// **'No cantilever overhangs detected.\nAll slabs are fully supported by columns/walls.'**
  String get noCantileversFound;

  /// Length label for linear cantilever
  ///
  /// In en, this message translates to:
  /// **'Length L'**
  String get propLengthL;

  /// Slab thickness label
  ///
  /// In en, this message translates to:
  /// **'Slab h'**
  String get propSlabH;

  /// Calculated long term deflection label
  ///
  /// In en, this message translates to:
  /// **'Deflection ftot: {value} mm'**
  String deflectionFtot(String value);

  /// Code limit deflection label
  ///
  /// In en, this message translates to:
  /// **'Limit flim: {value} mm'**
  String deflectionLimitFlim(String value);

  /// AppBar title for 3D structural model viewport
  ///
  /// In en, this message translates to:
  /// **'3D Structural Model'**
  String get structural3dTitle;

  /// Tooltip for shading mode popup
  ///
  /// In en, this message translates to:
  /// **'Shading Mode'**
  String get shadingModeTitle;

  /// Tooltip to reset 3D camera
  ///
  /// In en, this message translates to:
  /// **'Center View'**
  String get centerView;

  /// Chip to show all building storeys in 3D
  ///
  /// In en, this message translates to:
  /// **'All Storeys'**
  String get allStoreys;

  /// Wireframe shading mode
  ///
  /// In en, this message translates to:
  /// **'Wireframe'**
  String get shadingWireframe;

  /// Solid white shading mode
  ///
  /// In en, this message translates to:
  /// **'Solid White'**
  String get shadingSolid;

  /// CAD shaded edges mode
  ///
  /// In en, this message translates to:
  /// **'Shaded with Edges'**
  String get shadingShadedEdges;

  /// Surface normals shading mode
  ///
  /// In en, this message translates to:
  /// **'Surface Normals'**
  String get shadingNormals;

  /// Snap type endpoint
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get snapEndpoint;

  /// Snap type midpoint
  ///
  /// In en, this message translates to:
  /// **'Midpoint'**
  String get snapMidpoint;

  /// Snap type center
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get snapCenter;

  /// Snap type nearest
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get snapNearest;

  /// Snap type perpendicular
  ///
  /// In en, this message translates to:
  /// **'Perpendicular'**
  String get snapPerpendicular;

  /// Snap type point
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get snapPoint;

  /// Pointer badge for rectangular column
  ///
  /// In en, this message translates to:
  /// **'Column {width} x {height} cm'**
  String previewColumnTag(int width, int height);

  /// Pointer badge for circular column
  ///
  /// In en, this message translates to:
  /// **'Column Ø{diameter} cm'**
  String previewCircularColumnTag(int diameter);

  /// Pointer badge for wall start
  ///
  /// In en, this message translates to:
  /// **'Shear Wall: start point'**
  String get previewWallStartTag;

  /// Pointer badge for wall end
  ///
  /// In en, this message translates to:
  /// **'Shear Wall: end point'**
  String get previewWallEndTag;

  /// Pointer badge for slab vertex
  ///
  /// In en, this message translates to:
  /// **'Slab: vertex {index}'**
  String previewSlabVertexTag(int index);

  /// Cantilever type linear
  ///
  /// In en, this message translates to:
  /// **'Linear cantilever (1-way)'**
  String get cantileverTypeLinear;

  /// Cantilever type corner
  ///
  /// In en, this message translates to:
  /// **'Double corner cantilever (2-way)'**
  String get cantileverTypeCorner;

  /// Cantilever type transfer
  ///
  /// In en, this message translates to:
  /// **'Transfer cantilever (column on overhang)'**
  String get cantileverTypeTransfer;

  /// Cantilever risk level safe
  ///
  /// In en, this message translates to:
  /// **'Safe (Compliant)'**
  String get riskLevelSafe;

  /// Cantilever risk level warning
  ///
  /// In en, this message translates to:
  /// **'Warning (High deflection)'**
  String get riskLevelWarning;

  /// Cantilever risk level critical
  ///
  /// In en, this message translates to:
  /// **'Critical (Excessive deflection)'**
  String get riskLevelCritical;

  /// Default storey name pattern
  ///
  /// In en, this message translates to:
  /// **'Storey {number} (Elev. +{elevation})'**
  String storeyLevelName(int number, String elevation);

  /// Duplicated typical storey name pattern
  ///
  /// In en, this message translates to:
  /// **'Storey {number} (Typical from {source})'**
  String storeyTypicalName(int number, String source);

  /// Hardware GPU Acceleration label
  ///
  /// In en, this message translates to:
  /// **'Hardware GPU Acceleration'**
  String get hardwareAcceleration;

  /// Hardware GPU Acceleration active state
  ///
  /// In en, this message translates to:
  /// **'Hardware GPU Acceleration (Active)'**
  String get gpuAccelerationActive;

  /// Hardware GPU Acceleration inactive state
  ///
  /// In en, this message translates to:
  /// **'Hardware GPU Acceleration (Off)'**
  String get gpuAccelerationInactive;

  /// Tooltip when structural underlay filter is active
  ///
  /// In en, this message translates to:
  /// **'Underlay Filter (On)'**
  String get structuralFilterActive;

  /// Tooltip when structural underlay filter is off
  ///
  /// In en, this message translates to:
  /// **'Underlay Filter (Off)'**
  String get structuralFilterInactive;

  /// Snackbar notice when drawing has no isolated wall layers
  ///
  /// In en, this message translates to:
  /// **'No specific wall or axis layers identified; showing full drawing'**
  String get structuralFilterNoWallsFound;

  /// Badge label for floating columns
  ///
  /// In en, this message translates to:
  /// **'FLOATING'**
  String get floatingColumnBadge;

  /// Magnetic offset label when snapped flush to edge
  ///
  /// In en, this message translates to:
  /// **'{offset} m (Flush)'**
  String alignedOffsetFlush(String offset);

  /// Title for Layers tab in structural bottom palette
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layersTabTitle;

  /// Instruction hint when Layers tab is active in structural designer
  ///
  /// In en, this message translates to:
  /// **'Hold any drawing element to hide or isolate its layer'**
  String get layersTabHint;

  /// Title for Underlay Filter configuration sheet
  ///
  /// In en, this message translates to:
  /// **'Underlay Filter'**
  String get underlayFilterTitle;

  /// Subtitle for Underlay Filter configuration sheet
  ///
  /// In en, this message translates to:
  /// **'Customize which CAD layers are visible in underlay filter mode'**
  String get underlayFilterSubtitle;

  /// Button to reset underlay filter to automatically detected walls and axes
  ///
  /// In en, this message translates to:
  /// **'Auto (Walls & Axes)'**
  String get underlayFilterAutoReset;

  /// Button to select all layers in underlay filter
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get underlayFilterSelectAll;

  /// Button to clear all layers in underlay filter
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get underlayFilterClearAll;

  /// Action button to synchronize column designations across building levels
  ///
  /// In en, this message translates to:
  /// **'Sync Column Numbers Across Storeys'**
  String get syncColumnsAcrossStoreys;

  /// Notice when column numbering synchronization completes
  ///
  /// In en, this message translates to:
  /// **'{count} columns synchronized across storeys'**
  String syncColumnsSuccess(int count);

  /// Notice when a CAD layer is hidden via long-press
  ///
  /// In en, this message translates to:
  /// **'Layer \"{layer}\" is now hidden'**
  String layerHiddenNotice(String layer);

  /// Progress message while underlay filter is calculating and rendering
  ///
  /// In en, this message translates to:
  /// **'Applying underlay filter...'**
  String get filteringUnderlay;

  /// Search input placeholder for layer filtering
  ///
  /// In en, this message translates to:
  /// **'Search layers...'**
  String get searchLayers;

  /// Button to open underlay filter configuration
  ///
  /// In en, this message translates to:
  /// **'Configure Filter'**
  String get manageUnderlayFilter;

  /// Pointer badge for rectangular slab 1st corner
  ///
  /// In en, this message translates to:
  /// **'Slab: pick 1st corner'**
  String get previewSlabCorner1Tag;

  /// Pointer badge for rectangular slab opposite corner
  ///
  /// In en, this message translates to:
  /// **'Slab: pick opposite corner'**
  String get previewSlabCorner2Tag;

  /// Live dimension badge for parallel cantilever extrusion
  ///
  /// In en, this message translates to:
  /// **'Cantilever: {depth} m'**
  String cantileverExtrudeDepth(String depth);

  /// Tooltip for edge midpoint grip
  ///
  /// In en, this message translates to:
  /// **'Drag midpoint to extrude cantilever'**
  String get slabEdgeExtrudeTooltip;

  /// Magnetic parallel alignment indicator during slab edge dragging
  ///
  /// In en, this message translates to:
  /// **'Aligned to line: {distance} m'**
  String slabParallelAligned(String distance);

  /// Guidance hint for point-by-point slab placement tool
  ///
  /// In en, this message translates to:
  /// **'Tap or hold with snap to place slab points'**
  String get slabPointByPointPrompt;

  /// Cancel rectangular slab drawing
  ///
  /// In en, this message translates to:
  /// **'Cancel slab'**
  String get cancelSlab;

  /// Dimensions badge for rectangular slab
  ///
  /// In en, this message translates to:
  /// **'Slab: {width} x {height} m'**
  String slabRectDimensions(String width, String height);

  /// Move structural element button
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveElement;

  /// Rotate structural element 90 degrees button
  ///
  /// In en, this message translates to:
  /// **'Rotate 90°'**
  String get rotateElement;

  /// Mirror structural element button
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get mirrorElement;

  /// Snackbar message when a column is deleted
  ///
  /// In en, this message translates to:
  /// **'Column deleted'**
  String get columnDeleted;

  /// Title badge on selected column action card
  ///
  /// In en, this message translates to:
  /// **'Selected Column {dimensions}'**
  String selectedColumnTitle(String dimensions);

  /// Tooltip hint to drag element to relocate
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to move'**
  String get dragToMoveTooltip;

  /// Title for slab correction mode bottom bar
  ///
  /// In en, this message translates to:
  /// **'Slab Correction'**
  String get slabCorrectionTitle;

  /// Offset label in slab correction bar
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get slabOffsetLabel;

  /// Rotation label in slab correction bar
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get slabRotateLabel;

  /// Snackbar message when two vertices are merged
  ///
  /// In en, this message translates to:
  /// **'Points merged'**
  String get slabPointsMerged;

  /// Snackbar message when a vertex is deleted
  ///
  /// In en, this message translates to:
  /// **'Point {number} deleted'**
  String slabPointDeleted(int number);

  /// Snackbar message when a new vertex is inserted at midpoint
  ///
  /// In en, this message translates to:
  /// **'New vertex inserted at midpoint'**
  String get slabVertexInserted;

  /// Warning when trying to delete vertex with fewer than 4 points
  ///
  /// In en, this message translates to:
  /// **'Slab must have at least 3 points'**
  String get slabMinPointsWarning;

  /// Button to delete the slab
  ///
  /// In en, this message translates to:
  /// **'Delete slab'**
  String get deleteSlab;

  /// Snackbar message when slab is deleted
  ///
  /// In en, this message translates to:
  /// **'Slab deleted'**
  String get slabDeleted;

  /// Action button to edit slab
  ///
  /// In en, this message translates to:
  /// **'Edit Slab'**
  String get editSlabAction;

  /// Title badge for selected slab
  ///
  /// In en, this message translates to:
  /// **'Selected Slab'**
  String get selectedSlabTitle;

  /// Duplicate selected structural element
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateElement;

  /// Flip side of shear wall leading line
  ///
  /// In en, this message translates to:
  /// **'Flip Side'**
  String get flipSide;

  /// Title badge for selected shear wall
  ///
  /// In en, this message translates to:
  /// **'Selected Shear Wall {dimensions}'**
  String selectedWallTitle(String dimensions);

  /// L-shaped column preset label
  ///
  /// In en, this message translates to:
  /// **'L-Shape 50x50/25'**
  String get columnShapeLShape;

  /// Structural beam drawing tool
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get toolBeam;

  /// Title badge for selected beam
  ///
  /// In en, this message translates to:
  /// **'Selected Beam {dimensions}'**
  String selectedBeamTitle(String dimensions);

  /// Title badge for selected slab opening
  ///
  /// In en, this message translates to:
  /// **'Selected Opening {dimensions}'**
  String selectedOpeningTitle(String dimensions);

  /// Button to delete a vertex in slab editor
  ///
  /// In en, this message translates to:
  /// **'Delete Vertex'**
  String get deleteVertex;

  /// 25x50 cm beam preset
  ///
  /// In en, this message translates to:
  /// **'25x50'**
  String get beamPreset25x50;

  /// 25x60 cm beam preset
  ///
  /// In en, this message translates to:
  /// **'25x60'**
  String get beamPreset25x60;

  /// 25x40 cm beam preset
  ///
  /// In en, this message translates to:
  /// **'25x40'**
  String get beamPreset25x40;

  /// Riser shaft opening preset
  ///
  /// In en, this message translates to:
  /// **'Shaft 0.40x0.60'**
  String get openingPresetShaft;

  /// Staircase opening preset
  ///
  /// In en, this message translates to:
  /// **'Stairwell 2.40x4.50'**
  String get openingPresetStairs;

  /// Elevator shaft opening preset
  ///
  /// In en, this message translates to:
  /// **'Elevator 1.80x2.00'**
  String get openingPresetElevator;

  /// Freeform/custom rectangular opening
  ///
  /// In en, this message translates to:
  /// **'Custom Opening'**
  String get openingPresetCustom;

  /// Button to delete opening
  ///
  /// In en, this message translates to:
  /// **'Delete Opening'**
  String get deleteOpening;

  /// Structural grid axis line drawing tool
  ///
  /// In en, this message translates to:
  /// **'Grid Axis'**
  String get toolGridAxis;

  /// Title badge for selected grid axis
  ///
  /// In en, this message translates to:
  /// **'Grid Axis {name}'**
  String selectedGridAxisTitle(String name);

  /// Button to delete grid axis
  ///
  /// In en, this message translates to:
  /// **'Delete Axis'**
  String get deleteGridAxis;

  /// Button to rename grid axis
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameGridAxis;

  /// Prompt to select first side of wall
  ///
  /// In en, this message translates to:
  /// **'Select first wall side'**
  String get firstWallSidePrompt;

  /// Prompt to select opposite side of wall
  ///
  /// In en, this message translates to:
  /// **'Select opposite wall side'**
  String get secondWallSidePrompt;

  /// Intersection snap label
  ///
  /// In en, this message translates to:
  /// **'Intersection'**
  String get snapIntersection;

  /// Title for Eurocode 2 vertical capacity analysis
  ///
  /// In en, this message translates to:
  /// **'Vertical Capacity (EC2)'**
  String get verticalCapacityTitle;

  /// Subtitle for vertical capacity sheet
  ///
  /// In en, this message translates to:
  /// **'Column crushing, punching shear and slab deflection'**
  String get verticalCapacitySubtitle;

  /// Title for column crushing check
  ///
  /// In en, this message translates to:
  /// **'Column Crushing'**
  String get columnCrushingTitle;

  /// Title for punching shear check
  ///
  /// In en, this message translates to:
  /// **'Punching Shear'**
  String get punchingShearTitle;

  /// Title for slab deflection check
  ///
  /// In en, this message translates to:
  /// **'Recommended Slab Thickness'**
  String get slabDeflectionTitle;

  /// Title for foundation load check
  ///
  /// In en, this message translates to:
  /// **'Foundation Load'**
  String get foundationPressureTitle;

  /// Label for total base load
  ///
  /// In en, this message translates to:
  /// **'Total Vertical Load'**
  String get totalBaseLoad;

  /// Label for critical columns count
  ///
  /// In en, this message translates to:
  /// **'Critical Columns'**
  String get criticalColumns;

  /// Label for punching shear risks count
  ///
  /// In en, this message translates to:
  /// **'Punching Risks'**
  String get punchingRisks;

  /// Label for max clear span
  ///
  /// In en, this message translates to:
  /// **'Max Span'**
  String get maxSpanLabel;

  /// Label for recommended slab thickness
  ///
  /// In en, this message translates to:
  /// **'Recommended Thickness'**
  String get recommendedThicknessLabel;

  /// Label for axial compression utilization
  ///
  /// In en, this message translates to:
  /// **'Axial Compression (EC2)'**
  String get axialUtilizationLabel;

  /// Label for punching shear stress
  ///
  /// In en, this message translates to:
  /// **'Punching Shear Stress'**
  String get punchingStressLabel;

  /// Status safe label
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get statusSafe;

  /// Status warning label
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get statusWarning;

  /// Status critical label
  ///
  /// In en, this message translates to:
  /// **'Critical Overload'**
  String get statusCritical;

  /// Button label for EC2 vertical capacity
  ///
  /// In en, this message translates to:
  /// **'EC2 Capacity'**
  String get ec2FeasibilityButton;

  /// Label for required column section
  ///
  /// In en, this message translates to:
  /// **'Requires min {section}'**
  String columnRequiredSection(String section);

  /// Storey column load summary
  ///
  /// In en, this message translates to:
  /// **'{storey}: Ned = {ned} kN / Nrd = {nrd} kN ({ratio}%)'**
  String storeyColumnLoad(String storey, String ned, String nrd, String ratio);

  /// Title for EC8 seismic analysis
  ///
  /// In en, this message translates to:
  /// **'Seismic Analysis (EC8)'**
  String get seismicAnalysisTitle;

  /// Subtitle for EC8 seismic analysis
  ///
  /// In en, this message translates to:
  /// **'Eccentricity, shear walls, transfer columns & beams'**
  String get seismicAnalysisSubtitle;

  /// Label for center of mass
  ///
  /// In en, this message translates to:
  /// **'Center of Mass (CM)'**
  String get centerOfMass;

  /// Label for center of rigidity
  ///
  /// In en, this message translates to:
  /// **'Center of Rigidity (CR)'**
  String get centerOfRigidity;

  /// Label for seismic eccentricity
  ///
  /// In en, this message translates to:
  /// **'Seismic Eccentricity'**
  String get seismicEccentricity;

  /// Label for torsional sensitivity
  ///
  /// In en, this message translates to:
  /// **'Torsional Sensitivity'**
  String get torsionalSensitivity;

  /// Label for shear wall ratio
  ///
  /// In en, this message translates to:
  /// **'Shear Wall Ratio'**
  String get shearWallRatio;

  /// Title for floating columns check
  ///
  /// In en, this message translates to:
  /// **'Transfer / Floating Columns'**
  String get floatingColumnsTitle;

  /// Title for discontinuous walls
  ///
  /// In en, this message translates to:
  /// **'Discontinuous Shear Walls'**
  String get discontinuousWallsTitle;

  /// Title for soft storey check
  ///
  /// In en, this message translates to:
  /// **'Soft Storey'**
  String get softStoreyTitle;

  /// Title for beam preliminary sizing
  ///
  /// In en, this message translates to:
  /// **'Beam Sizing'**
  String get beamSizingTitle;

  /// Title for slab openings proximity
  ///
  /// In en, this message translates to:
  /// **'Slab Openings Proximity'**
  String get openingsProximityTitle;

  /// Button label for EC8 seismic analysis
  ///
  /// In en, this message translates to:
  /// **'EC8 Seismic'**
  String get ec8SeismicButton;

  /// Warning for beam depth
  ///
  /// In en, this message translates to:
  /// **'Recommended depth: min {depth} cm'**
  String beamDepthWarning(int depth);

  /// Warning for floating column
  ///
  /// In en, this message translates to:
  /// **'Column {name} on {storey} is floating on the slab (no lower support)!'**
  String floatingColumnWarning(String name, String storey);

  /// Apply action button
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyAction;

  /// Offset action button
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get offsetAction;

  /// Title for renaming column dialog
  ///
  /// In en, this message translates to:
  /// **'Rename Column'**
  String get renameColumnTitle;

  /// Title for renaming beam dialog
  ///
  /// In en, this message translates to:
  /// **'Rename Beam'**
  String get renameBeamTitle;

  /// Input label for designation
  ///
  /// In en, this message translates to:
  /// **'Designation (e.g. C1, C2, W1)'**
  String get designationLabel;

  /// Keep both button in offset dialog
  ///
  /// In en, this message translates to:
  /// **'Keep Both'**
  String get keepBoth;

  /// Delete previous button in offset dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Previous'**
  String get deletePrevious;

  /// Title for offset confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Offset Created'**
  String get offsetCreatedTitle;

  /// Prompt to delete previous axis after offset
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete the previous axis \"{name}\"?'**
  String deletePreviousAxisPrompt(String name);

  /// Prompt to delete previous column after offset
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete the previous column \"{name}\"?'**
  String deletePreviousColumnPrompt(String name);

  /// Offset dialog title
  ///
  /// In en, this message translates to:
  /// **'Offset with duplication: {item}'**
  String offsetWithDuplication(String item);

  /// Distance in meters label
  ///
  /// In en, this message translates to:
  /// **'Distance (meters)'**
  String get distanceMeters;

  /// Direction prompt for duplication
  ///
  /// In en, this message translates to:
  /// **'Duplication Direction:'**
  String get duplicationDirection;

  /// Left direction button
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get directionLeft;

  /// Right direction button
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get directionRight;

  /// Up direction button
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get directionUp;

  /// Down direction button
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get directionDown;

  /// Drag instruction for offset direction
  ///
  /// In en, this message translates to:
  /// **'Specify direction by dragging on canvas'**
  String get specifyDirectionByDrag;

  /// Overlay banner text for drag offset
  ///
  /// In en, this message translates to:
  /// **'Drag for direction • Release to offset ({distance} m)'**
  String dragForDirectionReleaseToOffset(String distance);

  /// Title for column dimensions dialog
  ///
  /// In en, this message translates to:
  /// **'Column Dimensions'**
  String get columnDimensionsTitle;

  /// Width in cm label
  ///
  /// In en, this message translates to:
  /// **'Width (cm)'**
  String get widthCm;

  /// Height in cm label
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// Rectangular shape label
  ///
  /// In en, this message translates to:
  /// **'Rectangular'**
  String get shapeRectangular;

  /// Circular shape label
  ///
  /// In en, this message translates to:
  /// **'Circular'**
  String get shapeCircular;

  /// L-shaped shape label
  ///
  /// In en, this message translates to:
  /// **'L-shaped'**
  String get shapeLShape;

  /// Title for shear wall thickness dialog
  ///
  /// In en, this message translates to:
  /// **'Shear Wall Thickness'**
  String get shearWallThicknessTitle;

  /// Thickness in cm label
  ///
  /// In en, this message translates to:
  /// **'Thickness (cm)'**
  String get thicknessCm;

  /// Title for beam dimensions dialog
  ///
  /// In en, this message translates to:
  /// **'Beam Dimensions'**
  String get beamDimensionsTitle;

  /// Width b in cm label
  ///
  /// In en, this message translates to:
  /// **'Width b (cm)'**
  String get widthBCm;

  /// Depth h in cm label
  ///
  /// In en, this message translates to:
  /// **'Depth h (cm)'**
  String get depthHCm;

  /// Title for slab thickness dialog and card
  ///
  /// In en, this message translates to:
  /// **'Slab Thickness'**
  String get slabThicknessTitle;

  /// Slab thickness in cm label
  ///
  /// In en, this message translates to:
  /// **'Thickness h (cm)'**
  String get slabThicknessHCm;

  /// Title for grid axis name dialog
  ///
  /// In en, this message translates to:
  /// **'Grid Axis Name'**
  String get axisNameTitle;

  /// Label for grid axis name input
  ///
  /// In en, this message translates to:
  /// **'Axis Name / Number (e.g. 1, A, 1-1)'**
  String get axisNameLabel;

  /// Title for shear wall
  ///
  /// In en, this message translates to:
  /// **'Shear Wall'**
  String get shearWallTitle;

  /// Title for beam
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get beamTitle;

  /// Title for slab opening
  ///
  /// In en, this message translates to:
  /// **'Slab Opening'**
  String get slabOpeningTitle;

  /// Title for MEP shaft opening
  ///
  /// In en, this message translates to:
  /// **'Shaft'**
  String get openingShaftTitle;

  /// Title for staircase opening
  ///
  /// In en, this message translates to:
  /// **'Staircase Opening'**
  String get openingStaircaseTitle;

  /// Title for elevator shaft opening
  ///
  /// In en, this message translates to:
  /// **'Elevator Shaft'**
  String get openingElevatorTitle;

  /// Title for grid axis
  ///
  /// In en, this message translates to:
  /// **'Axis \"{name}\"'**
  String gridAxisTitle(String name);

  /// Prefix for structural level elevation
  ///
  /// In en, this message translates to:
  /// **'S.L.'**
  String get structuralElevationLabel;

  /// Tooltip for CAD underlay layers button
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay Layers'**
  String get layersTooltip;

  /// Dimensions button in toolbar
  ///
  /// In en, this message translates to:
  /// **'Dimensions...'**
  String get dimensionsEllipsis;

  /// Other button in toolbar
  ///
  /// In en, this message translates to:
  /// **'Other...'**
  String get otherEllipsis;

  /// Hidden beam label
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get hiddenBeamLabel;

  /// Shaft opening preset label
  ///
  /// In en, this message translates to:
  /// **'Shaft (40×60)'**
  String get shaftOpeningLabel;

  /// Elevator opening preset label
  ///
  /// In en, this message translates to:
  /// **'Elevator (1.8×2.0)'**
  String get elevatorOpeningLabel;

  /// Stairs opening preset label
  ///
  /// In en, this message translates to:
  /// **'Stairs (2.4×4.5)'**
  String get stairsOpeningLabel;

  /// Name button in toolbar
  ///
  /// In en, this message translates to:
  /// **'Name...'**
  String get nameEllipsis;

  /// Abbreviation for points
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get pointsAbbr;

  /// Tag for picking opposite corner of opening
  ///
  /// In en, this message translates to:
  /// **'Opening: pick opposite corner'**
  String get previewOpeningCorner2Tag;

  /// Button to cancel custom opening
  ///
  /// In en, this message translates to:
  /// **'Cancel opening'**
  String get cancelOpening;

  /// Title for max eccentricity stat card
  ///
  /// In en, this message translates to:
  /// **'Max. Ecc.'**
  String get seismicStatMaxEccentricity;

  /// Title for torsional sensitivity stat card
  ///
  /// In en, this message translates to:
  /// **'Torsion'**
  String get seismicStatTorsion;

  /// High status indicator
  ///
  /// In en, this message translates to:
  /// **'HIGH'**
  String get seismicStatusHigh;

  /// Normal status indicator
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get seismicStatusNormal;

  /// Title for floating columns stat card
  ///
  /// In en, this message translates to:
  /// **'Floating Cols'**
  String get seismicStatFloatingColumns;

  /// Title for shear walls EC8 stat card
  ///
  /// In en, this message translates to:
  /// **'Shear Walls (EC8)'**
  String get seismicStatShearWallsEc8;

  /// Deficit status indicator
  ///
  /// In en, this message translates to:
  /// **'DEFICIT'**
  String get seismicStatusDeficit;

  /// OK coverage status indicator
  ///
  /// In en, this message translates to:
  /// **'OK >=1%'**
  String get seismicStatusOkCoverage;

  /// Tab title for seismic balance CM/CR
  ///
  /// In en, this message translates to:
  /// **'Balance (CM/CR)'**
  String get seismicTabBalance;

  /// Tab title for shear walls
  ///
  /// In en, this message translates to:
  /// **'Walls (%)'**
  String get seismicTabWalls;

  /// Tab title for structural regularity
  ///
  /// In en, this message translates to:
  /// **'Regularity'**
  String get seismicTabRegularity;

  /// Tab title for beams and openings
  ///
  /// In en, this message translates to:
  /// **'Beams/Openings'**
  String get seismicTabBeamsOpenings;

  /// Message when no storeys exist in project
  ///
  /// In en, this message translates to:
  /// **'No storeys defined in the project.'**
  String get seismicNoStoreys;

  /// Header title for seismic eccentricity
  ///
  /// In en, this message translates to:
  /// **'Seismic Eccentricity'**
  String get seismicEccentricityTitle;

  /// Badge for torsionally sensitive storey
  ///
  /// In en, this message translates to:
  /// **'Torsionally Sensitive'**
  String get seismicTorsionSensitive;

  /// Badge for balanced storey
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get seismicBalanced;

  /// Label for eccentricity in X
  ///
  /// In en, this message translates to:
  /// **'Eccentricity X (ex)'**
  String get seismicEccentricityXLabel;

  /// Label for eccentricity in Y
  ///
  /// In en, this message translates to:
  /// **'Eccentricity Y (ey)'**
  String get seismicEccentricityYLabel;

  /// Label for Eurocode 8 limit
  ///
  /// In en, this message translates to:
  /// **'EC8 Limit'**
  String get seismicLimitEc8Label;

  /// Status badge for building that is torsionally stiff but has eccentricity
  ///
  /// In en, this message translates to:
  /// **'Torsionally Stiff (e > 0.30·r)'**
  String get seismicTorsionStiffEccentric;

  /// Short stat card value for eccentric building
  ///
  /// In en, this message translates to:
  /// **'Eccentric'**
  String get seismicStatusEccentricShort;

  /// Label for Eurocode 8 torsional radii
  ///
  /// In en, this message translates to:
  /// **'Torsional radii (rx, ry)'**
  String get seismicTorsionalRadiiLabel;

  /// Label for Eurocode 8 floor mass gyration radius
  ///
  /// In en, this message translates to:
  /// **'Floor mass radius (ls)'**
  String get seismicMassRadiusLabel;

  /// Formula label for EC8 eccentricity limit
  ///
  /// In en, this message translates to:
  /// **'≤ 0.30·r (EC8)'**
  String get seismicLimitEc8Formula;

  /// Header title for shear wall coverage
  ///
  /// In en, this message translates to:
  /// **'Shear Wall Coverage'**
  String get seismicShearWallCoverageTitle;

  /// Badge for OK wall coverage
  ///
  /// In en, this message translates to:
  /// **'OK (≥ 1.0%)'**
  String get seismicOkMinCoverage;

  /// Badge for deficient wall coverage
  ///
  /// In en, this message translates to:
  /// **'DEFICIT (< 1.0%)'**
  String get seismicDeficitMinCoverage;

  /// Label for X wall coverage
  ///
  /// In en, this message translates to:
  /// **'X Coverage (ρ_wx):'**
  String get seismicWallCoverageXLabel;

  /// Label for Y wall coverage
  ///
  /// In en, this message translates to:
  /// **'Y Coverage (ρ_wy):'**
  String get seismicWallCoverageYLabel;

  /// EC8 wall recommendation explanation
  ///
  /// In en, this message translates to:
  /// **'Eurocode 8 recommendation: minimum 1.0% - 1.5% shear walls in each direction relative to floor area ({area} m²).'**
  String seismicWallRecommendationText(String area);

  /// Header title for floating columns
  ///
  /// In en, this message translates to:
  /// **'Floating / Transfer Columns'**
  String get seismicFloatingColumnsTitle;

  /// Count of items found badge
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String seismicCountFound(int count);

  /// Text when no floating columns exist
  ///
  /// In en, this message translates to:
  /// **'No floating columns detected. All columns transfer loads directly to lower supports.'**
  String get seismicNoFloatingColumnsText;

  /// Warning about floating columns
  ///
  /// In en, this message translates to:
  /// **'CRITICAL FOR SEISMIC SAFETY (EC8 §4.2.3.3): Floating columns transfer high concentrated loads directly onto the slab!'**
  String get seismicCriticalEc8FloatingText;

  /// List item describing floating columns on a storey
  ///
  /// In en, this message translates to:
  /// **'• {storey}: Columns {columns} are floating without lower column.'**
  String seismicFloatingColItem(String storey, String columns);

  /// Title for soft storey check
  ///
  /// In en, this message translates to:
  /// **'Soft Storey Check'**
  String get seismicSoftStoreyTitle;

  /// Danger badge
  ///
  /// In en, this message translates to:
  /// **'DANGER'**
  String get seismicDanger;

  /// None badge
  ///
  /// In en, this message translates to:
  /// **'NONE'**
  String get seismicNone;

  /// Danger text for soft storey
  ///
  /// In en, this message translates to:
  /// **'Stiffness drop detected (> 30%) between adjacent storeys. This creates a risk of soft storey collapse mechanism during earthquakes.'**
  String get seismicSoftStoreyDangerText;

  /// OK text for soft storey
  ///
  /// In en, this message translates to:
  /// **'Stiffness changes smoothly across storeys (no soft storeys detected).'**
  String get seismicSoftStoreyOkText;

  /// Text when no beams or openings exist
  ///
  /// In en, this message translates to:
  /// **'No beams or slab openings defined.'**
  String get seismicNoBeamsOrOpenings;

  /// Title for preliminary beam sizing
  ///
  /// In en, this message translates to:
  /// **'Preliminary beam sizing (h = L/10 - L/12):'**
  String get seismicBeamSizingTitle;

  /// Span length in meters
  ///
  /// In en, this message translates to:
  /// **'Span L = {span} m'**
  String seismicSpanM(String span);

  /// Title for openings near supports check
  ///
  /// In en, this message translates to:
  /// **'Slab openings near supports (< 4d):'**
  String get seismicOpeningsProximityTitle;

  /// Recommendation text for floating columns
  ///
  /// In en, this message translates to:
  /// **'Columns {names} are FLOATING on the slab (no column underneath). This is a serious seismic vulnerability! '**
  String seismicRecFloatingCols(String names);

  /// Recommendation text for high torsion
  ///
  /// In en, this message translates to:
  /// **'High torsional sensitivity: eccentricity {ecc} m ({pct}%). '**
  String seismicRecHighTorsion(String ecc, int pct);

  /// Add wall east recommendation
  ///
  /// In en, this message translates to:
  /// **'Recommendation: add a shear wall in the eastern (right) part. '**
  String get seismicRecAddWallEast;

  /// Add wall west recommendation
  ///
  /// In en, this message translates to:
  /// **'Recommendation: add a shear wall in the western (left) part. '**
  String get seismicRecAddWallWest;

  /// Add wall north recommendation
  ///
  /// In en, this message translates to:
  /// **'Recommendation: add a shear wall in the northern part. '**
  String get seismicRecAddWallNorth;

  /// Add wall south recommendation
  ///
  /// In en, this message translates to:
  /// **'Recommendation: add a shear wall in the southern part. '**
  String get seismicRecAddWallSouth;

  /// Deficit in both directions
  ///
  /// In en, this message translates to:
  /// **'Shear wall deficit in both directions (X: {rx}%, Y: {ry}% < 1.0%). Additional shear walls recommended. '**
  String seismicRecDeficitBoth(String rx, String ry);

  /// Deficit in X direction
  ///
  /// In en, this message translates to:
  /// **'Shear wall deficit in X ({rx}% < 1.0%). Additional X-direction shear wall recommended. '**
  String seismicRecDeficitX(String rx);

  /// Deficit in Y direction
  ///
  /// In en, this message translates to:
  /// **'Shear wall deficit in Y ({ry}% < 1.0%). Additional Y-direction shear wall recommended. '**
  String seismicRecDeficitY(String ry);

  /// Balanced seismic layout
  ///
  /// In en, this message translates to:
  /// **'Seismic balance and shear wall percentage coverage are excellent. '**
  String get seismicRecBalanced;

  /// Recommendation text when building is torsionally stiff but has structural eccentricity
  ///
  /// In en, this message translates to:
  /// **'Torsionally stiff layout (rx={rx} m, ry={ry} m ≥ ls={ls} m), but structural eccentricity ({ecc} m) exceeds 0.30·r. Requires 3D spatial dynamic modal response spectrum analysis per Eurocode 8. '**
  String seismicRecTorsionStiffEccentric(
    String rx,
    String ry,
    String ls,
    String ecc,
  );

  /// Recommendation text when building satisfies EC8 plan regularity
  ///
  /// In en, this message translates to:
  /// **'Regular in plan per EC8 §4.2.3.2 (rx={rx} m, ry={ry} m ≥ ls={ls} m, e ≤ 0.30·r). Excellent torsional balance. '**
  String seismicRecTorsionRegular(String rx, String ry, String ls);

  /// Recommendation text when building is torsionally flexible
  ///
  /// In en, this message translates to:
  /// **'Torsionally flexible system per EC8 §4.2.3.2 (rx={rx} m, ry={ry} m < ls={ls} m). Insufficient perimeter torsional stiffness! Additional perimeter shear walls/columns recommended. '**
  String seismicRecTorsionFlexible(String rx, String ry, String ls);

  /// Soft storey warning prefix
  ///
  /// In en, this message translates to:
  /// **'WARNING: SOFT STOREY! Lateral stiffness of this storey is > 30% lower than the storey above. '**
  String get seismicRecSoftStoreyPrefix;

  /// Beam depth insufficient recommendation
  ///
  /// In en, this message translates to:
  /// **'For span L = {span} m, depth {depth} cm is insufficient. Recommended beam {recW}x{recH} cm.'**
  String seismicRecBeamDepthInsufficient(
    String span,
    int depth,
    int recW,
    int recH,
  );

  /// Beam width insufficient recommendation
  ///
  /// In en, this message translates to:
  /// **'Width {width} cm is below seismic minimum (25 cm under EC8). Recommended 25x{depth} cm.'**
  String seismicRecBeamWidthInsufficient(int width, int depth);

  /// Beam sizing adequate recommendation
  ///
  /// In en, this message translates to:
  /// **'Cross-section {width}x{depth} cm is adequately sized for span L = {span} m.'**
  String seismicRecBeamSizingOk(int width, int depth, String span);

  /// Opening too close to support recommendation
  ///
  /// In en, this message translates to:
  /// **'Opening is {dist} m from {support} (< 0.70 m), penetrating the punching cone and requiring special edge trimming!'**
  String seismicRecOpeningClose(String dist, String support);

  /// Opening at safe distance recommendation
  ///
  /// In en, this message translates to:
  /// **'Opening is at a safe distance ({dist} m from {support}).'**
  String seismicRecOpeningSafe(String dist, String support);

  /// Badge when a storey lacks a slab diaphragm
  ///
  /// In en, this message translates to:
  /// **'No Slab Diaphragm'**
  String get seismicNoSlabBadge;

  /// Text when eccentricity cannot be calculated without slab
  ///
  /// In en, this message translates to:
  /// **'N/A (Slab required)'**
  String get seismicNoSlabEccentricity;

  /// Recommendation when storey lacks slab diaphragm
  ///
  /// In en, this message translates to:
  /// **'No floor slab defined on this storey. In accordance with Eurocode 8 and structural dynamics, a floor slab over vertical elements is required to form a horizontal seismic diaphragm and compute Center of Mass (CM), Center of Rigidity (CR), and eccentricity.'**
  String get seismicRecNoSlabDiaphragm;

  /// Recommendation when walls are outside slab
  ///
  /// In en, this message translates to:
  /// **'Shear wall(s) {names} are located outside the slab boundary and do not connect to the horizontal diaphragm. They are excluded from CR and stiffness calculation.'**
  String seismicRecDisconnectedWalls(String names);

  /// Recommendation when columns are outside slab
  ///
  /// In en, this message translates to:
  /// **'Column(s) {names} are located outside the slab boundary and do not connect to the horizontal diaphragm.'**
  String seismicRecDisconnectedCols(String names);

  /// Warning note when walls are outside slab
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wall outside slab (excluded from diaphragm)} other{{count} walls outside slab (excluded from diaphragm)}}'**
  String seismicWallsOutsideSlabWarning(int count);

  /// Text when wall ratio cannot be computed without slab
  ///
  /// In en, this message translates to:
  /// **'Shear wall ratio cannot be computed without a floor slab diaphragm.'**
  String get seismicNoSlabWallCoverage;

  /// Foundation base pressure stat card title
  ///
  /// In en, this message translates to:
  /// **'Base Pressure'**
  String get verticalBasePressure;

  /// Message when no columns exist
  ///
  /// In en, this message translates to:
  /// **'No columns defined in the project.'**
  String get verticalNoColumns;

  /// Label for punching shear check
  ///
  /// In en, this message translates to:
  /// **'Punching Shear (EC2 §6.4):'**
  String get verticalPunchingCheckLabel;

  /// Slab thickness insufficient
  ///
  /// In en, this message translates to:
  /// **'For span L = {span} m, slab thickness {cur} cm is insufficient. Minimum {req} cm recommended.'**
  String verticalRecSlabInsufficient(String span, int cur, int req);

  /// Beamless slab excessive deflection warning
  ///
  /// In en, this message translates to:
  /// **'For clear span L = {span} m without beams, slab {cur} cm will deflect excessively. Minimum {req} cm or main beams 25x50 cm recommended.'**
  String verticalRecSlabBeamlessDeflection(String span, int cur, int req);

  /// Slab thickness safe
  ///
  /// In en, this message translates to:
  /// **'Slab thickness ({cur} cm) is adequate for clear span L = {span} m.'**
  String verticalRecSlabSafe(int cur, String span);

  /// Column overloaded recommendation
  ///
  /// In en, this message translates to:
  /// **'Column {name} in {storey} cannot be {curW}x{curH} cm; must be at least {minSec} to support {storeys} storeys (Ned = {ned} kN, capacity Nrd = {nrd} kN).'**
  String verticalRecColOverloaded(
    String name,
    String storey,
    int curW,
    int curH,
    String minSec,
    int storeys,
    String ned,
    String nrd,
  );

  /// Column near capacity warning
  ///
  /// In en, this message translates to:
  /// **'Column {name} in {storey} is near capacity ({util}%). Upgrading to {minSec} is recommended.'**
  String verticalRecColWarning(
    String name,
    String storey,
    int util,
    String minSec,
  );

  /// Column safe recommendation
  ///
  /// In en, this message translates to:
  /// **'Column {name} ({curW}x{curH} cm) in {storey} safely carries {storeys} storeys ({util}%).'**
  String verticalRecColSafe(
    String name,
    int curW,
    int curH,
    String storey,
    int storeys,
    int util,
  );

  /// Punching shear risk recommendation
  ///
  /// In en, this message translates to:
  /// **'Risk of slab punching at {name} (v_Ed = {ved} MPa > v_Rd,c = {vrdc} MPa). Recommended: drop panel, slab {slabH} cm or larger column.'**
  String verticalRecPunchingRisk(
    String name,
    String ved,
    String vrdc,
    int slabH,
  );

  /// Column protected from punching due to connected beams
  ///
  /// In en, this message translates to:
  /// **'Column {name} is protected from punching: slab loads are carried directly by framing beams.'**
  String verticalRecPunchingProtectedByBeams(String name);

  /// Columns tab title
  ///
  /// In en, this message translates to:
  /// **'Columns ({count})'**
  String verticalTabColumns(int count);

  /// Slabs tab title
  ///
  /// In en, this message translates to:
  /// **'Slabs ({count})'**
  String verticalTabSlabs(int count);

  /// Foundations tab title
  ///
  /// In en, this message translates to:
  /// **'Foundations'**
  String get verticalTabFoundations;

  /// Storeys carried summary
  ///
  /// In en, this message translates to:
  /// **'{storey} • Carries {storeys} {storeysLabel} • Atrib = {area} m²'**
  String verticalStoreysCarried(
    String storey,
    int storeys,
    String storeysLabel,
    String area,
  );

  /// Singular storey word
  ///
  /// In en, this message translates to:
  /// **'storey'**
  String get verticalStoreySingle;

  /// Plural storeys word
  ///
  /// In en, this message translates to:
  /// **'storeys'**
  String get verticalStoreyPlural;

  /// Axial compression label
  ///
  /// In en, this message translates to:
  /// **'Axial Compression (EC2 §5.8):'**
  String get verticalAxialCompressionLabel;

  /// Message when no slabs exist
  ///
  /// In en, this message translates to:
  /// **'No slabs defined in the project.'**
  String get verticalNoSlabs;

  /// Slab storey card title
  ///
  /// In en, this message translates to:
  /// **'Slab - {storey}'**
  String verticalSlabStoreyTitle(String storey);

  /// Slab status safe
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get verticalSlabStatusOk;

  /// Slab status enlarge
  ///
  /// In en, this message translates to:
  /// **'Enlargement recommended'**
  String get verticalSlabStatusEnlarge;

  /// Clear span label
  ///
  /// In en, this message translates to:
  /// **'Clear span (Lmax)'**
  String get verticalClearSpanLmax;

  /// Current thickness label
  ///
  /// In en, this message translates to:
  /// **'Current thickness (h)'**
  String get verticalCurrentThicknessH;

  /// Required thickness label
  ///
  /// In en, this message translates to:
  /// **'Required (EC2 §7.4)'**
  String get verticalRequiredThicknessEc2;

  /// Foundation evaluation header
  ///
  /// In en, this message translates to:
  /// **'Foundation Load Assessment'**
  String get verticalFoundationsEvaluation;

  /// Total base load label
  ///
  /// In en, this message translates to:
  /// **'Total vertical load at foundation (Ned,base):'**
  String get verticalTotalBaseLoadNed;

  /// Footprint area label
  ///
  /// In en, this message translates to:
  /// **'Footprint area (foundation):'**
  String get verticalFootprintArea;

  /// Average base pressure label
  ///
  /// In en, this message translates to:
  /// **'Average soil base pressure (σ_base):'**
  String get verticalMeanBasePressure;

  /// Base pressure safe text
  ///
  /// In en, this message translates to:
  /// **'Base pressure ({pressure} kPa) is within standard limits for mat/strip foundations in moderate to good soils (R0 >= 200 kPa).'**
  String verticalBasePressureSafeText(String pressure);

  /// Base pressure high text
  ///
  /// In en, this message translates to:
  /// **'Base pressure ({pressure} kPa) is high. A full mat foundation or piling is recommended following a geotechnical report.'**
  String verticalBasePressureHighText(String pressure);

  /// Distance measurement tool label
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get toolMeasure;

  /// Distance in centimeters label
  ///
  /// In en, this message translates to:
  /// **'Distance (cm)'**
  String get distanceCentimeters;

  /// Button to confirm layers and enter structural module
  ///
  /// In en, this message translates to:
  /// **'Load Structural Module'**
  String get loadStructuralModule;

  /// Loading message while CAD layers are being updated
  ///
  /// In en, this message translates to:
  /// **'Updating layers...'**
  String get updatingLayers;

  /// Button to quickly isolate structural walls and axes
  ///
  /// In en, this message translates to:
  /// **'Isolate Structural Layers'**
  String get isolateStructuralLayers;

  /// Button to show all CAD layers
  ///
  /// In en, this message translates to:
  /// **'Show All Layers'**
  String get showAllLayers;

  /// Title of layer setup sheet before structural workspace
  ///
  /// In en, this message translates to:
  /// **'Prepare CAD Layers for BIM'**
  String get layersPreparationTitle;

  /// Subtitle explaining layer cleanup
  ///
  /// In en, this message translates to:
  /// **'Hide architectural clutter, text, and furniture for better clarity and performance.'**
  String get layersPreparationSubtitle;

  /// Menu action to export structural model
  ///
  /// In en, this message translates to:
  /// **'Export BiM Model'**
  String get exportBimModel;

  /// Option to export full BiM model in JSON format
  ///
  /// In en, this message translates to:
  /// **'BiM Project (JSON)'**
  String get exportBimJson;

  /// Option to export structural elements to DXF
  ///
  /// In en, this message translates to:
  /// **'Structural AutoCAD (DXF)'**
  String get exportStructuralDxf;

  /// Success message after export
  ///
  /// In en, this message translates to:
  /// **'Model exported successfully'**
  String get exportSuccess;

  /// Error message when export fails
  ///
  /// In en, this message translates to:
  /// **'Failed to export model: {error}'**
  String exportFailed(String error);

  /// Structural bottom-up elevation title for slab overhead
  ///
  /// In en, this message translates to:
  /// **'Slab over {storey}'**
  String slabOverStorey(String storey);

  /// Standard shear wall dimension preset
  ///
  /// In en, this message translates to:
  /// **'25×150 cm'**
  String get shearWallSizePreset;

  /// Alternative standard shear wall preset
  ///
  /// In en, this message translates to:
  /// **'25×120 cm'**
  String get shearWallSizePresetAlt;

  /// Button to configure custom shear wall dimensions
  ///
  /// In en, this message translates to:
  /// **'Custom Wall...'**
  String get customWallDimensions;

  /// Measured distance display
  ///
  /// In en, this message translates to:
  /// **'Distance: {meters} m ({cm} cm)'**
  String measuredDistance(String meters, String cm);

  /// Delta coordinates display
  ///
  /// In en, this message translates to:
  /// **'ΔX = {dx} m, ΔY = {dy} m'**
  String measuredDelta(String dx, String dy);

  /// Button to clear measurement ruler
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearMeasurement;

  /// Prefix letter for column numbering
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get columnNamePrefix;

  /// Prefix letter for shear wall numbering
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get shearWallNamePrefix;

  /// Top of concrete level marker text
  ///
  /// In en, this message translates to:
  /// **'T.O.C. {elevation}'**
  String slabSectionElevationMarker(String elevation);

  /// Slab thickness label in elevation marker
  ///
  /// In en, this message translates to:
  /// **'d = {thickness} cm'**
  String slabThicknessLabel(String thickness);

  /// Title/action for wall and axis detection
  ///
  /// In en, this message translates to:
  /// **'Auto-Detect Walls & Axes'**
  String get autoDetectWallsAndAxes;

  /// Prompt when walls are automatically detected upon opening drawing
  ///
  /// In en, this message translates to:
  /// **'Detected walls ({thickness} {unit}) in \"{layer}\". Isolate walls and generate centerline axes?'**
  String autoDetectWallsPrompt(String thickness, String unit, String layer);

  /// Button to isolate walls and create axis layer
  ///
  /// In en, this message translates to:
  /// **'Isolate Walls & Generate Axes'**
  String get isolateWallsAndGenerateAxes;

  /// Feedback message when walls and axes are successfully generated
  ///
  /// In en, this message translates to:
  /// **'Generated {axesCount} axes and isolated {wallsCount} wall contours ({unit})'**
  String wallsAndAxesGeneratedSuccess(
    int axesCount,
    int wallsCount,
    String unit,
  );

  /// Message when no wall pairs are detected
  ///
  /// In en, this message translates to:
  /// **'No standard wall pairs (20-30 cm) detected in drawing'**
  String get noWallsDetected;

  /// Candidate summary for layer ranking
  ///
  /// In en, this message translates to:
  /// **'Found {pairCount} wall pairs ({length} m)'**
  String wallCandidatesFound(int pairCount, String length);

  /// Subtitle describing wall and axis extraction in layer prep modal
  ///
  /// In en, this message translates to:
  /// **'Find 20-30 cm walls, isolate contours into WALLS_250 and draw grid axes.'**
  String get autoDetectWallsSubtitle;

  /// Title for strip footing foundations on ground level
  ///
  /// In en, this message translates to:
  /// **'Strip Foundations (±0.00)'**
  String get stripFootingFoundation;

  /// Title for mat foundation raft
  ///
  /// In en, this message translates to:
  /// **'Mat Foundation (±0.00)'**
  String get matFoundation;

  /// Label for foundation strip footing width
  ///
  /// In en, this message translates to:
  /// **'Foundation • b = {width} cm'**
  String foundationFootingLabel(int width);

  /// Label for overhead slab elevation
  ///
  /// In en, this message translates to:
  /// **'Overhead Slab (+{elev} m)'**
  String overheadSlabLabel(String elev);

  /// Standalone BiM projects title on Home screen and navigation
  ///
  /// In en, this message translates to:
  /// **'BiM Projects'**
  String get bimProjects;

  /// Subtitle for BiM Projects hero card
  ///
  /// In en, this message translates to:
  /// **'Structural models & multi-storey drawings'**
  String get bimProjectsSubtitle;

  /// Title of the project library screen
  ///
  /// In en, this message translates to:
  /// **'BiM Projects Library'**
  String get bimProjectLibraryTitle;

  /// Action and title to create a new BiM project
  ///
  /// In en, this message translates to:
  /// **'New BiM Project'**
  String get bimProjectNew;

  /// Label for project name field
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get bimProjectName;

  /// Hint text for project name field
  ///
  /// In en, this message translates to:
  /// **'e.g. Residential Building Flora'**
  String get bimProjectNameHint;

  /// Label for project location or city
  ///
  /// In en, this message translates to:
  /// **'Location / City'**
  String get bimProjectLocation;

  /// Hint text for project location field
  ///
  /// In en, this message translates to:
  /// **'e.g. Sofia, Bulgaria'**
  String get bimProjectLocationHint;

  /// Header for storeys and underlays section
  ///
  /// In en, this message translates to:
  /// **'Storeys & Underlays'**
  String get bimProjectStoreysSection;

  /// Action to pick and attach an architectural underlay
  ///
  /// In en, this message translates to:
  /// **'Add Underlay'**
  String get bimProjectAddUnderlay;

  /// Action to replace an existing underlay drawing
  ///
  /// In en, this message translates to:
  /// **'Replace Underlay'**
  String get bimProjectReplaceUnderlay;

  /// Status text when no underlay is selected for a storey
  ///
  /// In en, this message translates to:
  /// **'No underlay attached'**
  String get bimProjectNoUnderlay;

  /// Error message when non-CAD file is selected as storey underlay
  ///
  /// In en, this message translates to:
  /// **'Please select a valid .dxf, .dwg or .kcad CAD drawing file.'**
  String get bimProjectUnderlayFormatError;

  /// Storey elevation field label in meters
  ///
  /// In en, this message translates to:
  /// **'Elevation (m)'**
  String get bimProjectElevation;

  /// Storey clear height field label in meters
  ///
  /// In en, this message translates to:
  /// **'Height (m)'**
  String get bimProjectHeight;

  /// Label for storey name
  ///
  /// In en, this message translates to:
  /// **'Storey Name'**
  String get bimProjectStoreyName;

  /// Quick wizard section to generate storey levels
  ///
  /// In en, this message translates to:
  /// **'Quick Storey Setup'**
  String get bimProjectQuickSetup;

  /// Count of underground basement levels
  ///
  /// In en, this message translates to:
  /// **'Basements'**
  String get bimProjectBasementCount;

  /// Count of above ground levels
  ///
  /// In en, this message translates to:
  /// **'Above ground'**
  String get bimProjectAboveGroundCount;

  /// Default floor-to-floor height in meters
  ///
  /// In en, this message translates to:
  /// **'Storey height (m)'**
  String get bimProjectFloorHeight;

  /// Button to generate initial storey list
  ///
  /// In en, this message translates to:
  /// **'Generate Storeys'**
  String get bimProjectGenerateStoreys;

  /// Button to add a single storey
  ///
  /// In en, this message translates to:
  /// **'Add Storey'**
  String get bimProjectAddStorey;

  /// Tooltip or action to delete a storey
  ///
  /// In en, this message translates to:
  /// **'Delete Storey'**
  String get bimProjectDeleteStorey;

  /// Submit button to create the BiM project
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get bimProjectCreateButton;

  /// Status badge when control points are not all confirmed
  ///
  /// In en, this message translates to:
  /// **'Awaiting Alignment'**
  String get bimProjectStatusAlignment;

  /// Status badge when drawings are aligned and ready
  ///
  /// In en, this message translates to:
  /// **'Aligned • BiM Ready'**
  String get bimProjectStatusReady;

  /// Storey count badge
  ///
  /// In en, this message translates to:
  /// **'{count} storeys'**
  String bimProjectStoreysCount(int count);

  /// Action to open the structural BiM model
  ///
  /// In en, this message translates to:
  /// **'Open Model'**
  String get bimProjectOpen;

  /// Action to open the control-point alignment screen
  ///
  /// In en, this message translates to:
  /// **'Align Drawings'**
  String get bimProjectAlignStoreys;

  /// Title for delete project confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Project?'**
  String get bimProjectDeleteConfirmTitle;

  /// Message for delete project confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? All structural elements and drawings will be deleted.'**
  String bimProjectDeleteConfirmMessage(String name);

  /// Action to rename a BiM project
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get bimProjectRename;

  /// Title for the storey alignment screen
  ///
  /// In en, this message translates to:
  /// **'Drawing Alignment'**
  String get bimAlignmentTitle;

  /// Instructions explaining how to align underlays
  ///
  /// In en, this message translates to:
  /// **'Tap and hold to place a common control point (e.g. intersection of axes 1 and A) on each storey underlay.'**
  String get bimAlignmentInstructions;

  /// Status indicator for control point coordinates
  ///
  /// In en, this message translates to:
  /// **'Control point set at ({x}, {y})'**
  String bimAlignmentControlPointSet(String x, String y);

  /// Notice when control point has not been set yet
  ///
  /// In en, this message translates to:
  /// **'Control point required'**
  String get bimAlignmentControlPointMissing;

  /// Toggle to show lower storey semi-transparently
  ///
  /// In en, this message translates to:
  /// **'Ghost lower storey'**
  String get bimAlignmentOnionSkin;

  /// Confirmation button to lock alignment and launch BiM designer
  ///
  /// In en, this message translates to:
  /// **'Ready • Start BiM'**
  String get bimAlignmentReadyButton;

  /// Confirmation modal title before automation
  ///
  /// In en, this message translates to:
  /// **'Confirm Alignment & Start BiM'**
  String get bimAlignmentConfirmTitle;

  /// Confirmation modal explanation before wall detection
  ///
  /// In en, this message translates to:
  /// **'All control points are placed. The BiM module will now align the storeys, detect walls and generate grid axes. Proceed?'**
  String get bimAlignmentConfirmMessage;

  /// Export current storey DXF with original coordinates
  ///
  /// In en, this message translates to:
  /// **'Export Storey Drawing (DXF)'**
  String get bimProjectExportStoreyDxf;

  /// Subtitle describing storey DXF export
  ///
  /// In en, this message translates to:
  /// **'Original coordinates with visible & structural layers'**
  String get bimProjectExportStoreyDxfSubtitle;

  /// Export full project package as ZIP
  ///
  /// In en, this message translates to:
  /// **'Export Project Package (ZIP)'**
  String get bimProjectExportAllZip;

  /// Subtitle describing ZIP export
  ///
  /// In en, this message translates to:
  /// **'All storey drawings + structural BiM model'**
  String get bimProjectExportAllZipSubtitle;

  /// Snackbar notification on successful export
  ///
  /// In en, this message translates to:
  /// **'Exported successfully: {filename}'**
  String bimProjectExportSuccess(String filename);

  /// Empty state description in BiM project library
  ///
  /// In en, this message translates to:
  /// **'No BiM projects yet. Tap \'+\' to create your first structural project.'**
  String get bimProjectNoProjects;

  /// Action from storey manager sheet to edit project storeys
  ///
  /// In en, this message translates to:
  /// **'Manage Storeys & Underlays'**
  String get bimProjectManageStoreys;

  /// Default name for basement storey
  ///
  /// In en, this message translates to:
  /// **'Basement {num}'**
  String bimProjectBasement(int num);

  /// Default name for ground floor
  ///
  /// In en, this message translates to:
  /// **'Ground Floor'**
  String get bimProjectGroundFloor;

  /// Default name for above-ground floor
  ///
  /// In en, this message translates to:
  /// **'Floor {num}'**
  String bimProjectFloor(int num);

  /// Status text while saving BiM model
  ///
  /// In en, this message translates to:
  /// **'Saving BiM project...'**
  String get bimProjectSaving;

  /// Success message when underlay is loaded
  ///
  /// In en, this message translates to:
  /// **'Underlay attached'**
  String get bimProjectUnderlayAttached;

  /// Notice when attempting to open unaligned project
  ///
  /// In en, this message translates to:
  /// **'Please align all storeys before entering the BiM designer.'**
  String get bimProjectAlignFirstPrompt;

  /// Loading indicator while opening BiM project workspace
  ///
  /// In en, this message translates to:
  /// **'Loading BiM project and underlays...'**
  String get bimProjectLoading;

  /// Dark CAD theme for drawings canvas
  ///
  /// In en, this message translates to:
  /// **'CAD Dark'**
  String get cadThemeDarkCad;

  /// Paper white theme for drawings canvas
  ///
  /// In en, this message translates to:
  /// **'Paper White'**
  String get cadThemePaperWhite;

  /// Notice when no slab layer is found or when the slab layer contains no entities
  ///
  /// In en, this message translates to:
  /// **'No slab layer found or layer is empty'**
  String get noSlabLayerDetectedOrEmpty;

  /// Notice when a slab layer is detected and added to the structural underlay filter
  ///
  /// In en, this message translates to:
  /// **'Slab layer \"{layer}\" added to structural filter'**
  String slabLayerAddedToFilter(String layer);

  /// Button label to delete the selected vertex of an opening polygon
  ///
  /// In en, this message translates to:
  /// **'Delete Point'**
  String get deleteOpeningPoint;

  /// Notification when two opening vertices are merged
  ///
  /// In en, this message translates to:
  /// **'Opening points merged'**
  String get openingPointsMerged;

  /// Title and button for fine position and nudge bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Position & Nudge'**
  String get finePositionTitle;

  /// Step size label
  ///
  /// In en, this message translates to:
  /// **'Step: {step}'**
  String nudgeStepLabel(String step);

  /// 1 cm step label
  ///
  /// In en, this message translates to:
  /// **'1 cm'**
  String get step1cm;

  /// 5 cm step label
  ///
  /// In en, this message translates to:
  /// **'5 cm'**
  String get step5cm;

  /// 10 cm step label
  ///
  /// In en, this message translates to:
  /// **'10 cm'**
  String get step10cm;

  /// 25 cm step label
  ///
  /// In en, this message translates to:
  /// **'25 cm'**
  String get step25cm;

  /// Label for X coordinate input
  ///
  /// In en, this message translates to:
  /// **'X (m)'**
  String get coordinateXLabel;

  /// Label for Y coordinate input
  ///
  /// In en, this message translates to:
  /// **'Y (m)'**
  String get coordinateYLabel;

  /// Dynamic clear dimension text
  ///
  /// In en, this message translates to:
  /// **'Clear: {distance} m'**
  String clearDistanceDimension(String distance);

  /// Dynamic axial dimension text
  ///
  /// In en, this message translates to:
  /// **'Axis: {distance} m'**
  String axialDistanceDimension(String distance);

  /// Flush face alignment badge
  ///
  /// In en, this message translates to:
  /// **'Flush Face'**
  String get flushFaceAligned;

  /// Shear wall center reference line label
  ///
  /// In en, this message translates to:
  /// **'Ref: Center'**
  String get refLineCenter;

  /// Shear wall left face reference line label
  ///
  /// In en, this message translates to:
  /// **'Ref: Left Face'**
  String get refLineLeft;

  /// Shear wall right face reference line label
  ///
  /// In en, this message translates to:
  /// **'Ref: Right Face'**
  String get refLineRight;

  /// Title for shear wall reference line
  ///
  /// In en, this message translates to:
  /// **'Reference Line'**
  String get refLineTitle;

  /// Button to snap element to nearest axis or face
  ///
  /// In en, this message translates to:
  /// **'Snap to nearest'**
  String get snapToNearest;

  /// Align left face button
  ///
  /// In en, this message translates to:
  /// **'Flush Left'**
  String get alignLeftFace;

  /// Align right face button
  ///
  /// In en, this message translates to:
  /// **'Flush Right'**
  String get alignRightFace;

  /// Align top face button
  ///
  /// In en, this message translates to:
  /// **'Flush Top'**
  String get alignTopFace;

  /// Align bottom face button
  ///
  /// In en, this message translates to:
  /// **'Flush Bottom'**
  String get alignBottomFace;

  /// Notification when shear wall reference line changes
  ///
  /// In en, this message translates to:
  /// **'Reference line: {line}'**
  String shearWallRefLineChanged(String line);

  /// Auto axis constraint mode
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get axisLockAuto;

  /// Lock X coordinate axis constraint
  ///
  /// In en, this message translates to:
  /// **'↔ Lock X'**
  String get axisLockX;

  /// Lock Y coordinate axis constraint
  ///
  /// In en, this message translates to:
  /// **'↕ Lock Y'**
  String get axisLockY;

  /// Axis constraint setting title
  ///
  /// In en, this message translates to:
  /// **'Axis Constraint'**
  String get axisLockTitle;

  /// Equal spacing alignment label
  ///
  /// In en, this message translates to:
  /// **'Equal Spacing'**
  String get equalSpacing;

  /// Equal spacing dimension text
  ///
  /// In en, this message translates to:
  /// **'{distance} = {distance} m'**
  String equalSpacingDimension(String distance);

  /// Title for clear distance section
  ///
  /// In en, this message translates to:
  /// **'Clear Distance to Neighbors'**
  String get clearDistanceToNeighbors;

  /// Clear distance to left neighbor
  ///
  /// In en, this message translates to:
  /// **'To {name} (Left): {dist} m'**
  String clearDistanceLeft(String name, String dist);

  /// Clear distance to right neighbor
  ///
  /// In en, this message translates to:
  /// **'To {name} (Right): {dist} m'**
  String clearDistanceRight(String name, String dist);

  /// Clear distance to top neighbor
  ///
  /// In en, this message translates to:
  /// **'To {name} (Top): {dist} m'**
  String clearDistanceTop(String name, String dist);

  /// Clear distance to bottom neighbor
  ///
  /// In en, this message translates to:
  /// **'To {name} (Bottom): {dist} m'**
  String clearDistanceBottom(String name, String dist);

  /// Button to adjust clear distance
  ///
  /// In en, this message translates to:
  /// **'Clear Distance'**
  String get setClearDistanceAction;

  /// Input label for target clear distance
  ///
  /// In en, this message translates to:
  /// **'Desired clear distance (m)'**
  String get targetClearDistanceLabel;

  /// Apply clear distance button
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyClearDistance;

  /// Notice when no adjacent columns or walls are detected
  ///
  /// In en, this message translates to:
  /// **'No adjacent elements along axes'**
  String get noNeighborsFound;

  /// Status text while precision move is active
  ///
  /// In en, this message translates to:
  /// **'Positioning active'**
  String get precisionMoveActive;

  /// Confirm move button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmMove;

  /// Cancel move button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelMove;

  /// No description provided for @bimProjectEditElevation.
  ///
  /// In en, this message translates to:
  /// **'Edit elevation'**
  String get bimProjectEditElevation;

  /// No description provided for @bimProjectSortStoreys.
  ///
  /// In en, this message translates to:
  /// **'Sort by elevation'**
  String get bimProjectSortStoreys;

  /// No description provided for @bimProjectElevationHelper.
  ///
  /// In en, this message translates to:
  /// **'e.g. +2.85, 0.00, -3.20'**
  String get bimProjectElevationHelper;

  /// No description provided for @bimProjectInvalidElevation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid elevation in metres.'**
  String get bimProjectInvalidElevation;

  /// No description provided for @bimProjectDuplicateElevation.
  ///
  /// In en, this message translates to:
  /// **'A storey already has this elevation.'**
  String get bimProjectDuplicateElevation;

  /// No description provided for @bimProjectConvertingUnderlay.
  ///
  /// In en, this message translates to:
  /// **'Converting underlay…'**
  String get bimProjectConvertingUnderlay;

  /// No description provided for @bimProjectDetectingWallsAndSlabs.
  ///
  /// In en, this message translates to:
  /// **'Detecting walls and slabs…'**
  String get bimProjectDetectingWallsAndSlabs;

  /// No description provided for @bimProjectKcadReady.
  ///
  /// In en, this message translates to:
  /// **'KCAD ready'**
  String get bimProjectKcadReady;

  /// No description provided for @bimProjectConversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Underlay conversion failed'**
  String get bimProjectConversionFailed;

  /// No description provided for @bimProjectReprocessUnderlay.
  ///
  /// In en, this message translates to:
  /// **'Reprocess underlay'**
  String get bimProjectReprocessUnderlay;

  /// No description provided for @bimSlabProjectionCount.
  ///
  /// In en, this message translates to:
  /// **'External areas for review (cyan): {count}. Type and level are not confirmed.'**
  String bimSlabProjectionCount(int count);

  /// No description provided for @bimSlabPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Slab contour proposals'**
  String get bimSlabPreviewTitle;

  /// No description provided for @bimSlabPreviewMissing.
  ///
  /// In en, this message translates to:
  /// **'No contour analysis is saved. Use Reprocess underlay to run it.'**
  String get bimSlabPreviewMissing;

  /// No description provided for @bimSlabPreviewCount.
  ///
  /// In en, this message translates to:
  /// **'Proposed contours: {count}'**
  String bimSlabPreviewCount(int count);

  /// No description provided for @bimSlabPreviewExplanation.
  ///
  /// In en, this message translates to:
  /// **'Orange contours are approximate proposals. Red connections are assumed openings requiring review; they may appear even when no contour was obtained. Enable the structural filter to see them. A proposal may cover only part of the building. Courtyards, shafts and stair openings are not classified. Check the level and concrete edge. No structural slab has been created.'**
  String get bimSlabPreviewExplanation;

  /// No description provided for @bimSlabPreviewRegions.
  ///
  /// In en, this message translates to:
  /// **'Analysed regions: {regions}; without contours: {unresolved}; assumed connections: {gaps}.'**
  String bimSlabPreviewRegions(int regions, int unresolved, int gaps);

  /// No description provided for @bimSlabPreviewSkipped.
  ///
  /// In en, this message translates to:
  /// **'Regions not processed due to the work limit: {count}.'**
  String bimSlabPreviewSkipped(int count);

  /// No description provided for @bimSlabPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reliable closed contour was obtained. Possible causes include open wall gaps, missing walls, ambiguous connections, very small enclosed areas or drawing extents too large for the current resolution.'**
  String get bimSlabPreviewEmpty;

  /// Title in CAD layers bottom sheet
  ///
  /// In en, this message translates to:
  /// **'CAD Layers'**
  String get cadLayersTitle;

  /// Visible layers counter
  ///
  /// In en, this message translates to:
  /// **'{visible} of {total} layers visible'**
  String cadLayersVisibleCount(int visible, int total);

  /// Button to show all CAD layers
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get cadLayersShowAll;

  /// Button to hide all CAD layers
  ///
  /// In en, this message translates to:
  /// **'Hide All'**
  String get cadLayersHideAll;

  /// Label for global lineweight selector
  ///
  /// In en, this message translates to:
  /// **'Lineweight for all:'**
  String get cadLayersLineweightForAll;

  /// Placeholder for global lineweight selector
  ///
  /// In en, this message translates to:
  /// **'Select for all...'**
  String get cadLayersSelectForAll;

  /// Default name for layers with empty name
  ///
  /// In en, this message translates to:
  /// **'Unnamed Layer'**
  String get cadLayersUnnamed;

  /// Number of objects in layer
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 object} other{{count} objects}}'**
  String cadLayersObjectCount(int count);

  /// Label when layer is frozen
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get cadLayersFrozen;

  /// Label for layer lineweight selector
  ///
  /// In en, this message translates to:
  /// **'Lineweight:'**
  String get cadLayersLineweight;

  /// Original lineweight option
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get cadLayersOriginal;

  /// Original lineweight with thickness value
  ///
  /// In en, this message translates to:
  /// **'Original ({mm} mm)'**
  String cadLayersOriginalWithMm(String mm);

  /// Lineweight in millimeters
  ///
  /// In en, this message translates to:
  /// **'{mm} mm'**
  String cadLayersMm(String mm);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bg', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bg':
      return AppLocalizationsBg();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
