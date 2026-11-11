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

  /// No description provided for @architectWallAxisSpacing.
  ///
  /// In en, this message translates to:
  /// **'Between axes'**
  String get architectWallAxisSpacing;

  /// No description provided for @architectWallAxisRadius.
  ///
  /// In en, this message translates to:
  /// **'Axis radius'**
  String get architectWallAxisRadius;

  /// No description provided for @architectWallAxisSetback.
  ///
  /// In en, this message translates to:
  /// **'Axis setback'**
  String get architectWallAxisSetback;

  /// No description provided for @architectWallOperationAxisHelp.
  ///
  /// In en, this message translates to:
  /// **'Wall operations use the core axes, independently of the drawing reference. Clear dimensions are measured between finished faces.'**
  String get architectWallOperationAxisHelp;

  /// No description provided for @architectWallAngleLocked.
  ///
  /// In en, this message translates to:
  /// **'Angle locked'**
  String get architectWallAngleLocked;

  /// No description provided for @architectWallAngleFree.
  ///
  /// In en, this message translates to:
  /// **'Free angle'**
  String get architectWallAngleFree;

  /// No description provided for @architectWallAngleUnlockHelp.
  ///
  /// In en, this message translates to:
  /// **'Unlock the angle for a small sideways correction of the endpoint. Moving the whole wall remains available.'**
  String get architectWallAngleUnlockHelp;

  /// No description provided for @architectWallAngleLockHelp.
  ///
  /// In en, this message translates to:
  /// **'Lock the current angle to lengthen or shorten the wall without rotating it. Moving the whole wall remains available.'**
  String get architectWallAngleLockHelp;

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

  /// Generic Back button text or tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

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

  /// Button to close opening polygon with vertex count
  ///
  /// In en, this message translates to:
  /// **'Close ({count})'**
  String closeOpening(int count);

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

  /// Snap to door/window jamb
  ///
  /// In en, this message translates to:
  /// **'Opening edge'**
  String get snapOpeningEdge;

  /// Snap to door/window centre
  ///
  /// In en, this message translates to:
  /// **'Opening center'**
  String get snapOpeningCenter;

  /// Snap to multiples of the wall thickness
  ///
  /// In en, this message translates to:
  /// **'Module step'**
  String get snapModuleStep;

  /// Snap type center
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get snapCenter;

  /// Snap type quadrant (0°, 90°, 180°, 270° on circle or arc)
  ///
  /// In en, this message translates to:
  /// **'Quadrant'**
  String get snapQuadrant;

  /// Snap type apparent or extended intersection of two lines
  ///
  /// In en, this message translates to:
  /// **'Apparent intersection'**
  String get snapApparentIntersection;

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

  /// Guidance hint for point-by-point slab opening placement tool
  ///
  /// In en, this message translates to:
  /// **'Tap point by point to draw opening'**
  String get openingPointByPointPrompt;

  /// Guidance hint for 2-point rectangular staircase opening tool
  ///
  /// In en, this message translates to:
  /// **'Tap 1st corner, then drag or tap 2nd corner for staircase'**
  String get staircase2PointPrompt;

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
  /// **'Preliminary seismic layout'**
  String get seismicAnalysisTitle;

  /// Subtitle for EC8 seismic analysis
  ///
  /// In en, this message translates to:
  /// **'Layout indicators — not EC8 compliance'**
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

  /// No description provided for @architectCommandReview.
  ///
  /// In en, this message translates to:
  /// **'Review. ✓ saves; X cancels.'**
  String get architectCommandReview;

  /// No description provided for @architectCommandAim.
  ///
  /// In en, this message translates to:
  /// **'Define the edit. X cancels.'**
  String get architectCommandAim;

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
  /// **'Shaft'**
  String get shaftOpeningLabel;

  /// Elevator opening preset label
  ///
  /// In en, this message translates to:
  /// **'Elevator'**
  String get elevatorOpeningLabel;

  /// Stairs opening preset label
  ///
  /// In en, this message translates to:
  /// **'Stairs'**
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
  /// **'Wall ratio*'**
  String get seismicStatShearWallsEc8;

  /// Deficit status indicator
  ///
  /// In en, this message translates to:
  /// **'DEFICIT'**
  String get seismicStatusDeficit;

  /// OK coverage status indicator
  ///
  /// In en, this message translates to:
  /// **'≥1%*'**
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
  /// **'Eccentricity reference'**
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
  /// **'Wall area ratio — heuristic'**
  String get seismicShearWallCoverageTitle;

  /// Badge for OK wall coverage
  ///
  /// In en, this message translates to:
  /// **'≥1% reference'**
  String get seismicOkMinCoverage;

  /// Badge for deficient wall coverage
  ///
  /// In en, this message translates to:
  /// **'<1% reference'**
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
  /// **'Application screening reference: 1.0% connected wall area in each direction relative to net floor area ({area} m²). This is not a universal Eurocode 8 minimum or proof of seismic capacity.'**
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
  /// **'Opening proximity — 0.70 m screening reference'**
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
  /// **'No warning from the preliminary layout indicators. EC8 compliance has not been established. '**
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
  /// **'Clear distance between opening and {support}: {dist} m — below the 0.70 m screening reference. Punching shear and edge reinforcement require separate checks.'**
  String seismicRecOpeningClose(String dist, String support);

  /// Opening at safe distance recommendation
  ///
  /// In en, this message translates to:
  /// **'Clear distance between opening and {support}: {dist} m. Outside the 0.70 m screening band; punching shear has not been verified.'**
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

  /// Label for balanced preliminary seismic risk level
  ///
  /// In en, this message translates to:
  /// **'No layout warning'**
  String get seismicPreliminaryBalanced;

  /// Recommendation when lateral stiffness cannot be computed
  ///
  /// In en, this message translates to:
  /// **'Lateral layout cannot be evaluated: no usable connected supports, an unsupported section, or an ill-conditioned model. CR and eccentricity are unavailable.'**
  String get seismicRigidityUnavailable;

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
  /// **'Ceiling slab above {storey}'**
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

  /// Slab status undetermined
  ///
  /// In en, this message translates to:
  /// **'Undetermined'**
  String get verticalSlabStatusUnknown;

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

  /// No description provided for @bimMeasureGestureHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to pan · Tap for a point · Hold for precision · Pinch to zoom'**
  String get bimMeasureGestureHint;

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

  /// No description provided for @bimSlabLoggiaCount.
  ///
  /// In en, this message translates to:
  /// **'Of these, loggia proposals: {count}.'**
  String bimSlabLoggiaCount(int count);

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

  /// No description provided for @bimGenerateSlabs.
  ///
  /// In en, this message translates to:
  /// **'Generate initial slabs'**
  String get bimGenerateSlabs;

  /// No description provided for @bimSlabsAlreadyGenerated.
  ///
  /// In en, this message translates to:
  /// **'This storey already has generated slabs. Edit them directly; generation will not overwrite your changes.'**
  String get bimSlabsAlreadyGenerated;

  /// No description provided for @bimSlabSeedsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No valid slab contours are available. Process the underlay first.'**
  String get bimSlabSeedsEmpty;

  /// No description provided for @bimSlabSeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Create {count} editable slabs on this storey; skipped: {skipped}. Thickness: {thickness} cm, from the current slab setting.\n\nEdges snap only at distances below 2 cm. These are initial proposals: review the contour, openings, levels and thickness before using them in the structural scheme.'**
  String bimSlabSeedsReview(int count, int skipped, String thickness);

  /// No description provided for @seismicNotEvaluated.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated'**
  String get seismicNotEvaluated;

  /// No description provided for @seismicModelAssumptions.
  ///
  /// In en, this message translates to:
  /// **'Preliminary layout only: rigid diaphragm, common material/restraint factors and simplified weights. Cracking, core coupling, accidental torsion and 3D response are not verified.'**
  String get seismicModelAssumptions;

  /// No description provided for @seismicOpeningNotEvaluated.
  ///
  /// In en, this message translates to:
  /// **'No support or valid opening geometry is available; proximity is not evaluated.'**
  String get seismicOpeningNotEvaluated;

  /// No description provided for @seismicConnectionReview.
  ///
  /// In en, this message translates to:
  /// **'Unverified slab connection: {names}. Partial contact or invalid/overly complex geometry requires review; stiffness and eccentricity are not evaluated.'**
  String seismicConnectionReview(String names);

  /// No description provided for @seismicInvalidSlabGeometry.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated: invalid slab or opening contour. Check self-intersections, openings outside the slab and touching/overlapping openings.'**
  String get seismicInvalidSlabGeometry;

  /// No description provided for @seismicOverlappingSlabs.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated: slabs overlap. Resolve geometry and loads to avoid counting mass twice.'**
  String get seismicOverlappingSlabs;

  /// No description provided for @seismicSeparateRegions.
  ///
  /// In en, this message translates to:
  /// **'Detected {count} disconnected slab regions. A shared centre of rigidity and eccentricity are not evaluated; separate diaphragms or a connection model are required.'**
  String seismicSeparateRegions(int count);

  /// No description provided for @seismicSlabGeometryLimit.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated: slab geometry exceeds the preliminary check\'s capacity. A separate geometry review is required.'**
  String get seismicSlabGeometryLimit;

  /// No description provided for @seismicRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Region {index} · columns: {columns}, walls: {walls}'**
  String seismicRegionTitle(int index, int columns, int walls);

  /// No description provided for @seismicRegionSharedSupport.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated: shared or uncertain support assignment: {names}. A coupling model is required.'**
  String seismicRegionSharedSupport(String names);

  /// No description provided for @seismicRegionScope.
  ///
  /// In en, this message translates to:
  /// **'Isolated preliminary region models with existing slab weights and project surface loads. Coupling, beams between regions and vertical continuity are not evaluated.'**
  String get seismicRegionScope;

  /// No description provided for @seismicLoadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seismic mass loads'**
  String get seismicLoadsTitle;

  /// No description provided for @seismicLoadsScope.
  ///
  /// In en, this message translates to:
  /// **'Preliminary seismic model only. Self-weight 25 × h is added separately; exclude it from the permanent load. When disabled: project G/Q and participation 0.3. Participation is specified by the engineer, not selected automatically from Eurocodes. Vertical and cantilever checks retain their own loads.'**
  String get seismicLoadsScope;

  /// No description provided for @seismicLoadPermanent.
  ///
  /// In en, this message translates to:
  /// **'Additional permanent load G'**
  String get seismicLoadPermanent;

  /// No description provided for @seismicLoadVariable.
  ///
  /// In en, this message translates to:
  /// **'Imposed load Q'**
  String get seismicLoadVariable;

  /// No description provided for @seismicLoadParticipation.
  ///
  /// In en, this message translates to:
  /// **'Q participation in mass (0–1)'**
  String get seismicLoadParticipation;

  /// No description provided for @seismicLoadOverride.
  ///
  /// In en, this message translates to:
  /// **'Separate values for this slab'**
  String get seismicLoadOverride;

  /// No description provided for @seismicLoadSlab.
  ///
  /// In en, this message translates to:
  /// **'Slab {index}'**
  String seismicLoadSlab(int index);

  /// No description provided for @seismicInvalidMassLoads.
  ///
  /// In en, this message translates to:
  /// **'Not evaluated: check loads and thickness. G and Q must be finite nonnegative values, Q participation must be between 0 and 1, and thickness must be positive.'**
  String get seismicInvalidMassLoads;

  /// No description provided for @seismicWallContinuityTitle.
  ///
  /// In en, this message translates to:
  /// **'Wall vertical continuity'**
  String get seismicWallContinuityTitle;

  /// No description provided for @seismicWallContinuityScope.
  ///
  /// In en, this message translates to:
  /// **'Footprint overlap with parallel walls on the preceding project storey. Below 100% requires review for offsets, shortening or interruption. This is not a capacity check; transfer onto beams/columns and foundations are not evaluated.'**
  String get seismicWallContinuityScope;

  /// No description provided for @seismicWallContinuityItem.
  ///
  /// In en, this message translates to:
  /// **'{storey} · {wall}: overlap {coverage}'**
  String seismicWallContinuityItem(String storey, String wall, String coverage);

  /// No description provided for @seismicElevationAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'Vertical checks are not evaluated: duplicate or invalid elevations. Review storey levels.'**
  String get seismicElevationAmbiguous;

  /// No description provided for @seismicDirectionalScope.
  ///
  /// In en, this message translates to:
  /// **'Preliminary stiffness ratio to the upper storey along X/Y. Below 0.70 flags review, not a code verdict. Only uniquely matched single regions are compared.'**
  String get seismicDirectionalScope;

  /// No description provided for @seismicRegionTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Regions across storeys'**
  String get seismicRegionTrackingTitle;

  /// No description provided for @seismicLinkUnique.
  ///
  /// In en, this message translates to:
  /// **'unique overlap'**
  String get seismicLinkUnique;

  /// No description provided for @seismicLinkBranching.
  ///
  /// In en, this message translates to:
  /// **'split/merge — review'**
  String get seismicLinkBranching;

  /// No description provided for @seismicLinkAbsent.
  ///
  /// In en, this message translates to:
  /// **'no overlap — review'**
  String get seismicLinkAbsent;

  /// No description provided for @seismicRegionTrackingItem.
  ///
  /// In en, this message translates to:
  /// **'{storey}, region {region} → {lower}, regions {matches}: {coverage}; {status}. Geometric link, not a verified load path.'**
  String seismicRegionTrackingItem(
    String storey,
    int region,
    String lower,
    String matches,
    String coverage,
    String status,
  );

  /// No description provided for @ceilingSlabTitle.
  ///
  /// In en, this message translates to:
  /// **'Ceiling slab above the storey'**
  String get ceilingSlabTitle;

  /// No description provided for @ceilingSlabContext.
  ///
  /// In en, this message translates to:
  /// **'Storey {level} · ceiling slab above this storey'**
  String ceilingSlabContext(String level);

  /// No description provided for @ceilingExplicitLevel.
  ///
  /// In en, this message translates to:
  /// **'Set concrete top elevation'**
  String get ceilingExplicitLevel;

  /// No description provided for @ceilingConcreteTop.
  ///
  /// In en, this message translates to:
  /// **'Top of concrete'**
  String get ceilingConcreteTop;

  /// No description provided for @ceilingSlabLevels.
  ///
  /// In en, this message translates to:
  /// **'Top {top} m · soffit {bottom} m'**
  String ceilingSlabLevels(String top, String bottom);

  /// No description provided for @ceilingSlabLevelHint.
  ///
  /// In en, this message translates to:
  /// **'The slab and openings are above the active storey. Concrete top: next level minus finish; at the top storey: level plus height minus finish. An explicit elevation refers to concrete.'**
  String get ceilingSlabLevelHint;

  /// No description provided for @ceilingSlabInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive thickness and an elevation placing the slab above this storey and no higher than the next level.'**
  String get ceilingSlabInvalid;

  /// Tag indicating the slab is from the floor above serving as a ceiling
  ///
  /// In en, this message translates to:
  /// **'Overhead slab (ceiling)'**
  String get overheadSlabTag;

  /// No description provided for @slabEdgeOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset edge'**
  String get slabEdgeOffset;

  /// No description provided for @slabEdgeNumber.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get slabEdgeNumber;

  /// No description provided for @slabEdgeDistance.
  ///
  /// In en, this message translates to:
  /// **'Offset (cm)'**
  String get slabEdgeDistance;

  /// No description provided for @slabEdgeHint.
  ///
  /// In en, this message translates to:
  /// **'Positive: outward. Negative: inward. A shared edge also moves in the adjacent slab.'**
  String get slabEdgeHint;

  /// No description provided for @slabEdgeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This correction creates an invalid outline or affects a partially shared edge. Split the shared boundary into matching edges.'**
  String get slabEdgeInvalid;

  /// Button to clean redundant collinear points in slab
  ///
  /// In en, this message translates to:
  /// **'Clean contour'**
  String get cleanSlabContour;

  /// Tooltip for cleaning slab contour
  ///
  /// In en, this message translates to:
  /// **'Remove redundant collinear points and repair artifacts'**
  String get cleanSlabContourTooltip;

  /// Message after cleaning slab contour
  ///
  /// In en, this message translates to:
  /// **'Slab contour cleaned ({count} redundant points removed)'**
  String slabContourCleaned(int count);

  /// Message when slab contour has no redundant vertices
  ///
  /// In en, this message translates to:
  /// **'Slab contour is already clean and optimal'**
  String get slabContourAlreadyClean;

  /// No description provided for @openingNoSlab.
  ///
  /// In en, this message translates to:
  /// **'Create the ceiling slab first.'**
  String get openingNoSlab;

  /// No description provided for @openingInvalidPlacement.
  ///
  /// In en, this message translates to:
  /// **'The entire opening must lie inside one slab without touching its outline or another opening.'**
  String get openingInvalidPlacement;

  /// No description provided for @openingAmbiguousOwner.
  ///
  /// In en, this message translates to:
  /// **'More than one slab contains this opening. Resolve the slab overlap.'**
  String get openingAmbiguousOwner;

  /// No description provided for @openingMissing.
  ///
  /// In en, this message translates to:
  /// **'The selected opening no longer exists.'**
  String get openingMissing;

  /// No description provided for @schemeReadinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Check before generation'**
  String get schemeReadinessTitle;

  /// No description provided for @schemeGeometryReady.
  ///
  /// In en, this message translates to:
  /// **'Slabs and staircase are geometrically ready.'**
  String get schemeGeometryReady;

  /// No description provided for @schemeReadinessHint.
  ///
  /// In en, this message translates to:
  /// **'This checks the input objects. It does not generate columns or shear walls and is not a structural assessment.'**
  String get schemeReadinessHint;

  /// No description provided for @schemeEditing.
  ///
  /// In en, this message translates to:
  /// **'Finish the current slab edit.'**
  String get schemeEditing;

  /// No description provided for @schemeMissingStairs.
  ///
  /// In en, this message translates to:
  /// **'Place a Staircase opening in the ceiling slab. An elevator is optional.'**
  String get schemeMissingStairs;

  /// No description provided for @schemeAmbiguousLevels.
  ///
  /// In en, this message translates to:
  /// **'The storey or slab ownership is ambiguous. Check duplicate elevations and identifiers.'**
  String get schemeAmbiguousLevels;

  /// No description provided for @schemeInvalidLevel.
  ///
  /// In en, this message translates to:
  /// **'Check the ceiling elevation and thickness: its soffit must be above the working storey base.'**
  String get schemeInvalidLevel;

  /// No description provided for @schemeInvalidGeometry.
  ///
  /// In en, this message translates to:
  /// **'A slab or opening is invalid. Check self-intersections, boundaries and overlapping openings.'**
  String get schemeInvalidGeometry;

  /// No description provided for @schemeOverlappingSlabs.
  ///
  /// In en, this message translates to:
  /// **'Slabs overlap. Correct their outlines before generation.'**
  String get schemeOverlappingSlabs;

  /// No description provided for @schemeComputationLimit.
  ///
  /// In en, this message translates to:
  /// **'These outlines exceed the check\'s complexity limit. Simplify them.'**
  String get schemeComputationLimit;

  /// No description provided for @schemeCeilingLabel.
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get schemeCeilingLabel;

  /// No description provided for @schemeRegionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Separate regions'**
  String get schemeRegionsLabel;

  /// No description provided for @schemeGenerate.
  ///
  /// In en, this message translates to:
  /// **'Suggest columns and shear walls'**
  String get schemeGenerate;

  /// No description provided for @schemePreview.
  ///
  /// In en, this message translates to:
  /// **'Initial structural layout'**
  String get schemePreview;

  /// No description provided for @schemeVariantCore.
  ///
  /// In en, this message translates to:
  /// **'Variant 1 · near the staircase'**
  String get schemeVariantCore;

  /// No description provided for @schemeVariantLong.
  ///
  /// In en, this message translates to:
  /// **'Variant 2 · along long walls'**
  String get schemeVariantLong;

  /// No description provided for @schemeMinSpacing.
  ///
  /// In en, this message translates to:
  /// **'Minimum column spacing (m)'**
  String get schemeMinSpacing;

  /// No description provided for @schemeTargetSpacing.
  ///
  /// In en, this message translates to:
  /// **'Target spacing (m)'**
  String get schemeTargetSpacing;

  /// No description provided for @schemeRebuild.
  ///
  /// In en, this message translates to:
  /// **'Next variant'**
  String get schemeRebuild;

  /// No description provided for @schemeConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm the displayed slab outlines and openings'**
  String get schemeConfirm;

  /// No description provided for @schemeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept proposal'**
  String get schemeAccept;

  /// No description provided for @schemeNoWalls.
  ///
  /// In en, this message translates to:
  /// **'No solid wall runs detected. Grid axes alone do not authorize columns inside rooms.'**
  String get schemeNoWalls;

  /// No description provided for @schemeNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'No suitable free positions. Existing elements are preserved.'**
  String get schemeNoCandidates;

  /// No description provided for @schemeLimits.
  ///
  /// In en, this message translates to:
  /// **'The preliminary layout limit was reached. Review the remaining areas manually.'**
  String get schemeLimits;

  /// No description provided for @schemePreliminary.
  ///
  /// In en, this message translates to:
  /// **'Automatic sizes use available wall space and preliminary axial/punching checks. Selected sections are starting sizes when adaptation is enabled. Confirm dimensions, load paths and reinforcement with a structural model.'**
  String get schemePreliminary;

  /// No description provided for @schemeLegend.
  ///
  /// In en, this message translates to:
  /// **'Grey: existing · Blue: slabs · Green: new columns · Orange: new walls · Red: openings'**
  String get schemeLegend;

  /// No description provided for @schemeUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Regions without walls in both principal directions'**
  String get schemeUnresolved;

  /// No description provided for @schemeRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected candidates'**
  String get schemeRejected;

  /// No description provided for @schemeReport.
  ///
  /// In en, this message translates to:
  /// **'Detailed assessment'**
  String get schemeReport;

  /// No description provided for @schemeInvalidOptions.
  ///
  /// In en, this message translates to:
  /// **'Enter positive sizes and spacing. Target spacing must be at least the minimum; maximum wall length must be at least the starting length.'**
  String get schemeInvalidOptions;

  /// No description provided for @schemeStale.
  ///
  /// In en, this message translates to:
  /// **'The project changed. Open a new preview before accepting.'**
  String get schemeStale;

  /// No description provided for @schemeComparison.
  ///
  /// In en, this message translates to:
  /// **'Before → after'**
  String get schemeComparison;

  /// No description provided for @schemeFresh.
  ///
  /// In en, this message translates to:
  /// **'Only new objects are accepted. Manual elements and accepted edits are preserved.'**
  String get schemeFresh;

  /// Option to enforce pairing shear walls in both orthogonal directions
  ///
  /// In en, this message translates to:
  /// **'Prefer distributed walls in both directions'**
  String get schemePairedWalls;

  /// Option to generate complete corner and intermediate columns
  ///
  /// In en, this message translates to:
  /// **'Additional support density (optional)'**
  String get schemeGenerousDensity;

  /// Menu item to toggle ground foundation visibility on level 0.00
  ///
  /// In en, this message translates to:
  /// **'Show foundations (±0.00)'**
  String get toggleGroundFoundations;

  /// No description provided for @schemeVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get schemeVariant;

  /// No description provided for @schemeNoAlternative.
  ///
  /// In en, this message translates to:
  /// **'No distinct alternative found in this search. Change spacing or try again.'**
  String get schemeNoAlternative;

  /// No description provided for @schemeCoverage.
  ///
  /// In en, this message translates to:
  /// **'Red samples: distance exceeds half the target spacing / greatest support distance'**
  String get schemeCoverage;

  /// No description provided for @schemeEurocodeScope.
  ///
  /// In en, this message translates to:
  /// **'Preliminary geometric screening. Support distance is not a calculated span or deflection. EC2 verification requires a structural model, loads, materials and reinforcement; the EC8 report contains preliminary indicators only.'**
  String get schemeEurocodeScope;

  /// No description provided for @schemeSpanUnknown.
  ///
  /// In en, this message translates to:
  /// **'Support span is undetermined'**
  String get schemeSpanUnknown;

  /// No description provided for @schemeSupportSpan.
  ///
  /// In en, this message translates to:
  /// **'Critical support spacing (preliminary)'**
  String get schemeSupportSpan;

  /// No description provided for @schemeOpeningFallback.
  ///
  /// In en, this message translates to:
  /// **'Purple: fallback columns in door/window openings — review opening'**
  String get schemeOpeningFallback;

  /// No description provided for @schemeAdaptiveSizes.
  ///
  /// In en, this message translates to:
  /// **'Adapt sections to walls and preliminary checks'**
  String get schemeAdaptiveSizes;

  /// No description provided for @schemeWallDensity.
  ///
  /// In en, this message translates to:
  /// **'Connected wall area / net floor area (1% reference)'**
  String get schemeWallDensity;

  /// No description provided for @schemeWallDeficit.
  ///
  /// In en, this message translates to:
  /// **'Remaining wall area deficit — placement constraints'**
  String get schemeWallDeficit;

  /// No description provided for @schemeResizedColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns with adapted sections'**
  String get schemeResizedColumns;

  /// No description provided for @schemeSizingReview.
  ///
  /// In en, this message translates to:
  /// **'Column sections need review: load or punching check remains above the preliminary target'**
  String get schemeSizingReview;

  /// No description provided for @schemePlacementReasons.
  ///
  /// In en, this message translates to:
  /// **'Rejected positions'**
  String get schemePlacementReasons;

  /// No description provided for @schemeWallConstraint.
  ///
  /// In en, this message translates to:
  /// **'wall fit'**
  String get schemeWallConstraint;

  /// No description provided for @schemeSlabConstraint.
  ///
  /// In en, this message translates to:
  /// **'slab / hole'**
  String get schemeSlabConstraint;

  /// No description provided for @schemeSpacingConstraint.
  ///
  /// In en, this message translates to:
  /// **'spacing / collision'**
  String get schemeSpacingConstraint;

  /// No description provided for @schemeMaxWallLength.
  ///
  /// In en, this message translates to:
  /// **'Max new wall length (m)'**
  String get schemeMaxWallLength;

  /// No description provided for @schemeWallSections.
  ///
  /// In en, this message translates to:
  /// **'Walls — thickness × length'**
  String get schemeWallSections;

  /// No description provided for @schemeContinueLower.
  ///
  /// In en, this message translates to:
  /// **'Continue the scheme from level {level}, preserving positions and sections. Unresolved spans and wall deficits require revision of the lower scheme.'**
  String schemeContinueLower(String level);

  /// No description provided for @schemeContinuityReview.
  ///
  /// In en, this message translates to:
  /// **'Some manual supports do not match the lower scheme. Review vertical continuity.'**
  String get schemeContinuityReview;

  /// No description provided for @schemeBlockedContinuations.
  ///
  /// In en, this message translates to:
  /// **'Supports that cannot be continued: {count}. Red points mark positions requiring review.'**
  String schemeBlockedContinuations(int count);

  /// No description provided for @spanFeedbackCount.
  ///
  /// In en, this message translates to:
  /// **'Spacing problems: {count}'**
  String spanFeedbackCount(int count);

  /// No description provided for @spanFeedbackScope.
  ///
  /// In en, this message translates to:
  /// **'Preliminary · assigned slab thickness'**
  String get spanFeedbackScope;

  /// No description provided for @spanFeedbackUnknown.
  ///
  /// In en, this message translates to:
  /// **'Links without valid slab thickness: {count}'**
  String spanFeedbackUnknown(int count);

  /// No description provided for @bimClearStructure.
  ///
  /// In en, this message translates to:
  /// **'Clear structure — all storeys'**
  String get bimClearStructure;

  /// No description provided for @bimClearStructureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} columns and shear walls across all storeys. Slabs, beams and axes remain. You can undo this action.'**
  String bimClearStructureConfirm(int count);

  /// No description provided for @bimDeleteStoreyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete storey {level} and its structural elements?'**
  String bimDeleteStoreyConfirm(String level);

  /// No description provided for @bimUnderlayReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'Underlay data changed at {levels}. Review the preserved structural elements and openings.'**
  String bimUnderlayReviewNeeded(String levels);

  /// No description provided for @bimFloorSlabReference.
  ///
  /// In en, this message translates to:
  /// **'Floor slab at {level} — ceiling of storey {owner}'**
  String bimFloorSlabReference(String level, String owner);

  /// No description provided for @bimEditFloorSlab.
  ///
  /// In en, this message translates to:
  /// **'Edit floor slab'**
  String get bimEditFloorSlab;

  /// No description provided for @schemeSearchSummary.
  ///
  /// In en, this message translates to:
  /// **'Compared layouts: {layouts} · accepted changes: {changes} · evaluations: {evaluations}'**
  String schemeSearchSummary(int layouts, int changes, int evaluations);

  /// No description provided for @schemeFieldSummary.
  ///
  /// In en, this message translates to:
  /// **'Closed fields: {count} · for review: {review}'**
  String schemeFieldSummary(int count, int review);

  /// No description provided for @schemeUnresolvedFieldArea.
  ///
  /// In en, this message translates to:
  /// **'Area with undetermined field support'**
  String get schemeUnresolvedFieldArea;

  /// No description provided for @schemeOpeningSupportReview.
  ///
  /// In en, this message translates to:
  /// **'Support around openings: points for review'**
  String get schemeOpeningSupportReview;

  /// No description provided for @schemeBoundarySupportReview.
  ///
  /// In en, this message translates to:
  /// **'Cantilever or undetermined edge support'**
  String get schemeBoundarySupportReview;

  /// No description provided for @schemeContinuityIssues.
  ///
  /// In en, this message translates to:
  /// **'Vertical continuity issues'**
  String get schemeContinuityIssues;

  /// No description provided for @schemeConcreteVolume.
  ///
  /// In en, this message translates to:
  /// **'Support concrete volume'**
  String get schemeConcreteVolume;

  /// No description provided for @schemeBalanceIndex.
  ///
  /// In en, this message translates to:
  /// **'Preliminary torsion index (lower is better)'**
  String get schemeBalanceIndex;

  /// No description provided for @schemeNoWallConstraint.
  ///
  /// In en, this message translates to:
  /// **'No suitable wall'**
  String get schemeNoWallConstraint;

  /// No description provided for @schemeCollisionConstraint.
  ///
  /// In en, this message translates to:
  /// **'Section collision'**
  String get schemeCollisionConstraint;

  /// No description provided for @schemeColumnSpacingConstraint.
  ///
  /// In en, this message translates to:
  /// **'Column spacing'**
  String get schemeColumnSpacingConstraint;

  /// No description provided for @schemeWallSpacingConstraint.
  ///
  /// In en, this message translates to:
  /// **'Wall spacing'**
  String get schemeWallSpacingConstraint;

  /// No description provided for @schemeBudgetConstraint.
  ///
  /// In en, this message translates to:
  /// **'Placement budget'**
  String get schemeBudgetConstraint;

  /// No description provided for @schemeLimitInput.
  ///
  /// In en, this message translates to:
  /// **'Input size limit'**
  String get schemeLimitInput;

  /// No description provided for @schemeLimitSampling.
  ///
  /// In en, this message translates to:
  /// **'Sampling limit'**
  String get schemeLimitSampling;

  /// No description provided for @schemeLimitJunctions.
  ///
  /// In en, this message translates to:
  /// **'Wall junction limit'**
  String get schemeLimitJunctions;

  /// No description provided for @schemeLimitElements.
  ///
  /// In en, this message translates to:
  /// **'Support count limit'**
  String get schemeLimitElements;

  /// No description provided for @schemeLimitFields.
  ///
  /// In en, this message translates to:
  /// **'Field topology limit'**
  String get schemeLimitFields;

  /// No description provided for @schemeLimitOptimization.
  ///
  /// In en, this message translates to:
  /// **'Local search budget reached; optimality is not established'**
  String get schemeLimitOptimization;

  /// No description provided for @schemeStageCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get schemeStageCore;

  /// No description provided for @schemeStageWalls.
  ///
  /// In en, this message translates to:
  /// **'Distributed walls'**
  String get schemeStageWalls;

  /// No description provided for @schemeStageColumns.
  ///
  /// In en, this message translates to:
  /// **'Column nodes'**
  String get schemeStageColumns;

  /// No description provided for @schemeStageCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get schemeStageCoverage;

  /// No description provided for @schemeStageRepair.
  ///
  /// In en, this message translates to:
  /// **'Span repair'**
  String get schemeStageRepair;

  /// No description provided for @schemeStageOpenings.
  ///
  /// In en, this message translates to:
  /// **'Architectural opening review'**
  String get schemeStageOpenings;

  /// No description provided for @schemePunchingGeometryReview.
  ///
  /// In en, this message translates to:
  /// **'Punching support geometry or beam load transfer needs review'**
  String get schemePunchingGeometryReview;

  /// No description provided for @schemeInteriorColumn.
  ///
  /// In en, this message translates to:
  /// **'Interior column'**
  String get schemeInteriorColumn;

  /// No description provided for @schemeEdgeColumn.
  ///
  /// In en, this message translates to:
  /// **'Edge column'**
  String get schemeEdgeColumn;

  /// No description provided for @schemeCornerColumn.
  ///
  /// In en, this message translates to:
  /// **'Corner column'**
  String get schemeCornerColumn;

  /// No description provided for @schemeUnknownColumnPosition.
  ///
  /// In en, this message translates to:
  /// **'Undetermined column position'**
  String get schemeUnknownColumnPosition;

  /// No description provided for @schemeSearchNoImprovement.
  ///
  /// In en, this message translates to:
  /// **'The search retained the best assessed seed'**
  String get schemeSearchNoImprovement;

  /// No description provided for @schemeMinWallSpacing.
  ///
  /// In en, this message translates to:
  /// **'Minimum parallel wall spacing (m)'**
  String get schemeMinWallSpacing;

  /// No description provided for @schemeUnavailableChecks.
  ///
  /// In en, this message translates to:
  /// **'Undetermined checks'**
  String get schemeUnavailableChecks;

  /// No description provided for @schemeSeedDensityConstraint.
  ///
  /// In en, this message translates to:
  /// **'Skipped in the sparse seed'**
  String get schemeSeedDensityConstraint;

  /// No description provided for @floorSlabTitle.
  ///
  /// In en, this message translates to:
  /// **'Floor slab at this level'**
  String get floorSlabTitle;

  /// No description provided for @floorSlabContext.
  ///
  /// In en, this message translates to:
  /// **'Floor of level {level} · edit on its own plan'**
  String floorSlabContext(String level);

  /// No description provided for @floorSlabLevelHint.
  ///
  /// In en, this message translates to:
  /// **'The slab belongs to this level and is shown as the ceiling on the immediately lower level.'**
  String get floorSlabLevelHint;

  /// No description provided for @bimCeilingSlabReference.
  ///
  /// In en, this message translates to:
  /// **'Ceiling slab · floor of level {owner}'**
  String bimCeilingSlabReference(String owner);

  /// No description provided for @gridAxisSourceLevels.
  ///
  /// In en, this message translates to:
  /// **'Levels: {levels}'**
  String gridAxisSourceLevels(String levels);

  /// No description provided for @staircaseSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Staircases across levels'**
  String get staircaseSetupTitle;

  /// No description provided for @staircaseSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Set the start and final arrival level of each staircase. Outline circulation space on every level and the actual opening on arrival floors. The starting floor and the roof may remain solid.'**
  String get staircaseSetupHint;

  /// No description provided for @staircaseNoStairs.
  ///
  /// In en, this message translates to:
  /// **'This building has no staircases'**
  String get staircaseNoStairs;

  /// No description provided for @staircaseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add staircase'**
  String get staircaseAdd;

  /// No description provided for @staircaseStart.
  ///
  /// In en, this message translates to:
  /// **'Start level'**
  String get staircaseStart;

  /// No description provided for @staircaseEnd.
  ///
  /// In en, this message translates to:
  /// **'Final arrival level'**
  String get staircaseEnd;

  /// No description provided for @staircaseZone.
  ///
  /// In en, this message translates to:
  /// **'Circulation zone'**
  String get staircaseZone;

  /// No description provided for @staircaseZoneHint.
  ///
  /// In en, this message translates to:
  /// **'Outline flights, landings and passage space. This polygon reserves space for stairs and does not cut the slab. Close the polygon to save.'**
  String get staircaseZoneHint;

  /// No description provided for @staircaseDrawZone.
  ///
  /// In en, this message translates to:
  /// **'Outline zone'**
  String get staircaseDrawZone;

  /// No description provided for @staircaseDrawOpening.
  ///
  /// In en, this message translates to:
  /// **'Outline floor opening'**
  String get staircaseDrawOpening;

  /// No description provided for @staircaseDetect.
  ///
  /// In en, this message translates to:
  /// **'Find stair geometry'**
  String get staircaseDetect;

  /// No description provided for @staircaseReviewMissing.
  ///
  /// In en, this message translates to:
  /// **'Review staircase levels before generating supports.'**
  String get staircaseReviewMissing;

  /// No description provided for @staircaseScopeMissing.
  ///
  /// In en, this message translates to:
  /// **'Check the start and final arrival levels.'**
  String get staircaseScopeMissing;

  /// No description provided for @staircaseZoneMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid circulation zone'**
  String get staircaseZoneMissing;

  /// No description provided for @staircaseOpeningMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing matching staircase opening in the arrival floor'**
  String get staircaseOpeningMissing;

  /// No description provided for @staircaseOpeningReady.
  ///
  /// In en, this message translates to:
  /// **'Floor opening found'**
  String get staircaseOpeningReady;

  /// No description provided for @staircaseZoneReady.
  ///
  /// In en, this message translates to:
  /// **'Zone outlined'**
  String get staircaseZoneReady;

  /// No description provided for @staircaseDetectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stair geometry proposals'**
  String get staircaseDetectionTitle;

  /// No description provided for @staircaseDetectionHint.
  ///
  /// In en, this message translates to:
  /// **'Repeated strokes suggest flights, but do not establish the exact slab opening. Review the geometry and outline the opening on its arrival floor.'**
  String get staircaseDetectionHint;

  /// No description provided for @staircaseDetectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reliable repeated tread pattern found. Outline the zone manually or inspect the floor below.'**
  String get staircaseDetectionEmpty;

  /// No description provided for @staircaseUseZone.
  ///
  /// In en, this message translates to:
  /// **'Use as circulation zone'**
  String get staircaseUseZone;

  /// No description provided for @staircaseDetectionPartial.
  ///
  /// In en, this message translates to:
  /// **'Flight candidate; landing and passage space need review'**
  String get staircaseDetectionPartial;

  /// No description provided for @staircaseLimit.
  ///
  /// In en, this message translates to:
  /// **'Drawing is too large for a complete geometry search. Use manual outlining.'**
  String get staircaseLimit;

  /// No description provided for @staircaseInvalidZone.
  ///
  /// In en, this message translates to:
  /// **'The circulation polygon is invalid. Correct its points.'**
  String get staircaseInvalidZone;

  /// No description provided for @staircaseWinder.
  ///
  /// In en, this message translates to:
  /// **'Winder flight'**
  String get staircaseWinder;

  /// No description provided for @staircaseEvidenceFromLevel.
  ///
  /// In en, this message translates to:
  /// **'Flight evidence from {level}; review against this floor.'**
  String staircaseEvidenceFromLevel(String level);

  /// No description provided for @staircaseSupportConflict.
  ///
  /// In en, this message translates to:
  /// **'Existing supports overlap the staircase zone. Reposition them or correct the zone.'**
  String get staircaseSupportConflict;

  /// No description provided for @staircaseCloseZone.
  ///
  /// In en, this message translates to:
  /// **'Save zone ({count} points)'**
  String staircaseCloseZone(int count);

  /// No description provided for @staircaseUseOpening.
  ///
  /// In en, this message translates to:
  /// **'Review opening contour'**
  String get staircaseUseOpening;

  /// No description provided for @staircaseArms.
  ///
  /// In en, this message translates to:
  /// **'{count} flights'**
  String staircaseArms(int count);

  /// Title for standalone Architect Studio module
  ///
  /// In en, this message translates to:
  /// **'Architect Studio'**
  String get architectStudio;

  /// Subtitle for Architect Studio hero card
  ///
  /// In en, this message translates to:
  /// **'3D Conceptual design, walls, doors & storeys'**
  String get architectStudioSubtitle;

  /// Button to create new architectural project
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get architectNewProject;

  /// Label for project name field
  ///
  /// In en, this message translates to:
  /// **'Project Name'**
  String get architectProjectName;

  /// Hint for project name field
  ///
  /// In en, this message translates to:
  /// **'e.g. Modern Villa Alpha'**
  String get architectProjectNameHint;

  /// Label for units selector
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get architectUnits;

  /// Meters unit
  ///
  /// In en, this message translates to:
  /// **'Meters (m)'**
  String get architectUnitMeters;

  /// Centimeters unit
  ///
  /// In en, this message translates to:
  /// **'Centimeters (cm)'**
  String get architectUnitCm;

  /// Storeys section title
  ///
  /// In en, this message translates to:
  /// **'Storeys'**
  String get architectStoreys;

  /// Number of storeys field label
  ///
  /// In en, this message translates to:
  /// **'Number of Storeys'**
  String get architectStoreyCount;

  /// Floor height field label
  ///
  /// In en, this message translates to:
  /// **'Typical Floor Height (m)'**
  String get architectStoreyHeight;

  /// Ground floor height field label
  ///
  /// In en, this message translates to:
  /// **'Ground Floor Height (m)'**
  String get architectGroundHeight;

  /// Title for grid axes option
  ///
  /// In en, this message translates to:
  /// **'Dynamic Grid Axes'**
  String get architectDynamicGridAxes;

  /// Count of grid axes on X
  ///
  /// In en, this message translates to:
  /// **'Axes on X'**
  String get architectGridAxesX;

  /// Count of grid axes on Y
  ///
  /// In en, this message translates to:
  /// **'Axes on Y'**
  String get architectGridAxesY;

  /// Spacing between X axes
  ///
  /// In en, this message translates to:
  /// **'Spacing X (m)'**
  String get architectGridSpacingX;

  /// Spacing between Y axes
  ///
  /// In en, this message translates to:
  /// **'Spacing Y (m)'**
  String get architectGridSpacingY;

  /// Architectural tool category
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get architectCategoryPlan;

  /// Architectural tool category
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get architectCategoryBuild;

  /// Architectural tool category
  ///
  /// In en, this message translates to:
  /// **'2D drawing'**
  String get architectCategoryDrawing;

  /// Tooltip for architectural tool category picker
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get architectToolCategories;

  /// Explicit single-element selection tool
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get architectToolSelect;

  /// Wall tool
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get architectToolWall;

  /// Door tool
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get architectToolDoor;

  /// Measure tool
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get architectToolMeasure;

  /// Wall thickness label
  ///
  /// In en, this message translates to:
  /// **'Thk.'**
  String get architectWallThickness;

  /// Single wall mode
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get architectWallSingle;

  /// Chained wall mode
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get architectWallChained;

  /// Button to finish chained wall
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get architectFinishChained;

  /// Door width label
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectDoorWidth;

  /// Door height label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectDoorHeight;

  /// Door sill height label
  ///
  /// In en, this message translates to:
  /// **'Sill (hp)'**
  String get architectDoorSill;

  /// Left hinge side
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get architectDoorHingeLeft;

  /// Right hinge side
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get architectDoorHingeRight;

  /// Inward swing direction
  ///
  /// In en, this message translates to:
  /// **'Swing Inward'**
  String get architectDoorSwingIn;

  /// Outward swing direction
  ///
  /// In en, this message translates to:
  /// **'Swing Outward'**
  String get architectDoorSwingOut;

  /// Guidance prompt when door tool is active
  ///
  /// In en, this message translates to:
  /// **'Tap on a wall to place door'**
  String get architectDoorSelectWallPrompt;

  /// Door specification mark or ID label
  ///
  /// In en, this message translates to:
  /// **'Mark (ID)'**
  String get architectDoorSpecId;

  /// Door hinge side label
  ///
  /// In en, this message translates to:
  /// **'Hinge'**
  String get architectDoorHingeSide;

  /// Door swing direction label
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get architectDoorSwingDirection;

  /// Quick action to flip door swing direction
  ///
  /// In en, this message translates to:
  /// **'Flip swing (in/out)'**
  String get architectDoorFlipSwing;

  /// Quick action to flip door hinge side
  ///
  /// In en, this message translates to:
  /// **'Flip hinge (left/right)'**
  String get architectDoorFlipHinge;

  /// Guidance prompt when wall tool is active
  ///
  /// In en, this message translates to:
  /// **'Tap to start wall, tap again to place'**
  String get architectWallDrawPrompt;

  /// 2D floor plan view toggle
  ///
  /// In en, this message translates to:
  /// **'2D Plan'**
  String get architectView2D;

  /// 3D viewport toggle
  ///
  /// In en, this message translates to:
  /// **'3D Model'**
  String get architectView3D;

  /// Reset camera view action
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get architectResetView;

  /// Button to create architectural project
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get architectCreateProject;

  /// Functional zones tool
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get architectToolZone;

  /// Guidance prompt when zone tool is active
  ///
  /// In en, this message translates to:
  /// **'Drag to draw room zone'**
  String get architectZoneDragPrompt;

  /// Guidance prompt when drawing point-by-point zone
  ///
  /// In en, this message translates to:
  /// **'Points → close'**
  String get architectZoneDrawPrompt;

  /// Prompt when starting zone drafting
  ///
  /// In en, this message translates to:
  /// **'Tap canvas to place start point (1)'**
  String get architectZoneTapFirstPoint;

  /// Prompt during zone drafting
  ///
  /// In en, this message translates to:
  /// **'Point {count}: Tap for next point or select 1 to close'**
  String architectZoneNextPointPrompt(int count);

  /// Button to close and finalize zone polygon
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get architectZoneClose;

  /// Button to undo last placed vertex in zone drafting
  ///
  /// In en, this message translates to:
  /// **'Undo Point'**
  String get architectZoneUndoPoint;

  /// Button to cancel zone drafting
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get architectZoneCancelDraft;

  /// Snap badge when hovering start point
  ///
  /// In en, this message translates to:
  /// **'Close zone (1st point)'**
  String get architectZonePointSnapStart;

  /// Error when polygon self-intersects
  ///
  /// In en, this message translates to:
  /// **'Self-intersecting polygon boundary is not allowed'**
  String get architectZoneSelfIntersectError;

  /// Error when zone has less than 3 points
  ///
  /// In en, this message translates to:
  /// **'A zone requires at least 3 points'**
  String get architectZoneMinPointsError;

  /// Label indicating edge offset distance
  ///
  /// In en, this message translates to:
  /// **'Extruded edge: {dist} m'**
  String architectZoneExtrudeOffset(String dist);

  /// Notification when redundant/orphan vertices are eliminated
  ///
  /// In en, this message translates to:
  /// **'Removed {count} redundant/orphan vertices'**
  String architectZoneCleaned(int count);

  /// Number of placed points
  ///
  /// In en, this message translates to:
  /// **'Points: {count}'**
  String architectZonePointsCount(int count);

  /// Horizontal alignment badge
  ///
  /// In en, this message translates to:
  /// **'Straightened 0°'**
  String get architectZoneAlignH;

  /// Vertical alignment badge
  ///
  /// In en, this message translates to:
  /// **'Straightened 90°'**
  String get architectZoneAlignV;

  /// Notification when a zone is created
  ///
  /// In en, this message translates to:
  /// **'Zone {name} ({area} m²) created'**
  String architectZoneCreated(String name, String area);

  /// Notification when a zone is deleted
  ///
  /// In en, this message translates to:
  /// **'Zone deleted'**
  String get architectZoneDeleted;

  /// Notification when zone vertices are merged
  ///
  /// In en, this message translates to:
  /// **'Corners merged'**
  String get architectZoneMerged;

  /// Title for zone properties sheet
  ///
  /// In en, this message translates to:
  /// **'Zone Properties'**
  String get architectZoneProperties;

  /// Room name label
  ///
  /// In en, this message translates to:
  /// **'Room Name'**
  String get architectZoneName;

  /// Room category preset selector
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get architectZoneCategory;

  /// Target area label
  ///
  /// In en, this message translates to:
  /// **'Target Area'**
  String get architectZoneTargetArea;

  /// Room area label
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get architectZoneAreaLabel;

  /// Room perimeter label
  ///
  /// In en, this message translates to:
  /// **'Perimeter'**
  String get architectZonePerimeterLabel;

  /// Button to delete selected zone
  ///
  /// In en, this message translates to:
  /// **'Delete Zone'**
  String get architectDeleteZone;

  /// Button to square corners to 90 degrees
  ///
  /// In en, this message translates to:
  /// **'Straighten Angles (90°)'**
  String get architectZoneAutoAlign;

  /// Button to undo angle straightening
  ///
  /// In en, this message translates to:
  /// **'Undo Straighten'**
  String get architectZoneUndoAlign;

  /// Snackbar when angles are straightened
  ///
  /// In en, this message translates to:
  /// **'Angles straightened to 90°'**
  String get architectZoneAutoAlignSuccess;

  /// Rotation label
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get architectZoneRotate;

  /// Button to enable moving whole zone
  ///
  /// In en, this message translates to:
  /// **'Move Zone'**
  String get architectZoneMove;

  /// Offset label
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get architectZoneOffset;

  /// Save zone button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get architectZoneSave;

  /// Cancel zone edit button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get architectZoneCancel;

  /// Title of zone edit mode
  ///
  /// In en, this message translates to:
  /// **'Zone Edit & Transform'**
  String get architectZoneEditMode;

  /// Undo transformation button
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get architectZoneUndoAction;

  /// Redo transformation button
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get architectZoneRedoAction;

  /// Notification when zone is moved
  ///
  /// In en, this message translates to:
  /// **'Moved: {dist} m'**
  String architectZoneMovedDistance(String dist);

  /// Quick rectangle mode button
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get architectZoneQuickRect;

  /// Freeform polyline drafting mode button
  ///
  /// In en, this message translates to:
  /// **'Freeform'**
  String get architectZoneQuickPoly;

  /// Room number label
  ///
  /// In en, this message translates to:
  /// **'Room No.'**
  String get architectZoneNumber;

  /// Compact room number prefix
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get architectZoneNumberPrompt;

  /// Room finishes section header
  ///
  /// In en, this message translates to:
  /// **'Room Finishes'**
  String get architectZoneFinishes;

  /// Floor finish label
  ///
  /// In en, this message translates to:
  /// **'Floor Finish'**
  String get architectZoneFloorFinish;

  /// Wall finish label
  ///
  /// In en, this message translates to:
  /// **'Wall Finish'**
  String get architectZoneWallFinish;

  /// Ceiling finish label
  ///
  /// In en, this message translates to:
  /// **'Ceiling Finish'**
  String get architectZoneCeilingFinish;

  /// Clear height label
  ///
  /// In en, this message translates to:
  /// **'Clear Height (m)'**
  String get architectZoneClearHeight;

  /// Automatic dynamic boundary mode label
  ///
  /// In en, this message translates to:
  /// **'Auto Boundaries'**
  String get architectZoneBoundaryAuto;

  /// Description of automatic dynamic boundary mode
  ///
  /// In en, this message translates to:
  /// **'Dynamically conforms when walls change'**
  String get architectZoneBoundaryAutoDesc;

  /// Manual boundary mode label
  ///
  /// In en, this message translates to:
  /// **'Manual Correction'**
  String get architectZoneBoundaryManual;

  /// Description of manual boundary mode
  ///
  /// In en, this message translates to:
  /// **'Fixed boundaries without dynamic updates'**
  String get architectZoneBoundaryManualDesc;

  /// Auto 1-click zone placement mode
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get architectZoneModeAuto;

  /// Manual point-by-point zone placement mode
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get architectZoneModeManual;

  /// Prompt for auto-detecting room boundary
  ///
  /// In en, this message translates to:
  /// **'Tap inside an enclosed room to auto-detect boundary'**
  String get architectZoneAutoPrompt;

  /// Error when room is not enclosed
  ///
  /// In en, this message translates to:
  /// **'Room is not fully enclosed by walls'**
  String get architectZoneAutoFailed;

  /// Title of merge rooms confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Merge Rooms'**
  String get architectZoneMergeDialogTitle;

  /// Confirmation message when a separating wall is removed
  ///
  /// In en, this message translates to:
  /// **'The separating wall between \"{zoneA}\" and \"{zoneB}\" was removed. Would you like to merge them into a single room?'**
  String architectZoneMergeDialogMessage(String zoneA, String zoneB);

  /// Confirm button to merge rooms
  ///
  /// In en, this message translates to:
  /// **'Merge Rooms'**
  String get architectZoneMergeConfirm;

  /// Button to keep rooms separate
  ///
  /// In en, this message translates to:
  /// **'Keep Separate'**
  String get architectZoneMergeKeepSeparate;

  /// Snackbar when rooms are merged
  ///
  /// In en, this message translates to:
  /// **'Rooms merged into {name}'**
  String architectZoneMergedSuccess(String name);

  /// Room finish schedule title
  ///
  /// In en, this message translates to:
  /// **'Room Schedule'**
  String get architectZoneScheduleTitle;

  /// Total area label in schedule
  ///
  /// In en, this message translates to:
  /// **'Total Net Area'**
  String get architectZoneScheduleTotalArea;

  /// Room count in schedule
  ///
  /// In en, this message translates to:
  /// **'Rooms Count'**
  String get architectZoneScheduleRoomCount;

  /// Button to place schedule table on drawing
  ///
  /// In en, this message translates to:
  /// **'Place on Drawing'**
  String get architectZoneSchedulePlaceOnDrawing;

  /// Button to remove schedule table from drawing
  ///
  /// In en, this message translates to:
  /// **'Remove from Drawing'**
  String get architectZoneScheduleRemoveFromDrawing;

  /// Snackbar when table placed
  ///
  /// In en, this message translates to:
  /// **'Schedule table placed on drawing'**
  String get architectZoneScheduleTablePlaced;

  /// Copy schedule table button
  ///
  /// In en, this message translates to:
  /// **'Copy Schedule'**
  String get architectZoneScheduleCopy;

  /// Snackbar when schedule copied
  ///
  /// In en, this message translates to:
  /// **'Room schedule copied to clipboard'**
  String get architectZoneScheduleCopied;

  /// Message when no zones exist
  ///
  /// In en, this message translates to:
  /// **'No zones created in active storey'**
  String get architectZoneScheduleNoRooms;

  /// Schedule column number
  ///
  /// In en, this message translates to:
  /// **'№'**
  String get architectZoneScheduleColNo;

  /// Schedule column name
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get architectZoneScheduleColName;

  /// Schedule column area
  ///
  /// In en, this message translates to:
  /// **'Area (m²)'**
  String get architectZoneScheduleColArea;

  /// Schedule column perimeter
  ///
  /// In en, this message translates to:
  /// **'Perim. (m)'**
  String get architectZoneScheduleColPerimeter;

  /// Schedule column floor finish
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get architectZoneScheduleColFloor;

  /// Schedule column walls finish
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get architectZoneScheduleColWalls;

  /// Schedule column ceiling finish
  ///
  /// In en, this message translates to:
  /// **'Ceiling'**
  String get architectZoneScheduleColCeiling;

  /// Schedule column clear height
  ///
  /// In en, this message translates to:
  /// **'H (m)'**
  String get architectZoneScheduleColHeight;

  /// Zone table placement tool
  ///
  /// In en, this message translates to:
  /// **'Zone Table'**
  String get architectToolZoneTable;

  /// Tooltip for zone table placement tool
  ///
  /// In en, this message translates to:
  /// **'Place room schedule table on canvas'**
  String get architectToolZoneTableTooltip;

  /// Title of zone table HUD bar
  ///
  /// In en, this message translates to:
  /// **'Room Schedule Table'**
  String get architectZoneTableBarTitle;

  /// Hint to place table on canvas
  ///
  /// In en, this message translates to:
  /// **'Click on the drawing to place the table'**
  String get architectZoneTableBarHint;

  /// Hint to reposition placed table
  ///
  /// In en, this message translates to:
  /// **'Drag table on canvas to reposition'**
  String get architectZoneTableBarMoveHint;

  /// Notification when table is placed
  ///
  /// In en, this message translates to:
  /// **'Table placed on drawing'**
  String get architectZoneTablePlaced;

  /// Notification when table is removed
  ///
  /// In en, this message translates to:
  /// **'Table removed from drawing'**
  String get architectZoneTableRemoved;

  /// Button to remove table from drawing
  ///
  /// In en, this message translates to:
  /// **'Remove Table'**
  String get architectZoneTableRemove;

  /// Button to return to room zones tool
  ///
  /// In en, this message translates to:
  /// **'Back to Rooms'**
  String get architectZoneTableBackToZones;

  /// Action to place room schedule table
  ///
  /// In en, this message translates to:
  /// **'Place Table'**
  String get architectZoneTableActionPlace;

  /// Tooltip to confirm room schedule table placement
  ///
  /// In en, this message translates to:
  /// **'Confirm placement'**
  String get architectZoneTableConfirmPlacement;

  /// Tooltip to cancel room schedule table placement
  ///
  /// In en, this message translates to:
  /// **'Cancel placement'**
  String get architectZoneTableCancelPlacement;

  /// Hint shown while room schedule table placement is pending
  ///
  /// In en, this message translates to:
  /// **'Tap to reposition, or confirm placement with the checkmark'**
  String get architectZoneTablePendingHint;

  /// Title for room zone context menu
  ///
  /// In en, this message translates to:
  /// **'Room Options'**
  String get architectZoneContextMenu;

  /// Menu action to edit room zone contour
  ///
  /// In en, this message translates to:
  /// **'Edit Contour'**
  String get architectZoneEditContour;

  /// Title for predefined room types dialog
  ///
  /// In en, this message translates to:
  /// **'Room presets'**
  String get architectZonePresetsDialogTitle;

  /// Subtitle for predefined room types dialog
  ///
  /// In en, this message translates to:
  /// **'Default name and finishes for each room category'**
  String get architectZonePresetsDialogSubtitle;

  /// Button to reset current category to built-in defaults
  ///
  /// In en, this message translates to:
  /// **'Reset Category Defaults'**
  String get architectZonePresetsResetCategory;

  /// Button to reset all room categories to built-in defaults
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get architectZonePresetsResetAll;

  /// Snackbar message when room type presets are saved
  ///
  /// In en, this message translates to:
  /// **'Room type presets saved'**
  String get architectZonePresetsSaved;

  /// Tooltip for predefine room types action
  ///
  /// In en, this message translates to:
  /// **'Predefine room types and default finishes'**
  String get architectZonePresetsTooltip;

  /// Laminate floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Laminate'**
  String get architectZoneFloorLaminate;

  /// Granite tiles floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Porcelain tile'**
  String get architectZoneFloorGranite;

  /// Terracotta tiles floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Terracotta'**
  String get architectZoneFloorTerracotta;

  /// Parquet floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Parquet'**
  String get architectZoneFloorParquet;

  /// Carpet floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Carpet'**
  String get architectZoneFloorCarpet;

  /// Polished concrete floor finish preset
  ///
  /// In en, this message translates to:
  /// **'Polished Concrete'**
  String get architectZoneFloorConcrete;

  /// Latex wall finish preset
  ///
  /// In en, this message translates to:
  /// **'Latex paint'**
  String get architectZoneWallLatex;

  /// Faience wall finish preset
  ///
  /// In en, this message translates to:
  /// **'Faience'**
  String get architectZoneWallFaience;

  /// Decorative plaster wall finish preset
  ///
  /// In en, this message translates to:
  /// **'Dec. plaster'**
  String get architectZoneWallPlaster;

  /// Wallpaper wall finish preset
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get architectZoneWallWallpaper;

  /// Exposed brick wall finish preset
  ///
  /// In en, this message translates to:
  /// **'Exposed Brick'**
  String get architectZoneWallExposedBrick;

  /// Latex ceiling finish preset
  ///
  /// In en, this message translates to:
  /// **'Latex paint'**
  String get architectZoneCeilingLatex;

  /// Gypsum board ceiling finish preset
  ///
  /// In en, this message translates to:
  /// **'Gypsum Board'**
  String get architectZoneCeilingGypsum;

  /// Suspended ceiling finish preset
  ///
  /// In en, this message translates to:
  /// **'Suspended Ceiling'**
  String get architectZoneCeilingSuspended;

  /// Exposed concrete ceiling finish preset
  ///
  /// In en, this message translates to:
  /// **'Exposed Concrete'**
  String get architectZoneCeilingConcrete;

  /// No description provided for @staircaseAutoGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate stair openings'**
  String get staircaseAutoGenerate;

  /// No description provided for @staircaseAutoAdded.
  ///
  /// In en, this message translates to:
  /// **'Stair openings added: {count}'**
  String staircaseAutoAdded(int count);

  /// No description provided for @staircaseAutoExisting.
  ///
  /// In en, this message translates to:
  /// **'The stair openings are already placed.'**
  String get staircaseAutoExisting;

  /// No description provided for @staircaseAutoNotFound.
  ///
  /// In en, this message translates to:
  /// **'No opening was found. Draw it with the Staircase tool.'**
  String get staircaseAutoNotFound;

  /// No description provided for @staircaseAutoMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing stair opening at {levels}.'**
  String staircaseAutoMissing(String levels);

  /// No description provided for @bimToolGroupUnderlay.
  ///
  /// In en, this message translates to:
  /// **'Underlay'**
  String get bimToolGroupUnderlay;

  /// No description provided for @bimToolGroupStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get bimToolGroupStructure;

  /// No description provided for @bimToolGroupChecks.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get bimToolGroupChecks;

  /// No description provided for @bimGenerateSupportsAction.
  ///
  /// In en, this message translates to:
  /// **'Generate columns and walls'**
  String get bimGenerateSupportsAction;

  /// No description provided for @bimSupportSpacingAction.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get bimSupportSpacingAction;

  /// Architectural grid axes tool label
  ///
  /// In en, this message translates to:
  /// **'Axes'**
  String get architectToolAxis;

  /// Prompt when drafting an axis
  ///
  /// In en, this message translates to:
  /// **'Tap start and end points to draw an axis'**
  String get architectAxisDrawPrompt;

  /// Snackbar message when axes are renumbered
  ///
  /// In en, this message translates to:
  /// **'Axes resequenced successfully'**
  String get architectAxesResequenced;

  /// Snackbar message when all axes are aligned
  ///
  /// In en, this message translates to:
  /// **'Axes extents aligned'**
  String get architectAxesAligned;

  /// Snackbar message when an axis is aligned
  ///
  /// In en, this message translates to:
  /// **'Axis aligned with parallel axes'**
  String get architectAxisAligned;

  /// No description provided for @architectAxisRenamed.
  ///
  /// In en, this message translates to:
  /// **'Axis renamed to {name}'**
  String architectAxisRenamed(String name);

  /// Button to auto-number all axes
  ///
  /// In en, this message translates to:
  /// **'Resequence Axes'**
  String get resequenceGridAxesAction;

  /// Button to align all parallel axes extents
  ///
  /// In en, this message translates to:
  /// **'Align All Axes'**
  String get alignGridAxesAction;

  /// Button to align single axis extents
  ///
  /// In en, this message translates to:
  /// **'Align Extents'**
  String get alignGridAxisAction;

  /// Vertical axis orientation
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get architectAxisOrientationV;

  /// Horizontal axis orientation
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get architectAxisOrientationH;

  /// Snackbar when axis deleted
  ///
  /// In en, this message translates to:
  /// **'Axis deleted'**
  String get architectAxisDeleted;

  /// Snackbar when axis moved
  ///
  /// In en, this message translates to:
  /// **'Axis moved'**
  String get architectAxisMoved;

  /// Action and title for viewing diagnostic logs
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Logs'**
  String get architectDebugLogs;

  /// Button to clear diagnostic logs
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get architectClearLogs;

  /// Button to copy diagnostic logs
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get architectCopyLogs;

  /// Placeholder when diagnostic log history is empty
  ///
  /// In en, this message translates to:
  /// **'No logs recorded yet'**
  String get architectNoLogs;

  /// Snackbar when a door is placed
  ///
  /// In en, this message translates to:
  /// **'Door {specId} ({width}/{height}) placed'**
  String architectDoorPlaced(String specId, int width, int height);

  /// Project type label
  ///
  /// In en, this message translates to:
  /// **'Project Type'**
  String get bimProjectType;

  /// Structural BiM project type
  ///
  /// In en, this message translates to:
  /// **'Structural BiM'**
  String get bimProjectStructural;

  /// Architectural BiM project type
  ///
  /// In en, this message translates to:
  /// **'Architectural BiM'**
  String get bimProjectArchitectural;

  /// Description of structural BiM project
  ///
  /// In en, this message translates to:
  /// **'Load-bearing elements, columns, beams, shear walls, slabs, seismic & load analysis'**
  String get bimProjectStructuralDesc;

  /// Description of architectural BiM project
  ///
  /// In en, this message translates to:
  /// **'Walls, doors, windows, spaces, finishes, stairs, full architectural drafting'**
  String get bimProjectArchitecturalDesc;

  /// Filter tab for all projects
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get bimProjectFilterAll;

  /// Filter tab for structural projects
  ///
  /// In en, this message translates to:
  /// **'Structural'**
  String get bimProjectFilterStructural;

  /// Filter tab for architectural projects
  ///
  /// In en, this message translates to:
  /// **'Architectural'**
  String get bimProjectFilterArchitectural;

  /// Window tool
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get architectToolWindow;

  /// Column tool
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get architectToolColumn;

  /// Beam tool
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get architectToolBeam;

  /// Slab tool
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get architectToolSlab;

  /// Opening tool
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get architectToolOpening;

  /// Stairs tool
  ///
  /// In en, this message translates to:
  /// **'Stairs'**
  String get architectToolStair;

  /// Dimension tool
  ///
  /// In en, this message translates to:
  /// **'Dimension'**
  String get architectToolDimension;

  /// Level mark tool
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get architectToolLevel;

  /// Text annotation tool
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get architectToolText;

  /// CAD line tool
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get architectToolCadLine;

  /// No description provided for @architectToolPolyline.
  ///
  /// In en, this message translates to:
  /// **'Polyline'**
  String get architectToolPolyline;

  /// No description provided for @architectPolylineHint.
  ///
  /// In en, this message translates to:
  /// **'Draw connected segments as one object. Select it and drag a vertex or its leader dot to reshape it.'**
  String get architectPolylineHint;

  /// CAD rectangle tool
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get architectToolCadRect;

  /// CAD circle tool
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get architectToolCadCircle;

  /// CAD arc tool
  ///
  /// In en, this message translates to:
  /// **'Arc'**
  String get architectToolCadArc;

  /// CAD wipeout mask tool
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get architectToolMask;

  /// Multileader annotation tool
  ///
  /// In en, this message translates to:
  /// **'Multileader'**
  String get architectToolLeader;

  /// Spline curve tool
  ///
  /// In en, this message translates to:
  /// **'Spline'**
  String get architectToolSpline;

  /// CAD ellipse tool
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get architectToolCadEllipse;

  /// Roof slope arrow tool
  ///
  /// In en, this message translates to:
  /// **'Roof Slope'**
  String get architectToolRoofSlope;

  /// Line start cap style
  ///
  /// In en, this message translates to:
  /// **'Start Element'**
  String get architectLineStartCap;

  /// Line end cap style
  ///
  /// In en, this message translates to:
  /// **'End Element'**
  String get architectLineEndCap;

  /// No line end element
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get architectLineCapNone;

  /// Filled arrow line end
  ///
  /// In en, this message translates to:
  /// **'Filled Arrow'**
  String get architectLineCapArrowFilled;

  /// Open arrow line end
  ///
  /// In en, this message translates to:
  /// **'Open Arrow'**
  String get architectLineCapArrowOpen;

  /// Filled dot line end
  ///
  /// In en, this message translates to:
  /// **'Filled Dot'**
  String get architectLineCapDotFilled;

  /// Open dot line end
  ///
  /// In en, this message translates to:
  /// **'Open Dot'**
  String get architectLineCapDotOpen;

  /// Architectural tick line end
  ///
  /// In en, this message translates to:
  /// **'Architectural Tick'**
  String get architectLineCapTick;

  /// Size of line end elements
  ///
  /// In en, this message translates to:
  /// **'End Cap Size'**
  String get architectLineCapSize;

  /// Toggle curved line mode
  ///
  /// In en, this message translates to:
  /// **'Curved Line'**
  String get architectLineCurved;

  /// Hint for curved line
  ///
  /// In en, this message translates to:
  /// **'Bend line into a circular arc'**
  String get architectLineCurveHint;

  /// Mask border frame
  ///
  /// In en, this message translates to:
  /// **'Border Frame'**
  String get architectMaskBorder;

  /// Show mask border
  ///
  /// In en, this message translates to:
  /// **'Show Border Frame'**
  String get architectMaskBorderShow;

  /// Polyline arc segment mode
  ///
  /// In en, this message translates to:
  /// **'Arc Segment'**
  String get architectPolylineModeArc;

  /// Polyline straight segment mode
  ///
  /// In en, this message translates to:
  /// **'Line Segment'**
  String get architectPolylineModeLine;

  /// Close polyline contour
  ///
  /// In en, this message translates to:
  /// **'Close contour'**
  String get architectPolylineClose;

  /// Polyline width
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectPolylineWidth;

  /// Roof slope display format
  ///
  /// In en, this message translates to:
  /// **'Slope Format'**
  String get architectRoofSlopeFormat;

  /// Roof slope in percent
  ///
  /// In en, this message translates to:
  /// **'Percent (%)'**
  String get architectRoofSlopePercent;

  /// Roof slope in degrees
  ///
  /// In en, this message translates to:
  /// **'Degrees (°)'**
  String get architectRoofSlopeDegree;

  /// Roof slope in degrees and percent
  ///
  /// In en, this message translates to:
  /// **'Both (° and %)'**
  String get architectRoofSlopeBoth;

  /// Reverse slope arrow direction
  ///
  /// In en, this message translates to:
  /// **'Reverse Direction'**
  String get architectRoofSlopeReverse;

  /// Hint to place roof slope arrow
  ///
  /// In en, this message translates to:
  /// **'Tap on a roof plane to place a slope arrow'**
  String get architectRoofSlopeHint;

  /// Ellipse major radius
  ///
  /// In en, this message translates to:
  /// **'Major Radius'**
  String get architectEllipseMajorRadius;

  /// Ellipse minor radius
  ///
  /// In en, this message translates to:
  /// **'Minor Radius'**
  String get architectEllipseMinorRadius;

  /// Elliptical arc mode
  ///
  /// In en, this message translates to:
  /// **'Elliptical Arc'**
  String get architectEllipseArc;

  /// Leader note
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get architectLeaderNote;

  /// Prompt for leader note text
  ///
  /// In en, this message translates to:
  /// **'Enter note text'**
  String get architectLeaderPrompt;

  /// Window width label
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectWindowWidth;

  /// Window height label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectWindowHeight;

  /// Window sill label
  ///
  /// In en, this message translates to:
  /// **'Sill'**
  String get architectWindowSill;

  /// Quick action to flip window exterior/interior orientation
  ///
  /// In en, this message translates to:
  /// **'Flip exterior/interior side'**
  String get architectWindowFlipSide;

  /// Column shape label
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get architectColumnShape;

  /// Rectangular column shape
  ///
  /// In en, this message translates to:
  /// **'Rect.'**
  String get architectColumnRect;

  /// Circular column shape
  ///
  /// In en, this message translates to:
  /// **'Circular'**
  String get architectColumnCircle;

  /// Column size label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get architectColumnSize;

  /// Beam size label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get architectBeamSize;

  /// Stair width label
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectStairWidth;

  /// Stair steps label
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get architectStairSteps;

  /// Opening type label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get architectOpeningType;

  /// Shaft opening type
  ///
  /// In en, this message translates to:
  /// **'Shaft'**
  String get architectOpeningShaft;

  /// Slab void opening type
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get architectOpeningVoid;

  /// Level mark elevation label
  ///
  /// In en, this message translates to:
  /// **'Elevation / section'**
  String get architectLevelElevation;

  /// Annotation text label
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get architectAnnotationText;

  /// Toggle underlay display
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay'**
  String get architectUnderlayToggle;

  /// Snackbar when window placed
  ///
  /// In en, this message translates to:
  /// **'Window {specId} ({width}/{height}) placed'**
  String architectWindowPlaced(String specId, int width, int height);

  /// Snackbar when column placed
  ///
  /// In en, this message translates to:
  /// **'Column {label} placed'**
  String architectColumnPlaced(String label);

  /// Snackbar when beam placed
  ///
  /// In en, this message translates to:
  /// **'Beam placed'**
  String get architectBeamPlaced;

  /// Snackbar when stair placed
  ///
  /// In en, this message translates to:
  /// **'Stairs placed'**
  String get architectStairPlaced;

  /// Snackbar when opening placed
  ///
  /// In en, this message translates to:
  /// **'Opening placed'**
  String get architectOpeningPlaced;

  /// Snackbar when dimension line placed
  ///
  /// In en, this message translates to:
  /// **'Dimension line placed'**
  String get architectDimensionPlaced;

  /// Snackbar when level marker placed
  ///
  /// In en, this message translates to:
  /// **'Level marker placed'**
  String get architectLevelPlaced;

  /// Snackbar when annotation placed
  ///
  /// In en, this message translates to:
  /// **'Annotation placed'**
  String get architectAnnotationPlaced;

  /// Snackbar when CAD shape placed
  ///
  /// In en, this message translates to:
  /// **'CAD shape placed'**
  String get architectCadShapePlaced;

  /// Architectural elements structure category
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get architectCategoryStructure;

  /// Architectural spaces category
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get architectCategorySpaces;

  /// Annotations and dimensions category
  ///
  /// In en, this message translates to:
  /// **'Dimensions & text'**
  String get architectCategoryAnnotations;

  /// Freehand CAD drafting category
  ///
  /// In en, this message translates to:
  /// **'Drafting'**
  String get architectCategoryCad;

  /// Selected element indicator banner
  ///
  /// In en, this message translates to:
  /// **'Selected: {id}'**
  String selectedElement(String id);

  /// Title of architectural starter wizard
  ///
  /// In en, this message translates to:
  /// **'New Architectural Project'**
  String get architectWizardTitle;

  /// Subtitle of architectural starter wizard
  ///
  /// In en, this message translates to:
  /// **'Quick parametric project setup'**
  String get architectWizardSubtitle;

  /// Storeys configuration section title
  ///
  /// In en, this message translates to:
  /// **'Storeys & Heights'**
  String get architectWizardSectionStoreys;

  /// Grid axes section title
  ///
  /// In en, this message translates to:
  /// **'Structural Grid (Axes)'**
  String get architectWizardSectionGrid;

  /// Wall types section title
  ///
  /// In en, this message translates to:
  /// **'Wall Types & Balcony Parapet'**
  String get architectWizardSectionWalls;

  /// Parapet settings title
  ///
  /// In en, this message translates to:
  /// **'Balcony Parapet (12 cm curb)'**
  String get architectWizardParapetTitle;

  /// Information about statutory parapet height
  ///
  /// In en, this message translates to:
  /// **'Code height: {height} m ({level})'**
  String architectWizardParapetHeightInfo(String height, String level);

  /// Storey range descriptor
  ///
  /// In en, this message translates to:
  /// **'up to 5th storey'**
  String get architectWizardParapetUnder5;

  /// Storey range descriptor
  ///
  /// In en, this message translates to:
  /// **'above 5th storey / >20m'**
  String get architectWizardParapetOver5;

  /// Option for parapet coping cap
  ///
  /// In en, this message translates to:
  /// **'With Coping Cap'**
  String get architectWizardParapetFinishCap;

  /// Option for parapet handrail pipe
  ///
  /// In en, this message translates to:
  /// **'With Handrail Pipe on Posts (+15 cm)'**
  String get architectWizardParapetFinishPipe;

  /// Button to create project from wizard
  ///
  /// In en, this message translates to:
  /// **'Create Project & Start'**
  String get architectWizardCreateAction;

  /// Exterior insulated wall name
  ///
  /// In en, this message translates to:
  /// **'Exterior 25+12 EPS (37 cm)'**
  String get wallTypeExt25Eps12;

  /// Interior partition wall name
  ///
  /// In en, this message translates to:
  /// **'Partition 12 cm'**
  String get wallTypeInt12Partition;

  /// Uninsulated brick wall name
  ///
  /// In en, this message translates to:
  /// **'Brick 25 cm (no insulation)'**
  String get wallTypeExt25Brick;

  /// Balcony parapet wall name
  ///
  /// In en, this message translates to:
  /// **'Balcony Parapet 12 cm'**
  String get wallTypeParapet12;

  /// Default name for a new architectural project
  ///
  /// In en, this message translates to:
  /// **'Architectural Project'**
  String get architectDefaultProjectName;

  /// Storey count chip label
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Storey} other{{count} Storeys}}'**
  String architectStoreyCountChip(int count);

  /// Action button to launch architectural setup wizard
  ///
  /// In en, this message translates to:
  /// **'Start with Architectural Wizard'**
  String get architectLaunchWizard;

  /// Millimeters unit
  ///
  /// In en, this message translates to:
  /// **'Millimeters (mm)'**
  String get architectUnitMm;

  /// Feet unit
  ///
  /// In en, this message translates to:
  /// **'Feet (ft)'**
  String get architectUnitFeet;

  /// Inches unit
  ///
  /// In en, this message translates to:
  /// **'Inches (in)'**
  String get architectUnitInches;

  /// Unit system selector label
  ///
  /// In en, this message translates to:
  /// **'Dimensions System'**
  String get architectUnitSystem;

  /// Metric unit system
  ///
  /// In en, this message translates to:
  /// **'Metric (m, cm, mm)'**
  String get architectUnitSystemMetric;

  /// Imperial unit system
  ///
  /// In en, this message translates to:
  /// **'Imperial (ft, in)'**
  String get architectUnitSystemImperial;

  /// Step 1 title in wizard
  ///
  /// In en, this message translates to:
  /// **'1. Units'**
  String get architectWizardStep1;

  /// Step 2 title in wizard
  ///
  /// In en, this message translates to:
  /// **'2. Axes'**
  String get architectWizardStep2;

  /// Step 3 title in wizard
  ///
  /// In en, this message translates to:
  /// **'3. Storeys'**
  String get architectWizardStep3;

  /// Step 1 subtitle
  ///
  /// In en, this message translates to:
  /// **'Project name and dimensions system'**
  String get architectWizardStep1Subtitle;

  /// Step 2 subtitle
  ///
  /// In en, this message translates to:
  /// **'Grid axes and spacing'**
  String get architectWizardStep2Subtitle;

  /// Step 3 subtitle
  ///
  /// In en, this message translates to:
  /// **'Storey elevations and heights'**
  String get architectWizardStep3Subtitle;

  /// Next step button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get architectWizardNext;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get architectWizardBack;

  /// Wall core brick/concrete thickness
  ///
  /// In en, this message translates to:
  /// **'Core thickness'**
  String get architectWallCore;

  /// Wall EPS insulation thickness
  ///
  /// In en, this message translates to:
  /// **'EPS Insulation'**
  String get architectWallInsulation;

  /// Total wall thickness display
  ///
  /// In en, this message translates to:
  /// **'Total: {thickness}'**
  String architectWallTotalThickness(String thickness);

  /// Balcony parapet curb thickness
  ///
  /// In en, this message translates to:
  /// **'Curb thickness'**
  String get architectParapetCurb;

  /// Parapet height label
  ///
  /// In en, this message translates to:
  /// **'Parapet height'**
  String get architectParapetHeightLabel;

  /// No description provided for @architectWallLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get architectWallLength;

  /// No description provided for @architectWallDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get architectWallDirection;

  /// No description provided for @architectWallEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get architectWallEnd;

  /// No description provided for @architectWallContinue.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get architectWallContinue;

  /// No description provided for @architectWallReferenceCenter.
  ///
  /// In en, this message translates to:
  /// **'Axis'**
  String get architectWallReferenceCenter;

  /// No description provided for @architectWallReferenceLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get architectWallReferenceLeft;

  /// No description provided for @architectWallReferenceRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get architectWallReferenceRight;

  /// No description provided for @architectWallInsertPoint.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get architectWallInsertPoint;

  /// Endpoint marker number and its editable offset
  ///
  /// In en, this message translates to:
  /// **'{endpoint} · {distance}'**
  String architectWallEndpointValue(int endpoint, String distance);

  /// Wall positioning control guidance
  ///
  /// In en, this message translates to:
  /// **'End offset'**
  String get architectWallEndpointClearance;

  /// Wall positioning control guidance
  ///
  /// In en, this message translates to:
  /// **'Snap to walls, axes and drawing points.'**
  String get architectMagnetHelp;

  /// No description provided for @architectWallDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Hold → point · 2 fingers → zoom'**
  String get architectWallDraftHint;

  /// No description provided for @architectColumnPlacementHint.
  ///
  /// In en, this message translates to:
  /// **'Hold → place · Tap → select · X → cancel'**
  String get architectColumnPlacementHint;

  /// No description provided for @architectEditHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Hold → edit · longer → menu'**
  String get architectEditHoldHint;

  /// No description provided for @architectNavigationHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to pan; tap an object to edit.'**
  String get architectNavigationHint;

  /// No description provided for @architectWallEditRejected.
  ///
  /// In en, this message translates to:
  /// **'Opening or wall too short.'**
  String get architectWallEditRejected;

  /// No description provided for @architectSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Check storage.'**
  String get architectSaveFailed;

  /// No description provided for @architectWallExterior.
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get architectWallExterior;

  /// No description provided for @architectWallPartition.
  ///
  /// In en, this message translates to:
  /// **'Partition'**
  String get architectWallPartition;

  /// No description provided for @architectWallBrick.
  ///
  /// In en, this message translates to:
  /// **'Brick'**
  String get architectWallBrick;

  /// No description provided for @architectWallConcrete.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get architectWallConcrete;

  /// No description provided for @architectWallParapet.
  ///
  /// In en, this message translates to:
  /// **'Parapet'**
  String get architectWallParapet;

  /// No description provided for @architectWallReferenceInner.
  ///
  /// In en, this message translates to:
  /// **'Inside'**
  String get architectWallReferenceInner;

  /// No description provided for @architectWallReferenceOuter.
  ///
  /// In en, this message translates to:
  /// **'Outside'**
  String get architectWallReferenceOuter;

  /// No description provided for @architectWallFlipSide.
  ///
  /// In en, this message translates to:
  /// **'Flip exterior side'**
  String get architectWallFlipSide;

  /// No description provided for @architectSelectionMulti.
  ///
  /// In en, this message translates to:
  /// **'Multi'**
  String get architectSelectionMulti;

  /// No description provided for @architectSelectionMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get architectSelectionMove;

  /// No description provided for @architectMoveFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get architectMoveFree;

  /// No description provided for @architectMoveTransverse.
  ///
  /// In en, this message translates to:
  /// **'Across'**
  String get architectMoveTransverse;

  /// No description provided for @architectMoveOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset…'**
  String get architectMoveOffset;

  /// No description provided for @architectMoveStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get architectMoveStop;

  /// No description provided for @architectMoveHelp.
  ///
  /// In en, this message translates to:
  /// **'Move freely, across the element, or by an exact signed offset.'**
  String get architectMoveHelp;

  /// Select connected chain of elements
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get architectSelectConnected;

  /// Select all elements of the same type
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get architectSelectSimilar;

  /// Explains the category and active-storey scope of selection expansion
  ///
  /// In en, this message translates to:
  /// **'Select all elements in the selected categories on the active storey.'**
  String get architectSelectSimilarHelp;

  /// Smart context menu button
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get architectContextMenu;

  /// Number of items selected
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String architectSelectionCount(int count);

  /// Plural walls count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wall} other{{count} walls}}'**
  String architectSelectionWallsCount(int count);

  /// Plural columns count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 column} other{{count} columns}}'**
  String architectSelectionColumnsCount(int count);

  /// Plural beams count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 beam} other{{count} beams}}'**
  String architectSelectionBeamsCount(int count);

  /// Plural slabs count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 slab} other{{count} slabs}}'**
  String architectSelectionSlabsCount(int count);

  /// Summary of mixed element selection
  ///
  /// In en, this message translates to:
  /// **'{count} items: {details}'**
  String architectSelectionMixedSummary(int count, String details);

  /// Deselect active selection
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get architectDeselect;

  /// No description provided for @architectProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get architectProperties;

  /// No description provided for @architectWallExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get architectWallExtend;

  /// No description provided for @architectWallJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get architectWallJoin;

  /// No description provided for @architectOperationRejected.
  ///
  /// In en, this message translates to:
  /// **'Cannot apply here.'**
  String get architectOperationRejected;

  /// No description provided for @architectPropertyHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectPropertyHeight;

  /// No description provided for @architectPropertyWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectPropertyWidth;

  /// No description provided for @architectPropertyDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get architectPropertyDepth;

  /// No description provided for @architectPropertyThickness.
  ///
  /// In en, this message translates to:
  /// **'Thk.'**
  String get architectPropertyThickness;

  /// No description provided for @architectPropertyCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get architectPropertyCore;

  /// No description provided for @architectPropertyInsulation.
  ///
  /// In en, this message translates to:
  /// **'Insul.'**
  String get architectPropertyInsulation;

  /// No description provided for @architectPropertyAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get architectPropertyAngle;

  /// No description provided for @architectPropertySteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get architectPropertySteps;

  /// No description provided for @architectPropertySill.
  ///
  /// In en, this message translates to:
  /// **'Sill'**
  String get architectPropertySill;

  /// No description provided for @architectPropertyOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get architectPropertyOffset;

  /// Element base elevation offset above storey level
  ///
  /// In en, this message translates to:
  /// **'Base H'**
  String get architectPropertyBaseOffset;

  /// Floor plan cut display mode
  ///
  /// In en, this message translates to:
  /// **'Cut View'**
  String get architectPropertyCutDisplay;

  /// Automatic cut calculation based on cut plane
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get architectCutDisplayAuto;

  /// Always display uncut in projection
  ///
  /// In en, this message translates to:
  /// **'Projected'**
  String get architectCutDisplayProjected;

  /// Always display as cut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get architectCutDisplayCut;

  /// Display as overhead element
  ///
  /// In en, this message translates to:
  /// **'Overhead'**
  String get architectCutDisplayOverhead;

  /// Storey floor plan cut plane height
  ///
  /// In en, this message translates to:
  /// **'Cut H'**
  String get architectStoreyCutPlane;

  /// No description provided for @architectPropertySize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get architectPropertySize;

  /// No description provided for @architectPropertyName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get architectPropertyName;

  /// No description provided for @architectWallExtendHint.
  ///
  /// In en, this message translates to:
  /// **'Pick target'**
  String get architectWallExtendHint;

  /// No description provided for @architectWallCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get architectWallCut;

  /// No description provided for @architectWallCutHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the part between crossings'**
  String get architectWallCutHint;

  /// No description provided for @architectWallDetach.
  ///
  /// In en, this message translates to:
  /// **'Detach'**
  String get architectWallDetach;

  /// No description provided for @architectWallAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get architectWallAttach;

  /// Prompt when selecting the second wall to attach
  ///
  /// In en, this message translates to:
  /// **'Select second wall to connect at common vertex'**
  String get architectWallAttachSelectSecond;

  /// Success message when walls are attached at common vertex
  ///
  /// In en, this message translates to:
  /// **'Walls connected at common vertex'**
  String get architectWallAttachSuccess;

  /// Error message when walls cannot be connected
  ///
  /// In en, this message translates to:
  /// **'Walls cannot be connected at a common vertex'**
  String get architectWallAttachIncompatible;

  /// Success message when wall is detached
  ///
  /// In en, this message translates to:
  /// **'Wall detached'**
  String get architectWallDetachSuccess;

  /// Prompt shown in detach confirmation banner
  ///
  /// In en, this message translates to:
  /// **'Detach wall'**
  String get architectWallDetachPrompt;

  /// Label for dynamic offset distance editing
  ///
  /// In en, this message translates to:
  /// **'Offset distance'**
  String get architectOffsetDynamicDistance;

  /// No description provided for @architectWallMagnet.
  ///
  /// In en, this message translates to:
  /// **'Magnet'**
  String get architectWallMagnet;

  /// No description provided for @architectWallAlign.
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get architectWallAlign;

  /// No description provided for @architectWallMirror.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get architectWallMirror;

  /// No description provided for @architectWallSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get architectWallSplit;

  /// No description provided for @architectWallSplitHint.
  ///
  /// In en, this message translates to:
  /// **'Split: two points across walls'**
  String get architectWallSplitHint;

  /// Hint for first click in split tool to confirm surface
  ///
  /// In en, this message translates to:
  /// **'Click to confirm surface'**
  String get architectWallSplitSurfaceHint;

  /// Hint for second click in split tool for cut direction
  ///
  /// In en, this message translates to:
  /// **'Click for cut direction'**
  String get architectWallSplitDirectionHint;

  /// Prompt to pick the first point of the split cut line
  ///
  /// In en, this message translates to:
  /// **'Specify first split point'**
  String get architectWallSplitPromptPickFirst;

  /// Prompt to pick the second point of the split cut line
  ///
  /// In en, this message translates to:
  /// **'Specify second split point'**
  String get architectWallSplitPromptPickSecond;

  /// Prompt to select which side remains selected after split
  ///
  /// In en, this message translates to:
  /// **'Click the side to keep selected'**
  String get architectWallSplitPromptPickSide;

  /// Button to snap split cut line perpendicular to the wall
  ///
  /// In en, this message translates to:
  /// **'Perpendicular'**
  String get architectWallSplitPerpendicular;

  /// Button to keep side 1 selected after split
  ///
  /// In en, this message translates to:
  /// **'Side 1'**
  String get architectWallSplitSide1;

  /// Button to keep side 2 selected after split
  ///
  /// In en, this message translates to:
  /// **'Side 2'**
  String get architectWallSplitSide2;

  /// Button to keep both sides selected after split
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get architectWallSplitBoth;

  /// No description provided for @architectWallClearance.
  ///
  /// In en, this message translates to:
  /// **'Clearance'**
  String get architectWallClearance;

  /// No description provided for @architectGridNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get architectGridNone;

  /// No description provided for @architectGridCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get architectGridCustom;

  /// No description provided for @architectGridBays.
  ///
  /// In en, this message translates to:
  /// **'Bays {x} × {y}'**
  String architectGridBays(int x, int y);

  /// No description provided for @architectGridPickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag to choose bays. Each direction has one more axis than bays. Tap a dimension on the grid to edit it.'**
  String get architectGridPickerHelp;

  /// No description provided for @architectGridFewer.
  ///
  /// In en, this message translates to:
  /// **'Fewer bays'**
  String get architectGridFewer;

  /// No description provided for @architectGridMore.
  ///
  /// In en, this message translates to:
  /// **'More bays'**
  String get architectGridMore;

  /// No description provided for @architectWizardUnitsShort.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get architectWizardUnitsShort;

  /// No description provided for @architectWizardGridShort.
  ///
  /// In en, this message translates to:
  /// **'Axes'**
  String get architectWizardGridShort;

  /// No description provided for @architectWizardWallsShort.
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get architectWizardWallsShort;

  /// No description provided for @architectWizardTitleShort.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get architectWizardTitleShort;

  /// No description provided for @architectGridSpanLabel.
  ///
  /// In en, this message translates to:
  /// **'Spacing {axes}: {value}'**
  String architectGridSpanLabel(String axes, String value);

  /// No description provided for @architectGridParkingHelp.
  ///
  /// In en, this message translates to:
  /// **'Parking grid'**
  String get architectGridParkingHelp;

  /// No description provided for @architectGridResidentialHelp.
  ///
  /// In en, this message translates to:
  /// **'Residential grid'**
  String get architectGridResidentialHelp;

  /// No description provided for @architectGridVillaHelp.
  ///
  /// In en, this message translates to:
  /// **'House grid'**
  String get architectGridVillaHelp;

  /// No description provided for @architectGridModularHelp.
  ///
  /// In en, this message translates to:
  /// **'Office grid'**
  String get architectGridModularHelp;

  /// No description provided for @architectGridNoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Start without axes'**
  String get architectGridNoneHelp;

  /// No description provided for @architectRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get architectRadius;

  /// No description provided for @architectShapeWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectShapeWidth;

  /// No description provided for @architectShapeHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectShapeHeight;

  /// Title of parametric window and door designer screen
  ///
  /// In en, this message translates to:
  /// **'Window & Door Designer'**
  String get architectFenestrationEditor;

  /// Button to create a new window or door model
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get architectFenestrationCreateNew;

  /// Button to edit opening style
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get architectFenestrationEditStyle;

  /// Opening style label
  ///
  /// In en, this message translates to:
  /// **'Opening Model'**
  String get architectFenestrationStyle;

  /// Button to save window/door model to library
  ///
  /// In en, this message translates to:
  /// **'Save to Library'**
  String get architectFenestrationSave;

  /// Toast message on model save success
  ///
  /// In en, this message translates to:
  /// **'Model saved to library'**
  String get architectFenestrationSaveSuccess;

  /// Button to delete window/door model from library
  ///
  /// In en, this message translates to:
  /// **'Delete from Library'**
  String get architectFenestrationDelete;

  /// Toast message on model delete success
  ///
  /// In en, this message translates to:
  /// **'Model deleted from library'**
  String get architectFenestrationDeleteSuccess;

  /// No description provided for @architectFenestrationDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from library?'**
  String architectFenestrationDeleteConfirm(String name);

  /// Openings library title
  ///
  /// In en, this message translates to:
  /// **'Openings Library'**
  String get architectFenestrationLibrary;

  /// Window/door trim or casing label
  ///
  /// In en, this message translates to:
  /// **'Trim / Casing'**
  String get architectFenestrationCasing;

  /// Width of trim casing around opening
  ///
  /// In en, this message translates to:
  /// **'Casing Width'**
  String get architectFenestrationCasingWidth;

  /// Depth of casing projecting from wall surface
  ///
  /// In en, this message translates to:
  /// **'Casing Projection'**
  String get architectFenestrationCasingProjection;

  /// Casing position label
  ///
  /// In en, this message translates to:
  /// **'Casing Position'**
  String get architectFenestrationCasingPlacement;

  /// Exterior side casing
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get architectFenestrationCasingExterior;

  /// Interior side casing
  ///
  /// In en, this message translates to:
  /// **'Interior'**
  String get architectFenestrationCasingInterior;

  /// Both exterior and interior casing
  ///
  /// In en, this message translates to:
  /// **'Both Sides'**
  String get architectFenestrationCasingBoth;

  /// 5-chamber PVC frame specification
  ///
  /// In en, this message translates to:
  /// **'5-Chamber Frame (70 mm)'**
  String get architectFenestrationFrame5Chamber;

  /// Frame profile face width
  ///
  /// In en, this message translates to:
  /// **'Frame Face'**
  String get architectFenestrationFrameFaceWidth;

  /// Double glazing unit specification
  ///
  /// In en, this message translates to:
  /// **'Double Glazing (24 mm)'**
  String get architectFenestrationGlazingDouble;

  /// Glazing thickness label
  ///
  /// In en, this message translates to:
  /// **'Glazing Thickness'**
  String get architectFenestrationGlazingThickness;

  /// Add horizontal division or transom
  ///
  /// In en, this message translates to:
  /// **'Split Horizontally'**
  String get architectFenestrationSplitH;

  /// Add vertical division or mullion
  ///
  /// In en, this message translates to:
  /// **'Split Vertically'**
  String get architectFenestrationSplitV;

  /// Remove subdivision in pane
  ///
  /// In en, this message translates to:
  /// **'Remove Split'**
  String get architectFenestrationRemoveSplit;

  /// Type of selected opening pane
  ///
  /// In en, this message translates to:
  /// **'Pane Type'**
  String get architectFenestrationPaneType;

  /// Fixed glass pane
  ///
  /// In en, this message translates to:
  /// **'Fixed Glazing'**
  String get architectFenestrationPaneFixed;

  /// Openable casement turning left
  ///
  /// In en, this message translates to:
  /// **'Casement Left'**
  String get architectFenestrationPaneTurnLeft;

  /// Openable casement turning right
  ///
  /// In en, this message translates to:
  /// **'Casement Right'**
  String get architectFenestrationPaneTurnRight;

  /// Tilt and turn dual opening casement
  ///
  /// In en, this message translates to:
  /// **'Tilt & Turn'**
  String get architectFenestrationPaneTiltTurn;

  /// Top opening hopper casement
  ///
  /// In en, this message translates to:
  /// **'Top Hopper'**
  String get architectFenestrationPaneTopHopper;

  /// Door leaf pane
  ///
  /// In en, this message translates to:
  /// **'Door Leaf'**
  String get architectFenestrationPaneDoorLeaf;

  /// Solid insulated infill panel
  ///
  /// In en, this message translates to:
  /// **'Solid Panel'**
  String get architectFenestrationPaneSolidPanel;

  /// Dimensions tab label
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get architectFenestrationDimensions;

  /// Profile and glass tab label
  ///
  /// In en, this message translates to:
  /// **'Profile & Glass'**
  String get architectFenestrationProfile;

  /// Subdivisions tab label
  ///
  /// In en, this message translates to:
  /// **'Raster & Panes'**
  String get architectFenestrationDivisions;

  /// Preset catalog tab label
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get architectFenestrationPresets;

  /// 2D elevation view tab
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectFenestrationViewElevation;

  /// 3D view tab
  ///
  /// In en, this message translates to:
  /// **'3D View'**
  String get architectFenestrationView3D;

  /// 2D plan view tab
  ///
  /// In en, this message translates to:
  /// **'Plan (2D)'**
  String get architectFenestrationViewPlan;

  /// Bottom casing under window
  ///
  /// In en, this message translates to:
  /// **'Include Bottom Casing'**
  String get architectFenestrationIncludeBottomCasing;

  /// Explanation of exterior casing relationship to wall
  ///
  /// In en, this message translates to:
  /// **'Casing sits on exterior face of wall & insulation without cutting wall'**
  String get architectFenestrationWallContextHelp;

  /// Apply opening style to current project
  ///
  /// In en, this message translates to:
  /// **'Apply to Project'**
  String get architectFenestrationApplyToProject;

  /// Custom user-created opening style tag
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get architectFenestrationCustom;

  /// Standard preset opening style tag
  ///
  /// In en, this message translates to:
  /// **'Standard Preset'**
  String get architectFenestrationPreset;

  /// Modal title for choosing opening style
  ///
  /// In en, this message translates to:
  /// **'Select Opening Model'**
  String get architectFenestrationSelectStyle;

  /// Step 1 in window designer: frame and division grid
  ///
  /// In en, this message translates to:
  /// **'1. Frame & Grid'**
  String get architectFenestrationStep1;

  /// Step 2 in window designer: operability and inner sashes
  ///
  /// In en, this message translates to:
  /// **'2. Operability'**
  String get architectFenestrationStep2;

  /// Step 3 in window designer: glass, panels, and muntins
  ///
  /// In en, this message translates to:
  /// **'3. Infill & Muntins'**
  String get architectFenestrationStep3;

  /// Next step button
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get architectFenestrationNextStep;

  /// Previous step button
  ///
  /// In en, this message translates to:
  /// **'Previous Step'**
  String get architectFenestrationPrevStep;

  /// Glazing bars/muntins label
  ///
  /// In en, this message translates to:
  /// **'Muntins / Glazing Bars'**
  String get architectFenestrationMuntins;

  /// Vertical muntin bars count
  ///
  /// In en, this message translates to:
  /// **'Vertical Muntins'**
  String get architectFenestrationMuntinCols;

  /// Horizontal muntin bars count
  ///
  /// In en, this message translates to:
  /// **'Horizontal Muntins'**
  String get architectFenestrationMuntinRows;

  /// Width of muntin profile
  ///
  /// In en, this message translates to:
  /// **'Muntin Width'**
  String get architectFenestrationMuntinWidth;

  /// Preset with no muntin bars
  ///
  /// In en, this message translates to:
  /// **'No Muntins'**
  String get architectFenestrationMuntinNone;

  /// Classic 2x2 muntin grid preset
  ///
  /// In en, this message translates to:
  /// **'Classic 2x2'**
  String get architectFenestrationMuntinClassic;

  /// Georgian 2x3 muntin grid preset
  ///
  /// In en, this message translates to:
  /// **'Georgian 2x3'**
  String get architectFenestrationMuntinVictorian;

  /// Grid 3x3 muntin preset
  ///
  /// In en, this message translates to:
  /// **'Grid 3x3'**
  String get architectFenestrationMuntinGrid3x3;

  /// Inner operable sash profile width
  ///
  /// In en, this message translates to:
  /// **'Inner Sash Frame'**
  String get architectFenestrationSashProfile;

  /// Button to set exact dimension with keypad
  ///
  /// In en, this message translates to:
  /// **'Set Exact Dimension'**
  String get architectFenestrationExactDimension;

  /// Width of individual leaf pane
  ///
  /// In en, this message translates to:
  /// **'Leaf Width'**
  String get architectFenestrationLeafWidth;

  /// Height of individual leaf pane
  ///
  /// In en, this message translates to:
  /// **'Leaf Height'**
  String get architectFenestrationLeafHeight;

  /// Glass infill option
  ///
  /// In en, this message translates to:
  /// **'Glazing (Glass)'**
  String get architectFenestrationInfillGlazing;

  /// Solid insulated panel infill option
  ///
  /// In en, this message translates to:
  /// **'Solid Panel'**
  String get architectFenestrationInfillSolid;

  /// Add horizontal division in selected pane
  ///
  /// In en, this message translates to:
  /// **'Add Transom (Horiz.)'**
  String get architectFenestrationAddTransom;

  /// Add vertical division in selected pane
  ///
  /// In en, this message translates to:
  /// **'Add Mullion (Vert.)'**
  String get architectFenestrationAddMullion;

  /// Selected leaf header
  ///
  /// In en, this message translates to:
  /// **'Selected Pane'**
  String get architectFenestrationSelectedLeaf;

  /// Color swatch label for exterior casing
  ///
  /// In en, this message translates to:
  /// **'Casing Color'**
  String get architectFenestrationCasingColor;

  /// Mounting plane position label
  ///
  /// In en, this message translates to:
  /// **'Mounting Plane'**
  String get architectFenestrationMountingPlane;

  /// Description of mounting position
  ///
  /// In en, this message translates to:
  /// **'Centered inside brick core with exterior casing trim'**
  String get architectFenestrationMountingPlaneHelp;

  /// Subtitle tag indicating casing is enabled
  ///
  /// In en, this message translates to:
  /// **'With casing'**
  String get architectFenestrationWithCasing;

  /// Radial menu move action
  ///
  /// In en, this message translates to:
  /// **'Drag'**
  String get architectRadialMove;

  /// Drag tool label
  ///
  /// In en, this message translates to:
  /// **'Drag'**
  String get architectToolDrag;

  /// Drag tool description
  ///
  /// In en, this message translates to:
  /// **'Freely drag elements by picking any base point'**
  String get architectToolDragDesc;

  /// Drag tool prompt to pick base point
  ///
  /// In en, this message translates to:
  /// **'Click anywhere on element to grab base point'**
  String get architectDragPickBasePoint;

  /// Drag tool prompt to pick target point
  ///
  /// In en, this message translates to:
  /// **'Pick new position to move element'**
  String get architectDragPickTargetPoint;

  /// Drag tool success message
  ///
  /// In en, this message translates to:
  /// **'Element moved successfully'**
  String get architectDragSuccess;

  /// Snap helper label for orthogonal alignment with 1st point of polygon
  ///
  /// In en, this message translates to:
  /// **'Alignment with Point 1'**
  String get snapAlignPoint1;

  /// Radial menu edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get architectRadialEdit;

  /// Radial menu delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get architectRadialDelete;

  /// Radial menu duplicate action
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get architectRadialDuplicate;

  /// Short radial action for renaming an axis
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get architectRadialRename;

  /// Radial menu rotate action
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get architectRadialRotate;

  /// Radial menu flip action
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get architectRadialFlip;

  /// Radial menu properties action
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get architectRadialProperties;

  /// Radial menu split action
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get architectRadialSplit;

  /// Radial menu cut/trim action
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get architectRadialCut;

  /// Radial menu offset action
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get architectRadialOffset;

  /// Mirror move action label
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get architectMirrorMove;

  /// Mirror move action tooltip
  ///
  /// In en, this message translates to:
  /// **'Mirror move'**
  String get architectMirrorMoveTooltip;

  /// Mirror copy action label
  ///
  /// In en, this message translates to:
  /// **'Mirror+'**
  String get architectMirrorCopy;

  /// Mirror copy action tooltip
  ///
  /// In en, this message translates to:
  /// **'Mirror copy'**
  String get architectMirrorCopyTooltip;

  /// Prompt for picking mirror reference anchor point
  ///
  /// In en, this message translates to:
  /// **'Pick mirror anchor'**
  String get architectMirrorPromptPickAnchor;

  /// Prompt for specifying second point or mirror axis direction
  ///
  /// In en, this message translates to:
  /// **'Pick second axis point'**
  String get architectMirrorPromptPickAxis;

  /// Button to mirror across a vertical axis through anchor
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get architectMirrorAxisVertical;

  /// Button to mirror across a horizontal axis through anchor
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get architectMirrorAxisHorizontal;

  /// No description provided for @architectEdgeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get architectEdgeDistance;

  /// No description provided for @architectPolygonExactOffset.
  ///
  /// In en, this message translates to:
  /// **'Exact offset'**
  String get architectPolygonExactOffset;

  /// No description provided for @architectPolygonExactOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Exact offset: drag an edge or vertex to set the direction, then enter the distance with the app keypad.'**
  String get architectPolygonExactOffsetHint;

  /// No description provided for @architectEdgeOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Positive moves outward; negative moves inward. The distance is measured from the original edge.'**
  String get architectEdgeOffsetHint;

  /// No description provided for @architectVertexOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Distance along the drag direction from the original vertex. Use ± to reverse the direction.'**
  String get architectVertexOffsetHint;

  /// No description provided for @architectEdgeSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select an edge'**
  String get architectEdgeSelectHint;

  /// No description provided for @architectEdgeDistanceHint.
  ///
  /// In en, this message translates to:
  /// **'Set the distance by moving the selected edge.'**
  String get architectEdgeDistanceHint;

  /// No description provided for @architectEdgeMoveHint.
  ///
  /// In en, this message translates to:
  /// **'Move the edge parallel to itself, with both endpoints.'**
  String get architectEdgeMoveHint;

  /// No description provided for @architectEdgePullHint.
  ///
  /// In en, this message translates to:
  /// **'Pull the edge and retain its original corners.'**
  String get architectEdgePullHint;

  /// No description provided for @dragDuplicateAction.
  ///
  /// In en, this message translates to:
  /// **'Drag+'**
  String get dragDuplicateAction;

  /// No description provided for @dragDuplicateHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to place the copy'**
  String get dragDuplicateHint;

  /// No description provided for @structuralBeamNamePrefix.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get structuralBeamNamePrefix;

  /// No description provided for @bimUnderlayReviewCompleteAction.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get bimUnderlayReviewCompleteAction;

  /// No description provided for @bimUnderlayReviewCompleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark the preserved elements and openings as reviewed'**
  String get bimUnderlayReviewCompleteTooltip;

  /// No description provided for @bimNewPoint.
  ///
  /// In en, this message translates to:
  /// **'New point'**
  String get bimNewPoint;

  /// No description provided for @bimNewPointHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handle, then confirm.'**
  String get bimNewPointHint;

  /// Prompt message shown in banner when manually placing a new point on an element edge
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get architectNewPointPrompt;

  /// No description provided for @architectNewPointInvalid.
  ///
  /// In en, this message translates to:
  /// **'Avoid ends and openings'**
  String get architectNewPointInvalid;

  /// No description provided for @bimWallNewPointHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds connected wall segments. Split cuts and disconnects them.'**
  String get bimWallNewPointHelp;

  /// No description provided for @architectCanvasLight.
  ///
  /// In en, this message translates to:
  /// **'Light background'**
  String get architectCanvasLight;

  /// No description provided for @architectCanvasDark.
  ///
  /// In en, this message translates to:
  /// **'Dark background'**
  String get architectCanvasDark;

  /// No description provided for @architectWallType.
  ///
  /// In en, this message translates to:
  /// **'Wall type'**
  String get architectWallType;

  /// No description provided for @architectWallFollowStorey.
  ///
  /// In en, this message translates to:
  /// **'Follow storey'**
  String get architectWallFollowStorey;

  /// No description provided for @architectWallLeadingLine.
  ///
  /// In en, this message translates to:
  /// **'Leading line'**
  String get architectWallLeadingLine;

  /// No description provided for @architectWallLeadingLineHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the axis or face to follow for this and the following segments.'**
  String get architectWallLeadingLineHelp;

  /// No description provided for @architectWallCoreThickness.
  ///
  /// In en, this message translates to:
  /// **'Core thickness'**
  String get architectWallCoreThickness;

  /// No description provided for @architectPropertyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get architectPropertyTotal;

  /// No description provided for @architectMaterialBrick.
  ///
  /// In en, this message translates to:
  /// **'Brick'**
  String get architectMaterialBrick;

  /// No description provided for @architectMaterialConcrete.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get architectMaterialConcrete;

  /// No description provided for @architectMaterialTimber.
  ///
  /// In en, this message translates to:
  /// **'Timber'**
  String get architectMaterialTimber;

  /// No description provided for @architectMaterialPanel.
  ///
  /// In en, this message translates to:
  /// **'Thermal panel'**
  String get architectMaterialPanel;

  /// No description provided for @architectInsulationXps.
  ///
  /// In en, this message translates to:
  /// **'XPS'**
  String get architectInsulationXps;

  /// No description provided for @architectInsulationEps.
  ///
  /// In en, this message translates to:
  /// **'EPS'**
  String get architectInsulationEps;

  /// No description provided for @architectInsulationStoneWool.
  ///
  /// In en, this message translates to:
  /// **'Stone wool'**
  String get architectInsulationStoneWool;

  /// No description provided for @architectSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get architectSettings;

  /// No description provided for @architectGhostStoreys.
  ///
  /// In en, this message translates to:
  /// **'Ghost storeys'**
  String get architectGhostStoreys;

  /// Toggle to display erkers and balconies from the floor above with dashed lines on active storey
  ///
  /// In en, this message translates to:
  /// **'Upper floor erkers & balconies'**
  String get architectUpperOverhangs;

  /// Tooltip or help text for upper overhangs setting
  ///
  /// In en, this message translates to:
  /// **'Automatically display erkers and balconies from the floor above as dashed lines'**
  String get architectUpperOverhangsHelp;

  /// Short label for cantilevered erker projection from floor above
  ///
  /// In en, this message translates to:
  /// **'Erker'**
  String get architectOverhangErker;

  /// Short label for balcony projection from floor above
  ///
  /// In en, this message translates to:
  /// **'Balcony'**
  String get architectOverhangBalcony;

  /// No description provided for @architectDrawingGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get architectDrawingGrid;

  /// No description provided for @architectSnap.
  ///
  /// In en, this message translates to:
  /// **'Snap'**
  String get architectSnap;

  /// Setting label for the length of offset handles when editing points of walls, slabs, roofs and other elements
  ///
  /// In en, this message translates to:
  /// **'Handle leader line length'**
  String get architectHandleOffsetLength;

  /// No description provided for @architectAxesWallThickness.
  ///
  /// In en, this message translates to:
  /// **'Wall core for axes'**
  String get architectAxesWallThickness;

  /// No description provided for @architectAxesFromWallsHelp.
  ///
  /// In en, this message translates to:
  /// **'Create axes through wall cores on this storey. Set the core thickness in Settings.'**
  String get architectAxesFromWallsHelp;

  /// No description provided for @architectAxesNoMatchingWalls.
  ///
  /// In en, this message translates to:
  /// **'No walls match the selected core thickness.'**
  String get architectAxesNoMatchingWalls;

  /// No description provided for @architectAxesGenerated.
  ///
  /// In en, this message translates to:
  /// **'Added {count} axes'**
  String architectAxesGenerated(int count);

  /// No description provided for @architectDimensionChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get architectDimensionChain;

  /// No description provided for @architectDimensionScale.
  ///
  /// In en, this message translates to:
  /// **'Dimension scale'**
  String get architectDimensionScale;

  /// No description provided for @architectDimensionSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get architectDimensionSingle;

  /// No description provided for @architectDimensionExterior.
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get architectDimensionExterior;

  /// No description provided for @architectDimensionExteriorHelp.
  ///
  /// In en, this message translates to:
  /// **'Rows: openings, wall sections, overall core size with separate end insulation, axes. Row spacing follows drawing scale and text size. Facade openings and perpendicular axes are included automatically; picks on insulation reference the core.'**
  String get architectDimensionExteriorHelp;

  /// No description provided for @architectDimensionInterior.
  ///
  /// In en, this message translates to:
  /// **'Interior'**
  String get architectDimensionInterior;

  /// No description provided for @architectDimensionInteriorHint.
  ///
  /// In en, this message translates to:
  /// **'Select end walls and partitions, then position the line.'**
  String get architectDimensionInteriorHint;

  /// No description provided for @architectDimensionInteriorHelp.
  ///
  /// In en, this message translates to:
  /// **'One row measures between the inner faces of parallel end walls, including both faces of intermediate partitions.'**
  String get architectDimensionInteriorHelp;

  /// No description provided for @architectDimensionAddWalls.
  ///
  /// In en, this message translates to:
  /// **'Add walls'**
  String get architectDimensionAddWalls;

  /// No description provided for @architectDimensionEditPoints.
  ///
  /// In en, this message translates to:
  /// **'Edit points'**
  String get architectDimensionEditPoints;

  /// No description provided for @architectDimensionEditPointsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a wall to add it, or a minus to remove it. The green check saves.'**
  String get architectDimensionEditPointsHint;

  /// No description provided for @architectDimensionRemoveReference.
  ///
  /// In en, this message translates to:
  /// **'Remove from dimension'**
  String get architectDimensionRemoveReference;

  /// No description provided for @architectDimensionKeepReferences.
  ///
  /// In en, this message translates to:
  /// **'Add another reference before removing this one; a dimension needs two distinct endpoints.'**
  String get architectDimensionKeepReferences;

  /// No description provided for @architectDimensionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save the displayed dimension'**
  String get architectDimensionConfirm;

  /// No description provided for @architectDimensionAddWallsHint.
  ///
  /// In en, this message translates to:
  /// **'Select missing parallel walls, then confirm. The dimension line stays in place.'**
  String get architectDimensionAddWallsHint;

  /// No description provided for @architectDimensionStartHint.
  ///
  /// In en, this message translates to:
  /// **'Select the first measured point.'**
  String get architectDimensionStartHint;

  /// No description provided for @architectDimensionEndHint.
  ///
  /// In en, this message translates to:
  /// **'Select the second measured point, then position the dimension line.'**
  String get architectDimensionEndHint;

  /// No description provided for @architectDimensionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get architectDimensionContinue;

  /// No description provided for @architectDimensionFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get architectDimensionFinish;

  /// No description provided for @architectDimensionPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get architectDimensionPlace;

  /// No description provided for @architectDimensionChainHint.
  ///
  /// In en, this message translates to:
  /// **'Select walls or points. Green check saves; minus removes a reference.'**
  String get architectDimensionChainHint;

  /// No description provided for @architectDimensionDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'Select a wall or line parallel to the dimension line.'**
  String get architectDimensionDirectionHint;

  /// No description provided for @architectDimensionPositionHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to position the dimension line, or enter an exact offset.'**
  String get architectDimensionPositionHint;

  /// No description provided for @architectSelectionCycleHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap to select; repeated taps cycle overlaps. Hold for actions.'**
  String get architectSelectionCycleHelp;

  /// No description provided for @architectDimensionOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall dimension'**
  String get architectDimensionOverall;

  /// Snap indicator label when dimension distance is 30 cm
  ///
  /// In en, this message translates to:
  /// **'30 cm'**
  String get architectDimensionSnap30cm;

  /// Snap indicator label when dimension distance is 40 cm
  ///
  /// In en, this message translates to:
  /// **'40 cm'**
  String get architectDimensionSnap40cm;

  /// Context menu action to add a new point to a dimension
  ///
  /// In en, this message translates to:
  /// **'New point'**
  String get architectDimensionNewPoint;

  /// Default label for ground floor
  ///
  /// In en, this message translates to:
  /// **'Ground Floor'**
  String get architectStoreyGround;

  /// Default label for upper storeys
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get architectStoreyFloor;

  /// Plural doors count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 door} other{{count} doors}}'**
  String architectSelectionDoorsCount(int count);

  /// Plural windows count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 window} other{{count} windows}}'**
  String architectSelectionWindowsCount(int count);

  /// Plural zones count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 zone} other{{count} zones}}'**
  String architectSelectionZonesCount(int count);

  /// Plural axes count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 axis} other{{count} axes}}'**
  String architectSelectionAxesCount(int count);

  /// Plural CAD primitives count in selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 CAD} other{{count} CAD}}'**
  String architectSelectionCadCount(int count);

  /// Snap label for corners
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get snapCorner;

  /// Snap label for edges
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get snapEdge;

  /// Snap label for vertex merging
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get snapMerge;

  /// Snap label for door jamb alignment
  ///
  /// In en, this message translates to:
  /// **'Door jamb'**
  String get snapDoorJamb;

  /// Snap label for window jamb alignment
  ///
  /// In en, this message translates to:
  /// **'Window jamb'**
  String get snapWindowJamb;

  /// Door threshold sill none chip
  ///
  /// In en, this message translates to:
  /// **'Sill: 0'**
  String get architectDoorSillNone;

  /// Door threshold sill 15cm chip
  ///
  /// In en, this message translates to:
  /// **'Step: 15 cm'**
  String get architectDoorSillStep;

  /// Zone category living room
  ///
  /// In en, this message translates to:
  /// **'Living Room'**
  String get architectZoneCatLiving;

  /// Zone category bedroom
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get architectZoneCatBedroom;

  /// Zone category kitchen
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get architectZoneCatKitchen;

  /// Zone category corridor
  ///
  /// In en, this message translates to:
  /// **'Corridor / Hall'**
  String get architectZoneCatCorridor;

  /// Zone category bathroom
  ///
  /// In en, this message translates to:
  /// **'Bathroom / WC'**
  String get architectZoneCatBathroom;

  /// Zone category terrace
  ///
  /// In en, this message translates to:
  /// **'Terrace / Balcony'**
  String get architectZoneCatTerrace;

  /// Zone category storage
  ///
  /// In en, this message translates to:
  /// **'Storage / Utility'**
  String get architectZoneCatStorage;

  /// Zone category office
  ///
  /// In en, this message translates to:
  /// **'Home Office'**
  String get architectZoneCatOffice;

  /// Zone category custom space
  ///
  /// In en, this message translates to:
  /// **'Custom Space'**
  String get architectZoneCatCustom;

  /// Single casement window preset name
  ///
  /// In en, this message translates to:
  /// **'Single casement window'**
  String get architectFenestrationPresetSingleCasement;

  /// Double casement window preset name
  ///
  /// In en, this message translates to:
  /// **'Double casement window'**
  String get architectFenestrationPresetDoubleCasement;

  /// Double casement window with casing preset name
  ///
  /// In en, this message translates to:
  /// **'Double casement with casing'**
  String get architectFenestrationPresetDoubleWithCasing;

  /// Triple casement window preset name
  ///
  /// In en, this message translates to:
  /// **'Triple casement window'**
  String get architectFenestrationPresetTripleCasement;

  /// Window with transom preset name
  ///
  /// In en, this message translates to:
  /// **'Window with transom'**
  String get architectFenestrationPresetWithTransom;

  /// Interior door preset name
  ///
  /// In en, this message translates to:
  /// **'Interior door'**
  String get architectFenestrationPresetDoorInterior;

  /// Exterior entrance door with casing preset name
  ///
  /// In en, this message translates to:
  /// **'Entrance door with casing'**
  String get architectFenestrationPresetDoorEntranceCasing;

  /// Glazed balcony door preset name
  ///
  /// In en, this message translates to:
  /// **'Glazed balcony door'**
  String get architectFenestrationPresetDoorBalconyGlass;

  /// Balcony door combo preset with door on left and window on right
  ///
  /// In en, this message translates to:
  /// **'Balcony door with right window'**
  String get architectFenestrationPresetBalconyDoorRight;

  /// Balcony door combo preset with window on left and door on right
  ///
  /// In en, this message translates to:
  /// **'Balcony door with left window'**
  String get architectFenestrationPresetBalconyDoorLeft;

  /// Portal combo preset with door centered between two windows or vitrines
  ///
  /// In en, this message translates to:
  /// **'Portal door between side windows'**
  String get architectFenestrationPresetPortalDoorCenter;

  /// Toggle for casing trim around door or window
  ///
  /// In en, this message translates to:
  /// **'Casing around opening'**
  String get architectCasingToggle;

  /// Short casing label for toolbar chip
  ///
  /// In en, this message translates to:
  /// **'Casing'**
  String get architectDoorCasing;

  /// Button label to open library dialog from element properties
  ///
  /// In en, this message translates to:
  /// **'Browse library...'**
  String get architectBrowseLibrary;

  /// Parapet wall type name with handrail pipe
  ///
  /// In en, this message translates to:
  /// **'Parapet {thickness} cm (pipe h={height}m)'**
  String architectWallParapetPipe(int thickness, String height);

  /// Parapet wall type name with concrete cap
  ///
  /// In en, this message translates to:
  /// **'Parapet {thickness} cm (cap h={height}m)'**
  String architectWallParapetCap(int thickness, String height);

  /// No description provided for @stairShape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get stairShape;

  /// No description provided for @stairStraight.
  ///
  /// In en, this message translates to:
  /// **'Straight'**
  String get stairStraight;

  /// No description provided for @stairQuarterTurn.
  ///
  /// In en, this message translates to:
  /// **'L-shaped'**
  String get stairQuarterTurn;

  /// No description provided for @stairHalfTurn.
  ///
  /// In en, this message translates to:
  /// **'U-shaped'**
  String get stairHalfTurn;

  /// No description provided for @stairSpiral.
  ///
  /// In en, this message translates to:
  /// **'Spiral'**
  String get stairSpiral;

  /// No description provided for @stairSpiralOverlap.
  ///
  /// In en, this message translates to:
  /// **'Overlapping spiral'**
  String get stairSpiralOverlap;

  /// No description provided for @stairWinders.
  ///
  /// In en, this message translates to:
  /// **'Winder treads'**
  String get stairWinders;

  /// No description provided for @stairWindersHelp.
  ///
  /// In en, this message translates to:
  /// **'Replace the landing with winding treads. Automatically select the count and clear inner radius, targeting at least 23 cm on the line 30 cm from the narrow end. Code applicability depends on use and evacuation. Winders do not replace a landing required by flight rise.'**
  String get stairWindersHelp;

  /// No description provided for @stairWinderCorner.
  ///
  /// In en, this message translates to:
  /// **'At corner'**
  String get stairWinderCorner;

  /// No description provided for @stairWinderCornerTread.
  ///
  /// In en, this message translates to:
  /// **'Tread'**
  String get stairWinderCornerTread;

  /// No description provided for @stairWinderCornerRiser.
  ///
  /// In en, this message translates to:
  /// **'Riser'**
  String get stairWinderCornerRiser;

  /// No description provided for @stairWinderCornerHelp.
  ///
  /// In en, this message translates to:
  /// **'Tread: one tread spans the outer corner. Riser: the boundary between two treads follows the angle bisector. Both layouts have a clear inner radius; supports and reinforcement require separate design.'**
  String get stairWinderCornerHelp;

  /// No description provided for @stairWinderCount.
  ///
  /// In en, this message translates to:
  /// **'Treads per 90°'**
  String get stairWinderCount;

  /// No description provided for @stairWinderCountAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic winder count'**
  String get stairWinderCountAuto;

  /// No description provided for @stairWinderRadiusAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic winder radius'**
  String get stairWinderRadiusAuto;

  /// No description provided for @stairOverlapHelp.
  ///
  /// In en, this message translates to:
  /// **'More than one revolution. Head clearance between overlapping parts accounts for concrete and finish thickness.'**
  String get stairOverlapHelp;

  /// No description provided for @stairTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get stairTurnLeft;

  /// No description provided for @stairTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get stairTurnRight;

  /// No description provided for @stairPlaceHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick the outer corner of the first step, then point the ascent direction. Length and steps are calculated from the floor levels.'**
  String get stairPlaceHelp;

  /// No description provided for @stairCode.
  ///
  /// In en, this message translates to:
  /// **'Regulations'**
  String get stairCode;

  /// No description provided for @stairCodeBulgaria.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria · BG-2025.1'**
  String get stairCodeBulgaria;

  /// No description provided for @stairCodeGeometry.
  ///
  /// In en, this message translates to:
  /// **'Geometry only'**
  String get stairCodeGeometry;

  /// No description provided for @stairUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get stairUse;

  /// No description provided for @stairUsePrivate.
  ///
  /// In en, this message translates to:
  /// **'Within a dwelling'**
  String get stairUsePrivate;

  /// No description provided for @stairUseCommon.
  ///
  /// In en, this message translates to:
  /// **'New multifamily'**
  String get stairUseCommon;

  /// No description provided for @stairUsePublic.
  ///
  /// In en, this message translates to:
  /// **'Public building'**
  String get stairUsePublic;

  /// No description provided for @stairUseAssembly.
  ///
  /// In en, this message translates to:
  /// **'Public, over 200 people'**
  String get stairUseAssembly;

  /// No description provided for @stairUseOutdoor.
  ///
  /// In en, this message translates to:
  /// **'New urban route'**
  String get stairUseOutdoor;

  /// No description provided for @stairEvacuation.
  ///
  /// In en, this message translates to:
  /// **'Evacuation'**
  String get stairEvacuation;

  /// No description provided for @stairUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get stairUnspecified;

  /// No description provided for @stairNoEvacuation.
  ///
  /// In en, this message translates to:
  /// **'Not an escape stair'**
  String get stairNoEvacuation;

  /// No description provided for @stairUpTo15.
  ///
  /// In en, this message translates to:
  /// **'Up to 15 people'**
  String get stairUpTo15;

  /// No description provided for @stair16To50.
  ///
  /// In en, this message translates to:
  /// **'16–50 people'**
  String get stair16To50;

  /// No description provided for @stairOver50.
  ///
  /// In en, this message translates to:
  /// **'Over 50 people'**
  String get stairOver50;

  /// No description provided for @stairRise.
  ///
  /// In en, this message translates to:
  /// **'Total rise'**
  String get stairRise;

  /// No description provided for @stairFollowStoreys.
  ///
  /// In en, this message translates to:
  /// **'From floor levels'**
  String get stairFollowStoreys;

  /// No description provided for @stairHeightMode.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get stairHeightMode;

  /// No description provided for @stairHeightManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get stairHeightManual;

  /// No description provided for @stairHeightModeHelp.
  ///
  /// In en, this message translates to:
  /// **'From floor levels: calculate the rise from the specified start to the upper floor. Manual: enter the total rise; it stays fixed when floor levels change.'**
  String get stairHeightModeHelp;

  /// No description provided for @stairStartOffset.
  ///
  /// In en, this message translates to:
  /// **'Start offset'**
  String get stairStartOffset;

  /// No description provided for @stairStartOffsetHelp.
  ///
  /// In en, this message translates to:
  /// **'Starting height relative to the floor level. 0 starts on the floor, positive values above it and negative values below it. Total rise is measured from this start.'**
  String get stairStartOffsetHelp;

  /// No description provided for @stairUpperStorey.
  ///
  /// In en, this message translates to:
  /// **'Upper floor'**
  String get stairUpperStorey;

  /// No description provided for @stairFloorHeight.
  ///
  /// In en, this message translates to:
  /// **'Floor height'**
  String get stairFloorHeight;

  /// No description provided for @stairClearWidth.
  ///
  /// In en, this message translates to:
  /// **'Clear width'**
  String get stairClearWidth;

  /// No description provided for @stairRisers.
  ///
  /// In en, this message translates to:
  /// **'Risers'**
  String get stairRisers;

  /// No description provided for @stairRiser.
  ///
  /// In en, this message translates to:
  /// **'Riser height'**
  String get stairRiser;

  /// No description provided for @stairGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get stairGoing;

  /// No description provided for @stairLanding.
  ///
  /// In en, this message translates to:
  /// **'Landing depth'**
  String get stairLanding;

  /// No description provided for @stairInnerRadius.
  ///
  /// In en, this message translates to:
  /// **'Clear inner radius'**
  String get stairInnerRadius;

  /// No description provided for @stairSweep.
  ///
  /// In en, this message translates to:
  /// **'Turn angle'**
  String get stairSweep;

  /// No description provided for @stairAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get stairAutomatic;

  /// No description provided for @stairFit.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get stairFit;

  /// No description provided for @stairFitHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose risers, going, width and inner radius for the selected profile. The existing height and direction are retained.'**
  String get stairFitHelp;

  /// No description provided for @stairAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get stairAdvanced;

  /// No description provided for @stairChecks.
  ///
  /// In en, this message translates to:
  /// **'Checks'**
  String get stairChecks;

  /// No description provided for @stairCheckPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get stairCheckPass;

  /// No description provided for @stairCheckError.
  ///
  /// In en, this message translates to:
  /// **'Violation'**
  String get stairCheckError;

  /// No description provided for @stairCheckAdvice.
  ///
  /// In en, this message translates to:
  /// **'Comfort advice'**
  String get stairCheckAdvice;

  /// No description provided for @stairCheckReview.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get stairCheckReview;

  /// No description provided for @stairDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get stairDraft;

  /// No description provided for @stairDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'Drafts may contain violations and are drawn in red.'**
  String get stairDraftHelp;

  /// No description provided for @stairIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Geometric checks only. Headroom, handrails, finishes and the complete escape route require a project review.'**
  String get stairIncomplete;

  /// No description provided for @stairCheckSlope.
  ///
  /// In en, this message translates to:
  /// **'Flight slope'**
  String get stairCheckSlope;

  /// No description provided for @stairCheckFlightRise.
  ///
  /// In en, this message translates to:
  /// **'Rise per flight'**
  String get stairCheckFlightRise;

  /// No description provided for @stairCheckInner30.
  ///
  /// In en, this message translates to:
  /// **'Going at 30 cm'**
  String get stairCheckInner30;

  /// No description provided for @stairCheckInner.
  ///
  /// In en, this message translates to:
  /// **'Going at inner edge'**
  String get stairCheckInner;

  /// No description provided for @stairCheckDiameter.
  ///
  /// In en, this message translates to:
  /// **'Clear inner diameter'**
  String get stairCheckDiameter;

  /// No description provided for @stairCheckComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort · 2h + b'**
  String get stairCheckComfort;

  /// No description provided for @stairCheckCapacity.
  ///
  /// In en, this message translates to:
  /// **'Escape capacity and fire class'**
  String get stairCheckCapacity;

  /// No description provided for @stairCheckHeadroom.
  ///
  /// In en, this message translates to:
  /// **'Headroom and floor opening'**
  String get stairCheckHeadroom;

  /// No description provided for @stairCheckHandrails.
  ///
  /// In en, this message translates to:
  /// **'Guards and handrails'**
  String get stairCheckHandrails;

  /// No description provided for @stairCheckFinishes.
  ///
  /// In en, this message translates to:
  /// **'Nosings, tactile strips and finishes'**
  String get stairCheckFinishes;

  /// No description provided for @stairCheckAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessible use of spiral treads'**
  String get stairCheckAccessibility;

  /// No description provided for @stairCheckScope.
  ///
  /// In en, this message translates to:
  /// **'Additional applicable requirements'**
  String get stairCheckScope;

  /// No description provided for @stairCheckVersion.
  ///
  /// In en, this message translates to:
  /// **'Unrecognised rules version'**
  String get stairCheckVersion;

  /// No description provided for @stairCheckUpperStorey.
  ///
  /// In en, this message translates to:
  /// **'Check upper level: missing floor or rise outside 0–30 m'**
  String get stairCheckUpperStorey;

  /// No description provided for @stairRulesSources.
  ///
  /// In en, this message translates to:
  /// **'Regulatory sources'**
  String get stairRulesSources;

  /// No description provided for @stairFireSource.
  ///
  /// In en, this message translates to:
  /// **'Fire safety · Iз-1971, consolidated 2025'**
  String get stairFireSource;

  /// No description provided for @stairAccessSource.
  ///
  /// In en, this message translates to:
  /// **'Accessibility · РД-02-20-2/2021, Articles 18 and 55'**
  String get stairAccessSource;

  /// No description provided for @stairClearDimensionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Use finished clear widths between limiting handrail projections. For a spiral, the inner radius starts at the limiting inner edge or handrail projection.'**
  String get stairClearDimensionsHelp;

  /// No description provided for @stairUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Invalid stair dimensions. Check the entered values.'**
  String get stairUnsupported;

  /// No description provided for @stairLegacy.
  ///
  /// In en, this message translates to:
  /// **'Schematic stair. Recalculate to convert it to a parametric stair.'**
  String get stairLegacy;

  /// No description provided for @stairCheckGroupSteps.
  ///
  /// In en, this message translates to:
  /// **'Risers per group'**
  String get stairCheckGroupSteps;

  /// Notice when a wall protrudes past another wall
  ///
  /// In en, this message translates to:
  /// **'Wall overshoot: {distance} cm'**
  String architectWallOvershootDetected(int distance);

  /// Action to trim protruding wall stub
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get architectWallOvershootTrim;

  /// Action to keep protruding wall stub as is
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get architectWallOvershootDismiss;

  /// Feedback message after trimming wall overshoot
  ///
  /// In en, this message translates to:
  /// **'Wall corner trimmed ({distance} cm)'**
  String architectWallOvershootTrimmed(int distance);

  /// Tooltip for trimming wall overshoot
  ///
  /// In en, this message translates to:
  /// **'Trim protruding wall stub to corner'**
  String get architectWallOvershootTooltip;

  /// Radial menu action to join two walls
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get architectRadialJoin;

  /// Tooltip for join walls action
  ///
  /// In en, this message translates to:
  /// **'Join walls'**
  String get architectWallJoinTooltip;

  /// Instruction message when picking second wall to join
  ///
  /// In en, this message translates to:
  /// **'Select second wall to join'**
  String get architectWallJoinSelectSecond;

  /// Feedback message when walls are successfully joined
  ///
  /// In en, this message translates to:
  /// **'Walls joined'**
  String get architectWallJoinSuccess;

  /// Error message when walls cannot be joined
  ///
  /// In en, this message translates to:
  /// **'Walls cannot be joined'**
  String get architectWallJoinIncompatible;

  /// Tooltip for straightening an angled or crooked wall
  ///
  /// In en, this message translates to:
  /// **'Straighten'**
  String get architectWallStraighten;

  /// Feedback message when a wall is straightened to orthogonal axis
  ///
  /// In en, this message translates to:
  /// **'Wall straightened'**
  String get architectWallStraightened;

  /// Notice when a wall is already orthogonal
  ///
  /// In en, this message translates to:
  /// **'Wall is already straight'**
  String get architectWallAlreadyStraight;

  /// No description provided for @stairRailing.
  ///
  /// In en, this message translates to:
  /// **'Railing'**
  String get stairRailing;

  /// No description provided for @stairSmartRailingHelp.
  ///
  /// In en, this message translates to:
  /// **'Guard on open sides, handrail beside a full-height wall. Doors, windows and low walls keep the guard.'**
  String get stairSmartRailingHelp;

  /// No description provided for @stairLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get stairLabel;

  /// Count is the number of equal risers. Going and riser are formatted centimetres.
  ///
  /// In en, this message translates to:
  /// **'{count}R {going}/{riser} cm'**
  String stairPlanStepsLabel(int count, String going, String riser);

  /// No description provided for @stairPlanRiseLabel.
  ///
  /// In en, this message translates to:
  /// **'H={height} m'**
  String stairPlanRiseLabel(String height);

  /// No description provided for @stairDetails.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get stairDetails;

  /// No description provided for @stairGuardHeight.
  ///
  /// In en, this message translates to:
  /// **'Guard height'**
  String get stairGuardHeight;

  /// No description provided for @stairHandrailHeight.
  ///
  /// In en, this message translates to:
  /// **'Handrail height'**
  String get stairHandrailHeight;

  /// No description provided for @stairConcreteThickness.
  ///
  /// In en, this message translates to:
  /// **'Concrete waist'**
  String get stairConcreteThickness;

  /// No description provided for @stairFinishThickness.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get stairFinishThickness;

  /// No description provided for @stairNosing.
  ///
  /// In en, this message translates to:
  /// **'Nosing'**
  String get stairNosing;

  /// No description provided for @stairDetailsHelp.
  ///
  /// In en, this message translates to:
  /// **'Waist thickness is vertical. Drawing dimensions only; verify structural thickness, handrail clear width and the applicable regulations.'**
  String get stairDetailsHelp;

  /// No description provided for @stairSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get stairSection;

  /// No description provided for @stairSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Pick two points in the plan to move and turn the section.'**
  String get stairSectionHint;

  /// No description provided for @stairSectionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset section'**
  String get stairSectionReset;

  /// No description provided for @stairSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'The section misses the stair. Pick two new points in the plan.'**
  String get stairSectionEmpty;

  /// No description provided for @stairSectionPlan.
  ///
  /// In en, this message translates to:
  /// **'Section in plan'**
  String get stairSectionPlan;

  /// No description provided for @stairSectionCutHeight.
  ///
  /// In en, this message translates to:
  /// **'Plan cut height'**
  String get stairSectionCutHeight;

  /// No description provided for @slabLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get slabLayers;

  /// No description provided for @slabAssembly.
  ///
  /// In en, this message translates to:
  /// **'Assembly'**
  String get slabAssembly;

  /// No description provided for @slabAbove.
  ///
  /// In en, this message translates to:
  /// **'Above concrete'**
  String get slabAbove;

  /// No description provided for @slabBelow.
  ///
  /// In en, this message translates to:
  /// **'Below concrete'**
  String get slabBelow;

  /// No description provided for @slabCore.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get slabCore;

  /// No description provided for @slabCoreOffset.
  ///
  /// In en, this message translates to:
  /// **'Concrete top offset'**
  String get slabCoreOffset;

  /// No description provided for @slabFinishedLevel.
  ///
  /// In en, this message translates to:
  /// **'Finished level'**
  String get slabFinishedLevel;

  /// No description provided for @slabBottomLevel.
  ///
  /// In en, this message translates to:
  /// **'Bottom level'**
  String get slabBottomLevel;

  /// No description provided for @slabPreset.
  ///
  /// In en, this message translates to:
  /// **'Load assembly'**
  String get slabPreset;

  /// No description provided for @slabAllUsages.
  ///
  /// In en, this message translates to:
  /// **'All uses'**
  String get slabAllUsages;

  /// No description provided for @slabOnlyThis.
  ///
  /// In en, this message translates to:
  /// **'Only this slab'**
  String get slabOnlyThis;

  /// No description provided for @slabShared.
  ///
  /// In en, this message translates to:
  /// **'Edit shared type'**
  String get slabShared;

  /// No description provided for @slabSharedHelp.
  ///
  /// In en, this message translates to:
  /// **'Saving updates every slab using this type. Choose Only this slab to detach a copy.'**
  String get slabSharedHelp;

  /// No description provided for @slabNewType.
  ///
  /// In en, this message translates to:
  /// **'New assembly'**
  String get slabNewType;

  /// No description provided for @slabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Personal library'**
  String get slabLibrary;

  /// No description provided for @slabLibrarySaved.
  ///
  /// In en, this message translates to:
  /// **'Assembly saved to library.'**
  String get slabLibrarySaved;

  /// No description provided for @slabSaveLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get slabSaveLibrary;

  /// No description provided for @slabDeleteLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete from library'**
  String get slabDeleteLibrary;

  /// No description provided for @slabLibraryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Assembly deleted from library.'**
  String get slabLibraryDeleted;

  /// No description provided for @slabDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from personal library?'**
  String slabDeleteConfirm(String name);

  /// No description provided for @slabLibraryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the library.'**
  String get slabLibraryFailed;

  /// No description provided for @slabPresetHelp.
  ///
  /// In en, this message translates to:
  /// **'Editable starting dimensions, not a calculation for this building. Foundation: waterproofing below concrete; ground floor: waterproofing above concrete. Cold attic: non-walkable insulation. Ceiling insulation: suspended lining. Roof and terrace presets include one slope field; junctions and drainage need separate detailing.'**
  String get slabPresetHelp;

  /// No description provided for @slabAddLayer.
  ///
  /// In en, this message translates to:
  /// **'Add layer'**
  String get slabAddLayer;

  /// No description provided for @slabEditLayer.
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get slabEditLayer;

  /// No description provided for @slabMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get slabMaterial;

  /// No description provided for @slabRole.
  ///
  /// In en, this message translates to:
  /// **'Function'**
  String get slabRole;

  /// No description provided for @slabThicknessMm.
  ///
  /// In en, this message translates to:
  /// **'Thickness (mm)'**
  String get slabThicknessMm;

  /// No description provided for @slabSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope (%)'**
  String get slabSlope;

  /// No description provided for @slabDirection.
  ///
  /// In en, this message translates to:
  /// **'Fall direction'**
  String get slabDirection;

  /// No description provided for @slabDirectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap two points in the plan preview, from high to low.'**
  String get slabDirectionHelp;

  /// No description provided for @slabDirectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a fall direction in the preview.'**
  String get slabDirectionRequired;

  /// No description provided for @slabInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check dimensions, names and slope. Only one upper layer may have a slope.'**
  String get slabInvalid;

  /// No description provided for @slabDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate layer'**
  String get slabDuplicate;

  /// No description provided for @slabMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get slabMoveUp;

  /// No description provided for @slabMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get slabMoveDown;

  /// No description provided for @slabFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get slabFinish;

  /// No description provided for @slabFinishTile.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get slabFinishTile;

  /// No description provided for @slabFinishParquet.
  ///
  /// In en, this message translates to:
  /// **'Parquet'**
  String get slabFinishParquet;

  /// No description provided for @slabFinishWet.
  ///
  /// In en, this message translates to:
  /// **'Wet room'**
  String get slabFinishWet;

  /// No description provided for @slabNaturalGround.
  ///
  /// In en, this message translates to:
  /// **'Natural ground'**
  String get slabNaturalGround;

  /// No description provided for @buildingSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get buildingSections;

  /// No description provided for @buildingSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get buildingSection;

  /// No description provided for @buildingSectionNew.
  ///
  /// In en, this message translates to:
  /// **'New section'**
  String get buildingSectionNew;

  /// No description provided for @buildingSectionCut.
  ///
  /// In en, this message translates to:
  /// **'Edit cut'**
  String get buildingSectionCut;

  /// No description provided for @buildingSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Set the cut line, then choose its viewing side.'**
  String get buildingSectionHint;

  /// No description provided for @buildingSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No elements intersect this cut.'**
  String get buildingSectionEmpty;

  /// No description provided for @slabDetail.
  ///
  /// In en, this message translates to:
  /// **'Floor detail'**
  String get slabDetail;

  /// No description provided for @slabDetailPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a slab, then place its labels.'**
  String get slabDetailPick;

  /// No description provided for @slabDetailMove.
  ///
  /// In en, this message translates to:
  /// **'Tap to place the labels.'**
  String get slabDetailMove;

  /// No description provided for @slabDetailLost.
  ///
  /// In en, this message translates to:
  /// **'Lost link'**
  String get slabDetailLost;

  /// No description provided for @slabDetailReattach.
  ///
  /// In en, this message translates to:
  /// **'Reattach'**
  String get slabDetailReattach;

  /// No description provided for @slabDetailHere.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get slabDetailHere;

  /// No description provided for @slabDetailSide.
  ///
  /// In en, this message translates to:
  /// **'Flip labels'**
  String get slabDetailSide;

  /// No description provided for @slabDetailRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove detail'**
  String get slabDetailRemove;

  /// No description provided for @slabSectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get slabSectionDelete;

  /// No description provided for @slabMatConcrete.
  ///
  /// In en, this message translates to:
  /// **'Reinforced concrete'**
  String get slabMatConcrete;

  /// Aerated concrete material
  ///
  /// In en, this message translates to:
  /// **'Aerated concrete'**
  String get slabMatAeratedConcrete;

  /// Timber or wooden floor joists material
  ///
  /// In en, this message translates to:
  /// **'Timber / joists'**
  String get slabMatTimber;

  /// Timber joist floor assembly preset
  ///
  /// In en, this message translates to:
  /// **'Timber Joist Floor (Гредоред)'**
  String get slabPresetTimberJoist;

  /// Structural scheme selection title
  ///
  /// In en, this message translates to:
  /// **'Structural Scheme'**
  String get architectStructuralScheme;

  /// Flat slab structural scheme
  ///
  /// In en, this message translates to:
  /// **'Flat Slab (Beamless)'**
  String get architectStructuralSchemeFlatSlab;

  /// Beam and slab structural scheme
  ///
  /// In en, this message translates to:
  /// **'Beam & Slab System'**
  String get architectStructuralSchemeBeamAndSlab;

  /// Sandwich panels structural scheme
  ///
  /// In en, this message translates to:
  /// **'Sandwich Panels'**
  String get architectStructuralSchemeSandwichPanels;

  /// Round logs timber structural scheme
  ///
  /// In en, this message translates to:
  /// **'Round Timber Logs'**
  String get architectStructuralSchemeRoundLogs;

  /// Light gauge stud frame structural scheme
  ///
  /// In en, this message translates to:
  /// **'Light Stud Frame'**
  String get architectStructuralSchemeStudFrame;

  /// Exterior perimeter drop beam height
  ///
  /// In en, this message translates to:
  /// **'Perimeter Drop Beam Height'**
  String get architectPerimeterBeamDepth;

  /// Help text for exterior perimeter drop beam height
  ///
  /// In en, this message translates to:
  /// **'Total depth of perimeter RC drop beams under the slab core'**
  String get architectPerimeterBeamDepthHelp;

  /// Aerated concrete hatch pattern
  ///
  /// In en, this message translates to:
  /// **'Aerated concrete'**
  String get hatchPatternAeratedConcrete;

  /// No description provided for @slabMatTile.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get slabMatTile;

  /// No description provided for @slabMatTileAdhesive.
  ///
  /// In en, this message translates to:
  /// **'Tile adhesive'**
  String get slabMatTileAdhesive;

  /// No description provided for @slabMatParquet.
  ///
  /// In en, this message translates to:
  /// **'Parquet'**
  String get slabMatParquet;

  /// No description provided for @slabMatUnderlay.
  ///
  /// In en, this message translates to:
  /// **'Parquet underlay'**
  String get slabMatUnderlay;

  /// No description provided for @slabMatScreed.
  ///
  /// In en, this message translates to:
  /// **'Cement screed'**
  String get slabMatScreed;

  /// No description provided for @slabMatPeFoil.
  ///
  /// In en, this message translates to:
  /// **'PE separating foil'**
  String get slabMatPeFoil;

  /// No description provided for @slabMatXps.
  ///
  /// In en, this message translates to:
  /// **'XPS'**
  String get slabMatXps;

  /// No description provided for @slabMatFloorInsulation.
  ///
  /// In en, this message translates to:
  /// **'Rigid floor insulation'**
  String get slabMatFloorInsulation;

  /// No description provided for @slabMatAcousticWool.
  ///
  /// In en, this message translates to:
  /// **'Impact sound insulation'**
  String get slabMatAcousticWool;

  /// No description provided for @slabMatMineralWool.
  ///
  /// In en, this message translates to:
  /// **'Mineral wool'**
  String get slabMatMineralWool;

  /// No description provided for @slabMatRoofInsulation.
  ///
  /// In en, this message translates to:
  /// **'Rigid roof insulation'**
  String get slabMatRoofInsulation;

  /// No description provided for @slabMatWaterproofing.
  ///
  /// In en, this message translates to:
  /// **'Waterproofing'**
  String get slabMatWaterproofing;

  /// No description provided for @slabMatVapourBarrier.
  ///
  /// In en, this message translates to:
  /// **'Vapour control layer'**
  String get slabMatVapourBarrier;

  /// No description provided for @slabMatBreathableMembrane.
  ///
  /// In en, this message translates to:
  /// **'Breathable protection'**
  String get slabMatBreathableMembrane;

  /// No description provided for @slabMatGeotextile.
  ///
  /// In en, this message translates to:
  /// **'Geotextile'**
  String get slabMatGeotextile;

  /// No description provided for @slabMatGravel.
  ///
  /// In en, this message translates to:
  /// **'Gravel ballast'**
  String get slabMatGravel;

  /// No description provided for @slabMatBallast.
  ///
  /// In en, this message translates to:
  /// **'Compacted aggregate'**
  String get slabMatBallast;

  /// No description provided for @slabMatCompactedFill.
  ///
  /// In en, this message translates to:
  /// **'Compacted fill'**
  String get slabMatCompactedFill;

  /// No description provided for @slabMatBlindingConcrete.
  ///
  /// In en, this message translates to:
  /// **'Blinding concrete'**
  String get slabMatBlindingConcrete;

  /// No description provided for @slabMatPlaster.
  ///
  /// In en, this message translates to:
  /// **'Ceiling plaster'**
  String get slabMatPlaster;

  /// No description provided for @slabMatProtectiveRender.
  ///
  /// In en, this message translates to:
  /// **'Reinforced protective render'**
  String get slabMatProtectiveRender;

  /// No description provided for @slabMatPlasterboard.
  ///
  /// In en, this message translates to:
  /// **'Plasterboard lining'**
  String get slabMatPlasterboard;

  /// No description provided for @slabMatAdhesive.
  ///
  /// In en, this message translates to:
  /// **'Insulation adhesive'**
  String get slabMatAdhesive;

  /// No description provided for @slabMatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom material'**
  String get slabMatCustom;

  /// No description provided for @slabUseFoundation.
  ///
  /// In en, this message translates to:
  /// **'Foundation slab'**
  String get slabUseFoundation;

  /// No description provided for @slabUseGround.
  ///
  /// In en, this message translates to:
  /// **'Ground-bearing floor'**
  String get slabUseGround;

  /// No description provided for @slabUseBasement.
  ///
  /// In en, this message translates to:
  /// **'Above basement'**
  String get slabUseBasement;

  /// No description provided for @slabUseIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate floor'**
  String get slabUseIntermediate;

  /// No description provided for @slabUseColdAttic.
  ///
  /// In en, this message translates to:
  /// **'Below cold attic'**
  String get slabUseColdAttic;

  /// No description provided for @slabUseInsulatedCeiling.
  ///
  /// In en, this message translates to:
  /// **'Insulation below slab'**
  String get slabUseInsulatedCeiling;

  /// No description provided for @slabUseWarmRoof.
  ///
  /// In en, this message translates to:
  /// **'Warm flat roof'**
  String get slabUseWarmRoof;

  /// No description provided for @slabUseInvertedRoof.
  ///
  /// In en, this message translates to:
  /// **'Inverted flat roof'**
  String get slabUseInvertedRoof;

  /// No description provided for @slabUseTerrace.
  ///
  /// In en, this message translates to:
  /// **'Terrace above heated space'**
  String get slabUseTerrace;

  /// No description provided for @slabRoleFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get slabRoleFinish;

  /// No description provided for @slabRoleAdhesive.
  ///
  /// In en, this message translates to:
  /// **'Bonding'**
  String get slabRoleAdhesive;

  /// No description provided for @slabRoleScreed.
  ///
  /// In en, this message translates to:
  /// **'Screed'**
  String get slabRoleScreed;

  /// No description provided for @slabRoleSeparation.
  ///
  /// In en, this message translates to:
  /// **'Separation'**
  String get slabRoleSeparation;

  /// No description provided for @slabRoleInsulation.
  ///
  /// In en, this message translates to:
  /// **'Thermal insulation'**
  String get slabRoleInsulation;

  /// No description provided for @slabRoleAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Sound insulation'**
  String get slabRoleAcoustic;

  /// No description provided for @slabRoleWaterproofing.
  ///
  /// In en, this message translates to:
  /// **'Waterproofing'**
  String get slabRoleWaterproofing;

  /// No description provided for @slabRoleVapourControl.
  ///
  /// In en, this message translates to:
  /// **'Vapour control'**
  String get slabRoleVapourControl;

  /// No description provided for @slabRoleSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get slabRoleSlope;

  /// No description provided for @slabRoleCeiling.
  ///
  /// In en, this message translates to:
  /// **'Ceiling finish'**
  String get slabRoleCeiling;

  /// No description provided for @slabRoleBase.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get slabRoleBase;

  /// No description provided for @slabRoleFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get slabRoleFill;

  /// No description provided for @slabRoleProtection.
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get slabRoleProtection;

  /// No description provided for @architectFacades.
  ///
  /// In en, this message translates to:
  /// **'Elevations'**
  String get architectFacades;

  /// No description provided for @architectFacade.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectFacade;

  /// No description provided for @architectFacadeNew.
  ///
  /// In en, this message translates to:
  /// **'New elevation'**
  String get architectFacadeNew;

  /// No description provided for @architectFacadeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit marker'**
  String get architectFacadeEdit;

  /// No description provided for @architectFacadeReverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse view'**
  String get architectFacadeReverse;

  /// No description provided for @architectFacadePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get architectFacadePlan;

  /// No description provided for @architectFacadeStartHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the first marker point outside the building.'**
  String get architectFacadeStartHint;

  /// No description provided for @architectFacadeEndHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the second point, parallel to the facade.'**
  String get architectFacadeEndHint;

  /// No description provided for @architectFacadeSideHint.
  ///
  /// In en, this message translates to:
  /// **'Tap on the building side to set the viewing direction.'**
  String get architectFacadeSideHint;

  /// No description provided for @architectFacadeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No building elements in this view. Check the marker span and direction.'**
  String get architectFacadeEmpty;

  /// No description provided for @architectNorth.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get architectNorth;

  /// No description provided for @architectNorthPlace.
  ///
  /// In en, this message translates to:
  /// **'Place north'**
  String get architectNorthPlace;

  /// No description provided for @architectNorthHelp.
  ///
  /// In en, this message translates to:
  /// **'Rotate the symbol to set north. Elevation names update automatically.'**
  String get architectNorthHelp;

  /// No description provided for @architectNorthAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get architectNorthAngle;

  /// No description provided for @architectNorthAngleHelp.
  ///
  /// In en, this message translates to:
  /// **'Clockwise angle from plan-up (0°).'**
  String get architectNorthAngleHelp;

  /// No description provided for @architectNorthInvalidAngle.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid angle.'**
  String get architectNorthInvalidAngle;

  /// No description provided for @architectNorthPositionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the north symbol position.'**
  String get architectNorthPositionHint;

  /// No description provided for @architectNorthDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a point towards north.'**
  String get architectNorthDirectionHint;

  /// No description provided for @architectNorthSymbolLetter.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get architectNorthSymbolLetter;

  /// No description provided for @architectFacadeNorth.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get architectFacadeNorth;

  /// No description provided for @architectFacadeNorthEast.
  ///
  /// In en, this message translates to:
  /// **'Northeast'**
  String get architectFacadeNorthEast;

  /// No description provided for @architectFacadeEast.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get architectFacadeEast;

  /// No description provided for @architectFacadeSouthEast.
  ///
  /// In en, this message translates to:
  /// **'Southeast'**
  String get architectFacadeSouthEast;

  /// No description provided for @architectFacadeSouth.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get architectFacadeSouth;

  /// No description provided for @architectFacadeSouthWest.
  ///
  /// In en, this message translates to:
  /// **'Southwest'**
  String get architectFacadeSouthWest;

  /// No description provided for @architectFacadeWest.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get architectFacadeWest;

  /// No description provided for @architectFacadeNorthWest.
  ///
  /// In en, this message translates to:
  /// **'Northwest'**
  String get architectFacadeNorthWest;

  /// No description provided for @architectToolRoof.
  ///
  /// In en, this message translates to:
  /// **'Roof'**
  String get architectToolRoof;

  /// No description provided for @architectRoofs.
  ///
  /// In en, this message translates to:
  /// **'Roofs'**
  String get architectRoofs;

  /// No description provided for @architectRoofPlane.
  ///
  /// In en, this message translates to:
  /// **'Roof plane'**
  String get architectRoofPlane;

  /// No description provided for @architectRoofDrawRect.
  ///
  /// In en, this message translates to:
  /// **'Rect'**
  String get architectRoofDrawRect;

  /// No description provided for @architectRoofDrawPoly.
  ///
  /// In en, this message translates to:
  /// **'Poly'**
  String get architectRoofDrawPoly;

  /// No description provided for @architectRoofAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto roof'**
  String get architectRoofAuto;

  /// No description provided for @architectRoofAutoGable.
  ///
  /// In en, this message translates to:
  /// **'Gable'**
  String get architectRoofAutoGable;

  /// No description provided for @architectRoofAutoHip.
  ///
  /// In en, this message translates to:
  /// **'Hip'**
  String get architectRoofAutoHip;

  /// No description provided for @architectRoofAutoShed.
  ///
  /// In en, this message translates to:
  /// **'Shed'**
  String get architectRoofAutoShed;

  /// No description provided for @architectRoofAutoFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get architectRoofAutoFlat;

  /// No description provided for @architectRoofAutoCreated.
  ///
  /// In en, this message translates to:
  /// **'Generated {count} roof planes'**
  String architectRoofAutoCreated(int count);

  /// No description provided for @architectRoofAutoNoWalls.
  ///
  /// In en, this message translates to:
  /// **'Draw exterior walls first to generate an automatic roof.'**
  String get architectRoofAutoNoWalls;

  /// No description provided for @architectRoofSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get architectRoofSlope;

  /// No description provided for @architectRoofOverhang.
  ///
  /// In en, this message translates to:
  /// **'Eaves'**
  String get architectRoofOverhang;

  /// No description provided for @architectRoofManualSupport.
  ///
  /// In en, this message translates to:
  /// **'Manual support position'**
  String get architectRoofManualSupport;

  /// No description provided for @architectRoofSupportDistance.
  ///
  /// In en, this message translates to:
  /// **'From eaves'**
  String get architectRoofSupportDistance;

  /// No description provided for @architectRoofManualSupportHelp.
  ///
  /// In en, this message translates to:
  /// **'Horizontal distance from the eaves edge to the centre of the ring beam and wall plate. Uncheck to follow the supporting wall automatically.'**
  String get architectRoofManualSupportHelp;

  /// No description provided for @architectRoofSupportDistanceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a distance within the roof plane.'**
  String get architectRoofSupportDistanceInvalid;

  /// No description provided for @architectRoofBaseElev.
  ///
  /// In en, this message translates to:
  /// **'Eaves Z'**
  String get architectRoofBaseElev;

  /// No description provided for @architectRoofRidgeElev.
  ///
  /// In en, this message translates to:
  /// **'Ridge Z'**
  String get architectRoofRidgeElev;

  /// No description provided for @architectRoofSwitchEaves.
  ///
  /// In en, this message translates to:
  /// **'Next eaves'**
  String get architectRoofSwitchEaves;

  /// No description provided for @architectRoofSwitchEavesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch which edge is the lower eaves edge (or tap an edge on canvas)'**
  String get architectRoofSwitchEavesTooltip;

  /// No description provided for @architectRoofLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers & Timber'**
  String get architectRoofLayers;

  /// No description provided for @architectRoofLayersShort.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get architectRoofLayersShort;

  /// No description provided for @architectRoofPresetPitchedTiles.
  ///
  /// In en, this message translates to:
  /// **'Timber roof with clay tiles'**
  String get architectRoofPresetPitchedTiles;

  /// No description provided for @architectRoofPresetWarmPitched.
  ///
  /// In en, this message translates to:
  /// **'Insulated warm pitched roof'**
  String get architectRoofPresetWarmPitched;

  /// No description provided for @architectRoofPresetStandingSeam.
  ///
  /// In en, this message translates to:
  /// **'Standing seam metal roof'**
  String get architectRoofPresetStandingSeam;

  /// No description provided for @architectRoofPresetFlatWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm flat RC roof'**
  String get architectRoofPresetFlatWarm;

  /// No description provided for @architectRoofPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom roof assembly'**
  String get architectRoofPresetCustom;

  /// No description provided for @architectRoofRoleCovering.
  ///
  /// In en, this message translates to:
  /// **'Covering'**
  String get architectRoofRoleCovering;

  /// No description provided for @architectRoofRoleBattens.
  ///
  /// In en, this message translates to:
  /// **'Battens'**
  String get architectRoofRoleBattens;

  /// No description provided for @architectRoofRoleCounterBattens.
  ///
  /// In en, this message translates to:
  /// **'Counter-battens'**
  String get architectRoofRoleCounterBattens;

  /// No description provided for @architectRoofRoleUnderlayment.
  ///
  /// In en, this message translates to:
  /// **'Breathable membrane'**
  String get architectRoofRoleUnderlayment;

  /// No description provided for @architectRoofRoleBoarding.
  ///
  /// In en, this message translates to:
  /// **'Boarding / sheathing'**
  String get architectRoofRoleBoarding;

  /// No description provided for @architectRoofRoleRafters.
  ///
  /// In en, this message translates to:
  /// **'Rafters'**
  String get architectRoofRoleRafters;

  /// No description provided for @architectRoofRoleInsulation.
  ///
  /// In en, this message translates to:
  /// **'Thermal insulation'**
  String get architectRoofRoleInsulation;

  /// No description provided for @architectRoofRoleVapourBarrier.
  ///
  /// In en, this message translates to:
  /// **'Vapour barrier'**
  String get architectRoofRoleVapourBarrier;

  /// No description provided for @architectRoofRoleStructure.
  ///
  /// In en, this message translates to:
  /// **'Structural deck'**
  String get architectRoofRoleStructure;

  /// No description provided for @architectRoofRoleInterior.
  ///
  /// In en, this message translates to:
  /// **'Ceiling lining'**
  String get architectRoofRoleInterior;

  /// No description provided for @architectRoofMatClayTiles.
  ///
  /// In en, this message translates to:
  /// **'Clay roof tiles'**
  String get architectRoofMatClayTiles;

  /// No description provided for @architectRoofMatConcreteTiles.
  ///
  /// In en, this message translates to:
  /// **'Concrete tiles'**
  String get architectRoofMatConcreteTiles;

  /// No description provided for @architectRoofMatMetalSeam.
  ///
  /// In en, this message translates to:
  /// **'Standing seam metal'**
  String get architectRoofMatMetalSeam;

  /// No description provided for @architectRoofMatBitumenShingles.
  ///
  /// In en, this message translates to:
  /// **'Bitumen shingles'**
  String get architectRoofMatBitumenShingles;

  /// No description provided for @architectRoofMatTimberBoarding.
  ///
  /// In en, this message translates to:
  /// **'Timber boarding'**
  String get architectRoofMatTimberBoarding;

  /// No description provided for @architectRoofMatOsb.
  ///
  /// In en, this message translates to:
  /// **'OSB sheathing'**
  String get architectRoofMatOsb;

  /// No description provided for @architectRoofMatBreathableMembrane.
  ///
  /// In en, this message translates to:
  /// **'Breathable membrane'**
  String get architectRoofMatBreathableMembrane;

  /// No description provided for @architectRoofMatVapourBarrier.
  ///
  /// In en, this message translates to:
  /// **'Vapour barrier foil'**
  String get architectRoofMatVapourBarrier;

  /// No description provided for @architectRoofMatMineralWool.
  ///
  /// In en, this message translates to:
  /// **'Mineral wool'**
  String get architectRoofMatMineralWool;

  /// No description provided for @architectRoofMatXps.
  ///
  /// In en, this message translates to:
  /// **'XPS insulation'**
  String get architectRoofMatXps;

  /// No description provided for @architectRoofMatWaterproofing.
  ///
  /// In en, this message translates to:
  /// **'Waterproofing membrane'**
  String get architectRoofMatWaterproofing;

  /// No description provided for @architectRoofMatSlopeScreed.
  ///
  /// In en, this message translates to:
  /// **'Slope screed'**
  String get architectRoofMatSlopeScreed;

  /// No description provided for @architectRoofMatRcSlab.
  ///
  /// In en, this message translates to:
  /// **'Reinforced concrete'**
  String get architectRoofMatRcSlab;

  /// No description provided for @architectRoofMatPlasterboard.
  ///
  /// In en, this message translates to:
  /// **'Gypsum plasterboard'**
  String get architectRoofMatPlasterboard;

  /// No description provided for @architectRoofTimberSection.
  ///
  /// In en, this message translates to:
  /// **'Timber carpentry & framing'**
  String get architectRoofTimberSection;

  /// No description provided for @architectRoofBattensLabel.
  ///
  /// In en, this message translates to:
  /// **'Battens'**
  String get architectRoofBattensLabel;

  /// No description provided for @architectRoofCounterBattensLabel.
  ///
  /// In en, this message translates to:
  /// **'Counter-battens'**
  String get architectRoofCounterBattensLabel;

  /// No description provided for @architectRoofRaftersLabel.
  ///
  /// In en, this message translates to:
  /// **'Rafters'**
  String get architectRoofRaftersLabel;

  /// No description provided for @architectRoofWallPlateLabel.
  ///
  /// In en, this message translates to:
  /// **'Wall plate (Mauerlat)'**
  String get architectRoofWallPlateLabel;

  /// No description provided for @architectRoofRidgePurlinLabel.
  ///
  /// In en, this message translates to:
  /// **'Ridge purlin'**
  String get architectRoofRidgePurlinLabel;

  /// No description provided for @architectRoofFasciaLabel.
  ///
  /// In en, this message translates to:
  /// **'Fascia board at eaves'**
  String get architectRoofFasciaLabel;

  /// No description provided for @architectRoofEavesCutLabel.
  ///
  /// In en, this message translates to:
  /// **'Eaves cut style'**
  String get architectRoofEavesCutLabel;

  /// No description provided for @architectRoofEavesCutPlumb.
  ///
  /// In en, this message translates to:
  /// **'Vertical (plumb)'**
  String get architectRoofEavesCutPlumb;

  /// No description provided for @architectRoofEavesCutSquare.
  ///
  /// In en, this message translates to:
  /// **'Square to slope'**
  String get architectRoofEavesCutSquare;

  /// No description provided for @architectRoofEavesCutBox.
  ///
  /// In en, this message translates to:
  /// **'Boxed soffit'**
  String get architectRoofEavesCutBox;

  /// No description provided for @architectRoofStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get architectRoofStepLabel;

  /// No description provided for @architectRoofHintStart.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to pick first roof corner, or use Auto roof.'**
  String get architectRoofHintStart;

  /// No description provided for @architectRoofHintNext.
  ///
  /// In en, this message translates to:
  /// **'Pick next corner ({count} pts). Tap Finish to close.'**
  String architectRoofHintNext(int count);

  /// No description provided for @architectRoofSectionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Roof assembly'**
  String get architectRoofSectionDetailTitle;

  /// No description provided for @architectSectionStartHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the start of the cut.'**
  String get architectSectionStartHint;

  /// No description provided for @architectViewEndHint.
  ///
  /// In en, this message translates to:
  /// **'Set the end using the alignment guides.'**
  String get architectViewEndHint;

  /// No description provided for @architectViewDirectionHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the viewing side and click the far boundary.'**
  String get architectViewDirectionHint;

  /// No description provided for @architectSectionNumber.
  ///
  /// In en, this message translates to:
  /// **'Section {number}'**
  String architectSectionNumber(int number);

  /// No description provided for @architectManageViews.
  ///
  /// In en, this message translates to:
  /// **'Manage views'**
  String get architectManageViews;

  /// No description provided for @architectViewDrawingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a view from the menu.'**
  String get architectViewDrawingEmpty;

  /// Dynamic clearance dimension from door or window jamb to adjacent opening or wall
  ///
  /// In en, this message translates to:
  /// **'Opening clearance'**
  String get architectOpeningClearance;

  /// Snap label when door or window position snaps to a masonry multiple of wall core thickness
  ///
  /// In en, this message translates to:
  /// **'Modular step ({step} cm)'**
  String architectOpeningModularSnap(int step);

  /// No description provided for @architectRoofSetEavesHere.
  ///
  /// In en, this message translates to:
  /// **'Eaves here'**
  String get architectRoofSetEavesHere;

  /// No description provided for @architectRoofSetEavesHereTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set the selected roof edge as the lower eaves edge (slope rises from here)'**
  String get architectRoofSetEavesHereTooltip;

  /// No description provided for @architectRoofFlipSlope.
  ///
  /// In en, this message translates to:
  /// **'Flip 180°'**
  String get architectRoofFlipSlope;

  /// No description provided for @architectRoofFlipSlopeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reverse the roof slope direction by 180°'**
  String get architectRoofFlipSlopeTooltip;

  /// No description provided for @architectRoofRotateSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope dir'**
  String get architectRoofRotateSlope;

  /// No description provided for @architectRoofAttachToWalls.
  ///
  /// In en, this message translates to:
  /// **'Attach to wall top'**
  String get architectRoofAttachToWalls;

  /// No description provided for @architectRoofAttachToWallsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-align roof structure to highest supporting walls with constructive eaves detail'**
  String get architectRoofAttachToWallsSubtitle;

  /// No description provided for @architectRoofAlignOnce.
  ///
  /// In en, this message translates to:
  /// **'Align to walls'**
  String get architectRoofAlignOnce;

  /// No description provided for @architectRoofAlignOnceHelp.
  ///
  /// In en, this message translates to:
  /// **'Set the roof height once from the supporting walls. Manual moves keep their saved height.'**
  String get architectRoofAlignOnceHelp;

  /// No description provided for @architectRoofRingBeamLabel.
  ///
  /// In en, this message translates to:
  /// **'10 cm concrete ring beam'**
  String get architectRoofRingBeamLabel;

  /// No description provided for @architectRoofMetalFlashingLabel.
  ///
  /// In en, this message translates to:
  /// **'Metal flashing (drip edge)'**
  String get architectRoofMetalFlashingLabel;

  /// No description provided for @architectRoofMoveVerticalAction.
  ///
  /// In en, this message translates to:
  /// **'Move up / down'**
  String get architectRoofMoveVerticalAction;

  /// No description provided for @architectRoofSnapToWallsAction.
  ///
  /// In en, this message translates to:
  /// **'Snap to walls'**
  String get architectRoofSnapToWallsAction;

  /// No description provided for @architectRoofPropertiesAction.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get architectRoofPropertiesAction;

  /// No description provided for @architectRoofPlan.
  ///
  /// In en, this message translates to:
  /// **'Roof Lines'**
  String get architectRoofPlan;

  /// No description provided for @architectAddRoofPlan.
  ///
  /// In en, this message translates to:
  /// **'Add Roof Lines'**
  String get architectAddRoofPlan;

  /// No description provided for @architectRoofPlanUnderlay.
  ///
  /// In en, this message translates to:
  /// **'Perimeter wall underlay'**
  String get architectRoofPlanUnderlay;

  /// No description provided for @architectRoofPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top-level roof plan with dashed perimeter wall lines'**
  String get architectRoofPlanSubtitle;

  /// No description provided for @architectRoofLowerLevelBadge.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String architectRoofLowerLevelBadge(String level);

  /// No description provided for @architectRoofDrawMultiPitch.
  ///
  /// In en, this message translates to:
  /// **'Multi-pitch'**
  String get architectRoofDrawMultiPitch;

  /// No description provided for @architectRoofDrawMansard.
  ///
  /// In en, this message translates to:
  /// **'Mansard'**
  String get architectRoofDrawMansard;

  /// No description provided for @architectRoofIsMansard.
  ///
  /// In en, this message translates to:
  /// **'Mansard (Gambrel)'**
  String get architectRoofIsMansard;

  /// No description provided for @architectRoofMakeMansard.
  ///
  /// In en, this message translates to:
  /// **'Make Mansard'**
  String get architectRoofMakeMansard;

  /// No description provided for @architectRoofUpperSlope.
  ///
  /// In en, this message translates to:
  /// **'Upper slope'**
  String get architectRoofUpperSlope;

  /// No description provided for @architectRoofBreakDistance.
  ///
  /// In en, this message translates to:
  /// **'Knuckle'**
  String get architectRoofBreakDistance;

  /// No description provided for @architectRoofMansardKnuckleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drag to adjust the Mansard knuckle line'**
  String get architectRoofMansardKnuckleTooltip;

  /// No description provided for @architectRoofKnucklePurlin.
  ///
  /// In en, this message translates to:
  /// **'Mansard purlin'**
  String get architectRoofKnucklePurlin;

  /// No description provided for @architectRoofSnap45Degrees.
  ///
  /// In en, this message translates to:
  /// **'45° Hip / Ridge'**
  String get architectRoofSnap45Degrees;

  /// No description provided for @architectRoofLinkedSlopes.
  ///
  /// In en, this message translates to:
  /// **'Linked slopes'**
  String get architectRoofLinkedSlopes;

  /// No description provided for @architectRoofLinkedSlopesTooltip.
  ///
  /// In en, this message translates to:
  /// **'All roof planes in this group share the same slope and eaves height'**
  String get architectRoofLinkedSlopesTooltip;

  /// No description provided for @architectRoofIndependentSlope.
  ///
  /// In en, this message translates to:
  /// **'Independent slope'**
  String get architectRoofIndependentSlope;

  /// No description provided for @architectRoofIndependentSlopeTooltip.
  ///
  /// In en, this message translates to:
  /// **'This roof plane has an independent slope (unlocked from group)'**
  String get architectRoofIndependentSlopeTooltip;

  /// No description provided for @architectRoofToggleSlopeLockTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle linked group slope vs independent slope'**
  String get architectRoofToggleSlopeLockTooltip;

  /// No description provided for @architectRoofMatchRidge.
  ///
  /// In en, this message translates to:
  /// **'Match ridge'**
  String get architectRoofMatchRidge;

  /// No description provided for @architectRoofMatchRidgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adjust slope to match the ridge height of adjacent roofs'**
  String get architectRoofMatchRidgeTooltip;

  /// No description provided for @architectRoofRidgeHeightMatched.
  ///
  /// In en, this message translates to:
  /// **'Slope adjusted to {degrees}° to match ridge height {height}m'**
  String architectRoofRidgeHeightMatched(String degrees, String height);

  /// No description provided for @architectRoofSnapHipAngle.
  ///
  /// In en, this message translates to:
  /// **'{angle}° Hip / Valley'**
  String architectRoofSnapHipAngle(String angle);

  /// Snap label for intersection of converging hip rays
  ///
  /// In en, this message translates to:
  /// **'Hip intersection (45°)'**
  String get architectRoofSnapHipIntersection;

  /// Snap label for hip ray intersecting corner 45 guide
  ///
  /// In en, this message translates to:
  /// **'Corner hip intersection (45°)'**
  String get architectRoofSnapCornerHipIntersection;

  /// Snap label for hip ray intersecting perpendicular from corner
  ///
  /// In en, this message translates to:
  /// **'Perpendicular to inner corner'**
  String get architectRoofSnapPerpToCorner;

  /// Snap label for hip ray intersecting ridge parallel guide
  ///
  /// In en, this message translates to:
  /// **'Ridge / edge alignment'**
  String get architectRoofSnapRidgeAlignment;

  /// 3D orbit navigation tooltip
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get cad3dOrbit;

  /// 3D pan navigation tooltip
  ///
  /// In en, this message translates to:
  /// **'Pan'**
  String get cad3dPan;

  /// 3D walkthrough navigation tooltip
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get cad3dWalk;

  /// Prefer GPU texture rendering with native depth fallback
  ///
  /// In en, this message translates to:
  /// **'Accelerated 3D'**
  String get cad3dNativeDepthOn;

  /// Canvas fallback rendering option
  ///
  /// In en, this message translates to:
  /// **'Compatibility mode'**
  String get cad3dNativeDepthOff;

  /// Shaded 3D display style
  ///
  /// In en, this message translates to:
  /// **'Shaded'**
  String get cad3dShadingSmooth;

  /// Flat shaded 3D display style
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get cad3dShadingFlat;

  /// Transparent 3D display style
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get cad3dShadingXray;

  /// 3D camera preset menu tooltip
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get cad3dCamera;

  /// Invert vertical orbit and look input
  ///
  /// In en, this message translates to:
  /// **'Invert vertical look'**
  String get cad3dInvertY;

  /// Isometric 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Isometric'**
  String get cad3dViewIsometric;

  /// Top 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get cad3dViewTop;

  /// Front 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get cad3dViewFront;

  /// Right 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get cad3dViewRight;

  /// Bottom 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get cad3dViewBottom;

  /// Back 3D camera preset
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get cad3dViewBack;

  /// Blueprint 3D background theme
  ///
  /// In en, this message translates to:
  /// **'Blueprint'**
  String get cad3dThemeBlueprint;

  /// Light studio 3D background theme
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get cad3dThemeStudio;

  /// Black 3D background theme
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get cad3dThemeBlack;

  /// White 3D background theme
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get cad3dThemeWhite;

  /// No description provided for @architectProjectionInvalid.
  ///
  /// In en, this message translates to:
  /// **'The element does not fit. Check the opening, host and clearances.'**
  String get architectProjectionInvalid;

  /// No description provided for @architectProjectionLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get architectProjectionLeft;

  /// No description provided for @architectProjectionRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get architectProjectionRight;

  /// No description provided for @architectProjectionHead.
  ///
  /// In en, this message translates to:
  /// **'To slab'**
  String get architectProjectionHead;

  /// No description provided for @architectProjectionHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Move sideways'**
  String get architectProjectionHorizontal;

  /// No description provided for @architectProjectionAlignSill.
  ///
  /// In en, this message translates to:
  /// **'Align sills'**
  String get architectProjectionAlignSill;

  /// No description provided for @architectProjectionAlignHead.
  ///
  /// In en, this message translates to:
  /// **'Align heads'**
  String get architectProjectionAlignHead;

  /// No description provided for @architectProjectionNoSlab.
  ///
  /// In en, this message translates to:
  /// **'No upper slab'**
  String get architectProjectionNoSlab;

  /// No description provided for @architectProjectionAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left edges'**
  String get architectProjectionAlignLeft;

  /// No description provided for @architectProjectionAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right edges'**
  String get architectProjectionAlignRight;

  /// No description provided for @architectDistancePrecision.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get architectDistancePrecision;

  /// Example label in architect wizard
  ///
  /// In en, this message translates to:
  /// **'Example:'**
  String get architectWizardExample;

  /// No description provided for @architectWizardStoreysShort.
  ///
  /// In en, this message translates to:
  /// **'Storeys'**
  String get architectWizardStoreysShort;

  /// No description provided for @architectWizardElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectWizardElevation;

  /// No description provided for @architectWizardHeight.
  ///
  /// In en, this message translates to:
  /// **'H='**
  String get architectWizardHeight;

  /// No description provided for @architectWizardStoreyHeightHelp.
  ///
  /// In en, this message translates to:
  /// **'Height to the next storey, measured from finished floor to finished floor. Changing height moves the storeys above. Floor finishes and ceilings affect clear height separately.'**
  String get architectWizardStoreyHeightHelp;

  /// No description provided for @architectWizardElevationHelp.
  ///
  /// In en, this message translates to:
  /// **'Finished floor elevation relative to project zero. Editing an elevation keeps the other levels in place and adjusts the adjacent heights.'**
  String get architectWizardElevationHelp;

  /// No description provided for @architectWizardInvalidLevel.
  ///
  /// In en, this message translates to:
  /// **'Check the levels and heights.'**
  String get architectWizardInvalidLevel;

  /// No description provided for @architectWizardCreateShort.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get architectWizardCreateShort;

  /// No description provided for @architectWizardHeightReference.
  ///
  /// In en, this message translates to:
  /// **'finished floor → finished floor'**
  String get architectWizardHeightReference;

  /// No description provided for @architectWallConcreteCode.
  ///
  /// In en, this message translates to:
  /// **'RC {thickness}'**
  String architectWallConcreteCode(String thickness);

  /// No description provided for @architectWallParapetCode.
  ///
  /// In en, this message translates to:
  /// **'P {thickness}'**
  String architectWallParapetCode(String thickness);

  /// No description provided for @architectWallTypeThicknessHint.
  ///
  /// In en, this message translates to:
  /// **'{name} · {thickness} cm'**
  String architectWallTypeThicknessHint(String name, String thickness);

  /// No description provided for @architectWallQuickCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get architectWallQuickCore;

  /// No description provided for @architectWallQuickInsulation.
  ///
  /// In en, this message translates to:
  /// **'Insulation'**
  String get architectWallQuickInsulation;

  /// No description provided for @architectWallInvalidThickness.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid thickness.'**
  String get architectWallInvalidThickness;

  /// No description provided for @architectWallQuickThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get architectWallQuickThickness;

  /// No description provided for @wallTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Wall types'**
  String get wallTypesTitle;

  /// No description provided for @wallNewType.
  ///
  /// In en, this message translates to:
  /// **'New type'**
  String get wallNewType;

  /// No description provided for @wallCompositionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wallCompositionName;

  /// No description provided for @wallLocation.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get wallLocation;

  /// No description provided for @wallExterior.
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get wallExterior;

  /// No description provided for @wallInterior.
  ///
  /// In en, this message translates to:
  /// **'Interior'**
  String get wallInterior;

  /// No description provided for @wallLayerCore.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get wallLayerCore;

  /// No description provided for @wallLayerInsulation.
  ///
  /// In en, this message translates to:
  /// **'Insulation'**
  String get wallLayerInsulation;

  /// No description provided for @wallLayerFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get wallLayerFinish;

  /// No description provided for @wallLayerRole.
  ///
  /// In en, this message translates to:
  /// **'Layer role'**
  String get wallLayerRole;

  /// No description provided for @wallLayerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add layer'**
  String get wallLayerAdd;

  /// No description provided for @wallLayerUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get wallLayerUp;

  /// No description provided for @wallLayerDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get wallLayerDown;

  /// No description provided for @wallLayerOutsideInside.
  ///
  /// In en, this message translates to:
  /// **'Outside → inside'**
  String get wallLayerOutsideInside;

  /// No description provided for @wallLayerSides.
  ///
  /// In en, this message translates to:
  /// **'A → B'**
  String get wallLayerSides;

  /// No description provided for @wallLayerInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use positive thicknesses and a continuous core.'**
  String get wallLayerInvalid;

  /// No description provided for @wallSelectedScope.
  ///
  /// In en, this message translates to:
  /// **'Selected walls only'**
  String get wallSelectedScope;

  /// No description provided for @wallTypeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to type ({count})'**
  String wallTypeApply(int count);

  /// No description provided for @wallTypeReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get wallTypeReplacement;

  /// No description provided for @wallTypeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete custom wall type \"{name}\"?'**
  String wallTypeDeleteConfirm(String name);

  /// No description provided for @wallTypeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Wall type deleted.'**
  String get wallTypeDeleted;

  /// No description provided for @wallTypeInUse.
  ///
  /// In en, this message translates to:
  /// **'Select a replacement for the walls using this type.'**
  String get wallTypeInUse;

  /// No description provided for @wallCompositionAction.
  ///
  /// In en, this message translates to:
  /// **'Construction'**
  String get wallCompositionAction;

  /// No description provided for @wallManageTypes.
  ///
  /// In en, this message translates to:
  /// **'Manage types'**
  String get wallManageTypes;

  /// No description provided for @wallMaterialPlaster.
  ///
  /// In en, this message translates to:
  /// **'Plaster'**
  String get wallMaterialPlaster;

  /// No description provided for @wallMaterialRender.
  ///
  /// In en, this message translates to:
  /// **'Facade render'**
  String get wallMaterialRender;

  /// No description provided for @wallMaterialBoard.
  ///
  /// In en, this message translates to:
  /// **'Plasterboard'**
  String get wallMaterialBoard;

  /// No description provided for @wallMaterialStone.
  ///
  /// In en, this message translates to:
  /// **'Stone'**
  String get wallMaterialStone;

  /// No description provided for @wallPlinth.
  ///
  /// In en, this message translates to:
  /// **'Plinth'**
  String get wallPlinth;

  /// No description provided for @wallPlinthFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get wallPlinthFinish;

  /// No description provided for @wallPlinthBase.
  ///
  /// In en, this message translates to:
  /// **'Base elevation (m)'**
  String get wallPlinthBase;

  /// No description provided for @wallPlinthBaseHelp.
  ///
  /// In en, this message translates to:
  /// **'Project elevation of the bottom edge; H is measured upwards.'**
  String get wallPlinthBaseHelp;

  /// No description provided for @wallAdvanced.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get wallAdvanced;

  /// No description provided for @wallTypeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy type'**
  String get wallTypeCopy;

  /// No description provided for @wallMixedValue.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get wallMixedValue;

  /// No description provided for @wallArc.
  ///
  /// In en, this message translates to:
  /// **'Arc wall'**
  String get wallArc;

  /// Perpendicular distance from the chord midpoint to the curve handle
  ///
  /// In en, this message translates to:
  /// **'Distance to chord'**
  String get architectChordDistance;

  /// No description provided for @wallArcSagitta.
  ///
  /// In en, this message translates to:
  /// **'Rise'**
  String get wallArcSagitta;

  /// No description provided for @wallArcSagittaHelp.
  ///
  /// In en, this message translates to:
  /// **'Distance from the chord midpoint to the arc midpoint along the reference line. Enter 0 to straighten.'**
  String get wallArcSagittaHelp;

  /// No description provided for @wallArcDimensionHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap to change the rise or radius. The start and end stay fixed.'**
  String get wallArcDimensionHelp;

  /// No description provided for @wallArcInvalidDimension.
  ///
  /// In en, this message translates to:
  /// **'Invalid dimension for this wall or its openings.'**
  String get wallArcInvalidDimension;

  /// No description provided for @wallArcPickEnd.
  ///
  /// In en, this message translates to:
  /// **'Pick the end of the arc'**
  String get wallArcPickEnd;

  /// No description provided for @wallArcPickThrough.
  ///
  /// In en, this message translates to:
  /// **'Pick a point on the arc'**
  String get wallArcPickThrough;

  /// No description provided for @wallArcInvalidRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius is too small for this wall.'**
  String get wallArcInvalidRadius;

  /// No description provided for @wallArcPickStart.
  ///
  /// In en, this message translates to:
  /// **'Pick the start of the arc'**
  String get wallArcPickStart;

  /// No description provided for @wallPlinthEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get wallPlinthEnabled;

  /// No description provided for @wallArcMode.
  ///
  /// In en, this message translates to:
  /// **'Arc'**
  String get wallArcMode;

  /// No description provided for @architectZonePresets.
  ///
  /// In en, this message translates to:
  /// **'Zone presets'**
  String get architectZonePresets;

  /// No description provided for @architectZoneManualHelp.
  ///
  /// In en, this message translates to:
  /// **'Manual: edit points and edges. Clear to detect the room from its walls again.'**
  String get architectZoneManualHelp;

  /// No description provided for @architectZoneBoundaryOpen.
  ///
  /// In en, this message translates to:
  /// **'No enclosed room found. Check the walls for gaps.'**
  String get architectZoneBoundaryOpen;

  /// No description provided for @architectZoneCrossingRepairHint.
  ///
  /// In en, this message translates to:
  /// **'Crossings will be corrected when the zone is closed.'**
  String get architectZoneCrossingRepairHint;

  /// No description provided for @architectZoneBoundaryRepaired.
  ///
  /// In en, this message translates to:
  /// **'Boundary crossings corrected.'**
  String get architectZoneBoundaryRepaired;

  /// No description provided for @architectSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets'**
  String get architectSheets;

  /// No description provided for @architectModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get architectModel;

  /// No description provided for @architectSheetName.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get architectSheetName;

  /// No description provided for @architectSheetPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get architectSheetPlan;

  /// No description provided for @architectSheetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add sheet'**
  String get architectSheetAdd;

  /// No description provided for @architectSheetProperties.
  ///
  /// In en, this message translates to:
  /// **'Sheet properties'**
  String get architectSheetProperties;

  /// No description provided for @architectSheetPlace.
  ///
  /// In en, this message translates to:
  /// **'Place view'**
  String get architectSheetPlace;

  /// No description provided for @architectSheetEdit.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get architectSheetEdit;

  /// No description provided for @architectSheetDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get architectSheetDuplicate;

  /// No description provided for @architectSheetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get architectSheetDelete;

  /// No description provided for @architectSheetLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get architectSheetLock;

  /// No description provided for @architectSheetUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get architectSheetUnlock;

  /// No description provided for @architectSheetTemplate.
  ///
  /// In en, this message translates to:
  /// **'Title block'**
  String get architectSheetTemplate;

  /// No description provided for @architectSheetExport.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get architectSheetExport;

  /// No description provided for @architectExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get architectExportTitle;

  /// No description provided for @architectExportDxfViews.
  ///
  /// In en, this message translates to:
  /// **'DXF drawings'**
  String get architectExportDxfViews;

  /// No description provided for @architectExportDxfSheets.
  ///
  /// In en, this message translates to:
  /// **'DXF sheets'**
  String get architectExportDxfSheets;

  /// No description provided for @architectExportIfc.
  ///
  /// In en, this message translates to:
  /// **'IFC model'**
  String get architectExportIfc;

  /// No description provided for @architectExportChooseViews.
  ///
  /// In en, this message translates to:
  /// **'Select drawings'**
  String get architectExportChooseViews;

  /// No description provided for @architectExportIfcSchema.
  ///
  /// In en, this message translates to:
  /// **'IFC version'**
  String get architectExportIfcSchema;

  /// No description provided for @architectExportRun.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get architectExportRun;

  /// No description provided for @architectExportPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get architectExportPreparing;

  /// No description provided for @architectExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export did not complete. Check geometry and the selected sources.'**
  String get architectExportFailed;

  /// No description provided for @architectExportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export is ready.'**
  String get architectExportComplete;

  /// No description provided for @architectExportIfcHint.
  ///
  /// In en, this message translates to:
  /// **'IFC retains BIM classes and materials. Editability also depends on the Revit or Archicad import settings.'**
  String get architectExportIfcHint;

  /// No description provided for @architectExportIfcReport.
  ///
  /// In en, this message translates to:
  /// **'Parametric: {parametric}. Geometric: {fallback}.'**
  String architectExportIfcReport(int parametric, int fallback);

  /// No description provided for @architectExportFallback.
  ///
  /// In en, this message translates to:
  /// **'Exact geometry; editability depends on the importer.'**
  String get architectExportFallback;

  /// No description provided for @architectExportProxy.
  ///
  /// In en, this message translates to:
  /// **'Component without a specialized IFC class.'**
  String get architectExportProxy;

  /// No description provided for @architectExportSurfaceFallback.
  ///
  /// In en, this message translates to:
  /// **'Surface representation without a closed volume.'**
  String get architectExportSurfaceFallback;

  /// No description provided for @architectExportMissingGeometry.
  ///
  /// In en, this message translates to:
  /// **'No geometric body. Element properties have been retained.'**
  String get architectExportMissingGeometry;

  /// No description provided for @architectExportUnhostedOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening without a slab to cut. Its boundary and properties have been retained.'**
  String get architectExportUnhostedOpening;

  /// No description provided for @architectExportElementFailed.
  ///
  /// In en, this message translates to:
  /// **'Invalid geometry in element {elementId}.'**
  String architectExportElementFailed(String elementId);

  /// No description provided for @architectExportReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get architectExportReport;

  /// No description provided for @architectExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get architectExportSave;

  /// No description provided for @architectSheetPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get architectSheetPrint;

  /// No description provided for @architectSheetMissingSource.
  ///
  /// In en, this message translates to:
  /// **'Missing source. Relink or remove this drawing before export.'**
  String get architectSheetMissingSource;

  /// No description provided for @architectSheetMixedScales.
  ///
  /// In en, this message translates to:
  /// **'Various'**
  String get architectSheetMixedScales;

  /// No description provided for @architectSheetFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get architectSheetFormat;

  /// No description provided for @architectSheetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get architectSheetCustom;

  /// No description provided for @architectSheetWidth.
  ///
  /// In en, this message translates to:
  /// **'Width (mm)'**
  String get architectSheetWidth;

  /// No description provided for @architectSheetHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (mm)'**
  String get architectSheetHeight;

  /// No description provided for @architectSheetMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin (mm)'**
  String get architectSheetMargin;

  /// No description provided for @architectSheetNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get architectSheetNumber;

  /// No description provided for @architectSheetAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get architectSheetAuthor;

  /// No description provided for @architectSheetDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get architectSheetDate;

  /// No description provided for @architectSheetNameField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get architectSheetNameField;

  /// No description provided for @architectSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get architectSheetSave;

  /// No description provided for @architectSheetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get architectSheetCancel;

  /// No description provided for @architectSheetScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get architectSheetScale;

  /// No description provided for @architectSheetX.
  ///
  /// In en, this message translates to:
  /// **'X (mm)'**
  String get architectSheetX;

  /// No description provided for @architectSheetY.
  ///
  /// In en, this message translates to:
  /// **'Y (mm)'**
  String get architectSheetY;

  /// No description provided for @architectSheetAnchorX.
  ///
  /// In en, this message translates to:
  /// **'Source X'**
  String get architectSheetAnchorX;

  /// No description provided for @architectSheetAnchorY.
  ///
  /// In en, this message translates to:
  /// **'Source Y'**
  String get architectSheetAnchorY;

  /// No description provided for @architectSheetRotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation (°)'**
  String get architectSheetRotation;

  /// No description provided for @architectSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get architectSheetTitle;

  /// No description provided for @architectSheetSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get architectSheetSource;

  /// No description provided for @architectSheetAlign.
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get architectSheetAlign;

  /// No description provided for @architectSheetLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get architectSheetLeft;

  /// No description provided for @architectSheetRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get architectSheetRight;

  /// No description provided for @architectSheetTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get architectSheetTop;

  /// No description provided for @architectSheetBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get architectSheetBottom;

  /// No description provided for @architectSheetSelect.
  ///
  /// In en, this message translates to:
  /// **'Select sheets in export order'**
  String get architectSheetSelect;

  /// No description provided for @architectSheetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter valid positive sizes and keep the margin inside the sheet.'**
  String get architectSheetInvalid;

  /// No description provided for @architectSheetExportFailed.
  ///
  /// In en, this message translates to:
  /// **'PDF export failed.'**
  String get architectSheetExportFailed;

  /// No description provided for @architectSheetNoViews.
  ///
  /// In en, this message translates to:
  /// **'No views available.'**
  String get architectSheetNoViews;

  /// No description provided for @architectSheetAddCell.
  ///
  /// In en, this message translates to:
  /// **'Add cell'**
  String get architectSheetAddCell;

  /// No description provided for @architectSheetField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get architectSheetField;

  /// No description provided for @architectSheetBorder.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get architectSheetBorder;

  /// No description provided for @architectSheetText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get architectSheetText;

  /// No description provided for @architectSheetProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get architectSheetProject;

  /// No description provided for @architectSheetDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get architectSheetDrawing;

  /// No description provided for @architectPrintPreview.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get architectPrintPreview;

  /// No description provided for @architectAnnotationSettings.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get architectAnnotationSettings;

  /// No description provided for @architectAnnotationSize.
  ///
  /// In en, this message translates to:
  /// **'Size on paper (mm)'**
  String get architectAnnotationSize;

  /// No description provided for @architectAnnotationReset.
  ///
  /// In en, this message translates to:
  /// **'Use profile'**
  String get architectAnnotationReset;

  /// No description provided for @architectAnnotationProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get architectAnnotationProfile;

  /// No description provided for @architectAnnotationElement.
  ///
  /// In en, this message translates to:
  /// **'Individual annotation'**
  String get architectAnnotationElement;

  /// No description provided for @architectAnnotationOrdinary.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get architectAnnotationOrdinary;

  /// No description provided for @architectAnnotationDimension.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get architectAnnotationDimension;

  /// No description provided for @architectAnnotationArea.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get architectAnnotationArea;

  /// No description provided for @architectAnnotationRoomName.
  ///
  /// In en, this message translates to:
  /// **'Room names'**
  String get architectAnnotationRoomName;

  /// No description provided for @architectAnnotationTitle.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get architectAnnotationTitle;

  /// No description provided for @architectAnnotationTable.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get architectAnnotationTable;

  /// No description provided for @architectAnnotationSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get architectAnnotationSymbol;

  /// No description provided for @architectSheetVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get architectSheetVisibility;

  /// No description provided for @architectSheetAxes.
  ///
  /// In en, this message translates to:
  /// **'Axes'**
  String get architectSheetAxes;

  /// No description provided for @architectSheetZones.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get architectSheetZones;

  /// No description provided for @architectSheetDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get architectSheetDimensions;

  /// No description provided for @architectSheetAnnotations.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get architectSheetAnnotations;

  /// No description provided for @architectSheetMarkers.
  ///
  /// In en, this message translates to:
  /// **'Markers'**
  String get architectSheetMarkers;

  /// No description provided for @architectSheetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create a sheet, then place a plan, section or elevation.'**
  String get architectSheetEmpty;

  /// No description provided for @architectSheetSaveView.
  ///
  /// In en, this message translates to:
  /// **'Save view'**
  String get architectSheetSaveView;

  /// No description provided for @architectSheetTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get architectSheetTemplateName;

  /// No description provided for @architectAreaWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Area ({unit}²)'**
  String architectAreaWithUnit(String unit);

  /// No description provided for @architectSheetTemplateOverflow.
  ///
  /// In en, this message translates to:
  /// **'Title block text exceeds its cell. Enlarge the cell before export.'**
  String get architectSheetTemplateOverflow;

  /// No description provided for @snapMidpointAlignment.
  ///
  /// In en, this message translates to:
  /// **'Align to midpoint'**
  String get snapMidpointAlignment;

  /// No description provided for @architectComponentLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get architectComponentLibraryTitle;

  /// No description provided for @architectComponentStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Component Studio'**
  String get architectComponentStudioTitle;

  /// No description provided for @architectComponentStudioBtn.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get architectComponentStudioBtn;

  /// No description provided for @architectCategorySanitary.
  ///
  /// In en, this message translates to:
  /// **'Sanitary'**
  String get architectCategorySanitary;

  /// No description provided for @architectCategoryFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get architectCategoryFurniture;

  /// No description provided for @architectCategoryKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get architectCategoryKitchen;

  /// No description provided for @architectCategoryStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get architectCategoryStorage;

  /// No description provided for @architectCategoryOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get architectCategoryOffice;

  /// No description provided for @architectCategoryEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get architectCategoryEquipment;

  /// No description provided for @architectCategoryLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get architectCategoryLighting;

  /// No description provided for @architectCategoryOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get architectCategoryOutdoor;

  /// No description provided for @architectComponentRotateBtn.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° (R)'**
  String get architectComponentRotateBtn;

  /// No description provided for @architectComponentSavedMsg.
  ///
  /// In en, this message translates to:
  /// **'Component saved to custom library!'**
  String get architectComponentSavedMsg;

  /// No description provided for @architectComponentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete from library'**
  String get architectComponentDelete;

  /// No description provided for @architectComponentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Component deleted from library'**
  String get architectComponentDeleted;

  /// No description provided for @architectComponentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from library?'**
  String architectComponentDeleteConfirm(String name);

  /// No description provided for @architectComponentCompileBtn.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get architectComponentCompileBtn;

  /// No description provided for @architectComponentSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get architectComponentSaveBtn;

  /// No description provided for @architectComponentTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Select template...'**
  String get architectComponentTemplateHint;

  /// No description provided for @architectComponentExportDartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export Dart class to clipboard'**
  String get architectComponentExportDartTooltip;

  /// No description provided for @architectComponentExportDartMsg.
  ///
  /// In en, this message translates to:
  /// **'Dart code copied to clipboard!'**
  String get architectComponentExportDartMsg;

  /// No description provided for @architect2dPlanSymbol.
  ///
  /// In en, this message translates to:
  /// **'2D Plan Symbol'**
  String get architect2dPlanSymbol;

  /// No description provided for @architect3dSolidMesh.
  ///
  /// In en, this message translates to:
  /// **'3D Solid Mesh'**
  String get architect3dSolidMesh;

  /// No description provided for @architectPlacementModeWall.
  ///
  /// In en, this message translates to:
  /// **'Wall Attached'**
  String get architectPlacementModeWall;

  /// No description provided for @architectPlacementModeFree.
  ///
  /// In en, this message translates to:
  /// **'Free Standing'**
  String get architectPlacementModeFree;

  /// Layer for furniture and sanitary components
  ///
  /// In en, this message translates to:
  /// **'Furniture & Interior'**
  String get architectLayerFurniture;

  /// No description provided for @architectComponentNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get architectComponentNoItems;

  /// No description provided for @architectFurnishing.
  ///
  /// In en, this message translates to:
  /// **'Furnishing'**
  String get architectFurnishing;

  /// No description provided for @architectLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get architectLibrary;

  /// No description provided for @architectLibraryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get architectLibraryAll;

  /// No description provided for @architectLibrarySourceAll.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get architectLibrarySourceAll;

  /// No description provided for @architectLibraryBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get architectLibraryBuiltIn;

  /// No description provided for @architectLibraryCustom.
  ///
  /// In en, this message translates to:
  /// **'My objects'**
  String get architectLibraryCustom;

  /// No description provided for @architectLibraryImport.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get architectLibraryImport;

  /// No description provided for @architectLibraryImportHelp.
  ///
  /// In en, this message translates to:
  /// **'Import a parametric object (.json) with dimensions in metres. Preview and save it in the studio.'**
  String get architectLibraryImportHelp;

  /// No description provided for @architectLibraryImportError.
  ///
  /// In en, this message translates to:
  /// **'The object could not be imported.'**
  String get architectLibraryImportError;

  /// No description provided for @architectComponentInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the object code, dimensions and supported shapes.'**
  String get architectComponentInvalid;

  /// No description provided for @architectComponentCustomName.
  ///
  /// In en, this message translates to:
  /// **'Custom object'**
  String get architectComponentCustomName;

  /// No description provided for @architectComponentCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get architectComponentCode;

  /// No description provided for @architectComponentPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get architectComponentPreview;

  /// No description provided for @architectComponentLockRatio.
  ///
  /// In en, this message translates to:
  /// **'Lock X:Y:Z'**
  String get architectComponentLockRatio;

  /// No description provided for @architectComponentLockRatioHelp.
  ///
  /// In en, this message translates to:
  /// **'Changing one dimension scales all three by the same factor.'**
  String get architectComponentLockRatioHelp;

  /// No description provided for @architectComponentDimensionError.
  ///
  /// In en, this message translates to:
  /// **'Enter a size from 0.1 to 10000 cm.'**
  String get architectComponentDimensionError;

  /// No description provided for @architectComponentDefaults.
  ///
  /// In en, this message translates to:
  /// **'Default size'**
  String get architectComponentDefaults;

  /// No description provided for @architectTemplateDesk.
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get architectTemplateDesk;

  /// No description provided for @architectTemplateBasin.
  ///
  /// In en, this message translates to:
  /// **'Basin'**
  String get architectTemplateBasin;

  /// No description provided for @architectComponentToiletWall.
  ///
  /// In en, this message translates to:
  /// **'Wall-hung toilet'**
  String get architectComponentToiletWall;

  /// No description provided for @architectComponentToiletFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor-standing toilet'**
  String get architectComponentToiletFloor;

  /// No description provided for @architectComponentVanity.
  ///
  /// In en, this message translates to:
  /// **'Washbasin cabinet'**
  String get architectComponentVanity;

  /// No description provided for @architectComponentBathtub.
  ///
  /// In en, this message translates to:
  /// **'Bathtub'**
  String get architectComponentBathtub;

  /// No description provided for @architectComponentShower.
  ///
  /// In en, this message translates to:
  /// **'Shower'**
  String get architectComponentShower;

  /// No description provided for @architectComponentBedDouble.
  ///
  /// In en, this message translates to:
  /// **'Double bed'**
  String get architectComponentBedDouble;

  /// No description provided for @architectComponentBedSingle.
  ///
  /// In en, this message translates to:
  /// **'Single bed'**
  String get architectComponentBedSingle;

  /// No description provided for @architectComponentWardrobe.
  ///
  /// In en, this message translates to:
  /// **'Wardrobe'**
  String get architectComponentWardrobe;

  /// No description provided for @architectComponentDining.
  ///
  /// In en, this message translates to:
  /// **'Table and chairs'**
  String get architectComponentDining;

  /// No description provided for @architectComponentSofa.
  ///
  /// In en, this message translates to:
  /// **'Sofa'**
  String get architectComponentSofa;

  /// No description provided for @architectComponentDesk.
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get architectComponentDesk;

  /// No description provided for @architectComponentKitchenBase.
  ///
  /// In en, this message translates to:
  /// **'Base cabinet'**
  String get architectComponentKitchenBase;

  /// No description provided for @architectComponentKitchenSink.
  ///
  /// In en, this message translates to:
  /// **'Sink cabinet'**
  String get architectComponentKitchenSink;

  /// No description provided for @architectComponentFridge.
  ///
  /// In en, this message translates to:
  /// **'Refrigerator'**
  String get architectComponentFridge;

  /// No description provided for @architectComponentCooktop.
  ///
  /// In en, this message translates to:
  /// **'Cooktop and oven'**
  String get architectComponentCooktop;

  /// No description provided for @architectComponentExportJsonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get architectComponentExportJsonTooltip;

  /// No description provided for @architectComponentExportJsonMsg.
  ///
  /// In en, this message translates to:
  /// **'JSON copied to clipboard'**
  String get architectComponentExportJsonMsg;

  /// No description provided for @architectComponentView2d.
  ///
  /// In en, this message translates to:
  /// **'2D view'**
  String get architectComponentView2d;

  /// No description provided for @architectComponentView3d.
  ///
  /// In en, this message translates to:
  /// **'3D view'**
  String get architectComponentView3d;

  /// No description provided for @architectApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get architectApartment;

  /// No description provided for @architectRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get architectRoom;

  /// No description provided for @architectApartmentRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get architectApartmentRooms;

  /// No description provided for @architectUnassignedRooms.
  ///
  /// In en, this message translates to:
  /// **'Unassigned rooms'**
  String get architectUnassignedRooms;

  /// No description provided for @architectApartmentAutoAssignment.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get architectApartmentAutoAssignment;

  /// No description provided for @architectApartmentNoRooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms within the outline.'**
  String get architectApartmentNoRooms;

  /// No description provided for @architectApartmentBoundaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Draw manually along internal wall axes and the exterior faces of exterior walls.'**
  String get architectApartmentBoundaryHelp;

  /// No description provided for @architectApartmentGross.
  ///
  /// In en, this message translates to:
  /// **'Contour area'**
  String get architectApartmentGross;

  /// No description provided for @architectApartmentNet.
  ///
  /// In en, this message translates to:
  /// **'Room area'**
  String get architectApartmentNet;

  /// No description provided for @architectApartmentRoomsHelp.
  ///
  /// In en, this message translates to:
  /// **'Rooms are assigned automatically by the largest overlapping area with an apartment. Each room is counted in full only once. Equal areas retain the current apartment. Rooms outside all apartments stay unassigned.'**
  String get architectApartmentRoomsHelp;

  /// No description provided for @architectLineJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lines joined'**
  String get architectLineJoinSuccess;

  /// No description provided for @architectLineJoinIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Lines cannot be joined'**
  String get architectLineJoinIncompatible;

  /// No description provided for @architectLineJoinSelectSecond.
  ///
  /// In en, this message translates to:
  /// **'Select second line to join'**
  String get architectLineJoinSelectSecond;

  /// No description provided for @architectLineEditRejected.
  ///
  /// In en, this message translates to:
  /// **'Line must be at least 1 mm long.'**
  String get architectLineEditRejected;

  /// No description provided for @architectLineStyle.
  ///
  /// In en, this message translates to:
  /// **'Line style'**
  String get architectLineStyle;

  /// No description provided for @architectLineSolid.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get architectLineSolid;

  /// No description provided for @architectLineDashed.
  ///
  /// In en, this message translates to:
  /// **'Dashed'**
  String get architectLineDashed;

  /// No description provided for @architectLineShortDashed.
  ///
  /// In en, this message translates to:
  /// **'Short dashes'**
  String get architectLineShortDashed;

  /// No description provided for @architectLineLongDashed.
  ///
  /// In en, this message translates to:
  /// **'Long dashes'**
  String get architectLineLongDashed;

  /// No description provided for @architectLineDotted.
  ///
  /// In en, this message translates to:
  /// **'Dotted'**
  String get architectLineDotted;

  /// No description provided for @architectLineSparseDotted.
  ///
  /// In en, this message translates to:
  /// **'Sparse dots'**
  String get architectLineSparseDotted;

  /// No description provided for @architectLineDashDot.
  ///
  /// In en, this message translates to:
  /// **'Dash–dot'**
  String get architectLineDashDot;

  /// No description provided for @architectLineDashDoubleDot.
  ///
  /// In en, this message translates to:
  /// **'Dash–double dot'**
  String get architectLineDashDoubleDot;

  /// No description provided for @architectLineLongDashDot.
  ///
  /// In en, this message translates to:
  /// **'Long dash–dot'**
  String get architectLineLongDashDot;

  /// No description provided for @architectLineLongShortDash.
  ///
  /// In en, this message translates to:
  /// **'Long–short dash'**
  String get architectLineLongShortDash;

  /// No description provided for @architectLineDoubleDashDot.
  ///
  /// In en, this message translates to:
  /// **'Double dash–dot'**
  String get architectLineDoubleDashDot;

  /// No description provided for @architectLinePatternEditor.
  ///
  /// In en, this message translates to:
  /// **'Custom pattern'**
  String get architectLinePatternEditor;

  /// No description provided for @architectLineDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete line style'**
  String get architectLineDeleteConfirmTitle;

  /// No description provided for @architectLineDeleteConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Delete custom line style \"{name}\"?'**
  String architectLineDeleteConfirmPrompt(String name);

  /// No description provided for @architectLineStyleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Line style deleted.'**
  String get architectLineStyleDeleted;

  /// No description provided for @architectLineDash.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get architectLineDash;

  /// No description provided for @architectLineGap.
  ///
  /// In en, this message translates to:
  /// **'Gap'**
  String get architectLineGap;

  /// No description provided for @architectLinePatternHint.
  ///
  /// In en, this message translates to:
  /// **'Dashes, gaps and symbols. Sizes are measured on paper.'**
  String get architectLinePatternHint;

  /// No description provided for @architectLinePatternRange.
  ///
  /// In en, this message translates to:
  /// **'Enter 0.1–100 mm.'**
  String get architectLinePatternRange;

  /// No description provided for @architectLinePatternAdd.
  ///
  /// In en, this message translates to:
  /// **'Add pair'**
  String get architectLinePatternAdd;

  /// No description provided for @architectLinePatternRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove pair'**
  String get architectLinePatternRemove;

  /// No description provided for @architectLinePowerLine.
  ///
  /// In en, this message translates to:
  /// **'Power line'**
  String get architectLinePowerLine;

  /// No description provided for @architectLineSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get architectLineSymbol;

  /// No description provided for @architectLineSymbolNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get architectLineSymbolNone;

  /// No description provided for @architectLineSymbolLightning.
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get architectLineSymbolLightning;

  /// No description provided for @architectLineSymbolCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get architectLineSymbolCircle;

  /// No description provided for @architectLineSymbolSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get architectLineSymbolSquare;

  /// No description provided for @architectLineSymbolTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get architectLineSymbolTriangle;

  /// No description provided for @architectLineSymbolDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get architectLineSymbolDiamond;

  /// No description provided for @architectLineSymbolCross.
  ///
  /// In en, this message translates to:
  /// **'Cross'**
  String get architectLineSymbolCross;

  /// No description provided for @architectLineSymbolArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get architectLineSymbolArrow;

  /// No description provided for @architectLineSymbolChevron.
  ///
  /// In en, this message translates to:
  /// **'Chevron'**
  String get architectLineSymbolChevron;

  /// No description provided for @architectLineSymbolCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom shape'**
  String get architectLineSymbolCustom;

  /// No description provided for @architectLineSymbolSettings.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get architectLineSymbolSettings;

  /// No description provided for @architectLineSymbolDraw.
  ///
  /// In en, this message translates to:
  /// **'Edit shape'**
  String get architectLineSymbolDraw;

  /// No description provided for @architectLineSymbolSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get architectLineSymbolSize;

  /// No description provided for @architectLineSymbolSpacing.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get architectLineSymbolSpacing;

  /// No description provided for @architectLineSymbolFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow line direction'**
  String get architectLineSymbolFollow;

  /// No description provided for @architectLineSymbolClearLine.
  ///
  /// In en, this message translates to:
  /// **'Gap around symbol'**
  String get architectLineSymbolClearLine;

  /// No description provided for @architectLineSymbolDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Place points or draw freehand. You can add separate strokes.'**
  String get architectLineSymbolDrawHint;

  /// No description provided for @architectLineSymbolPoints.
  ///
  /// In en, this message translates to:
  /// **'Point by point'**
  String get architectLineSymbolPoints;

  /// No description provided for @architectLineSymbolFreehand.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get architectLineSymbolFreehand;

  /// No description provided for @architectToolHatch.
  ///
  /// In en, this message translates to:
  /// **'Hatch'**
  String get architectToolHatch;

  /// No description provided for @architectSelectionHatchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hatch} other{{count} hatches}}'**
  String architectSelectionHatchesCount(int count);

  /// No description provided for @architectHatchPattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get architectHatchPattern;

  /// No description provided for @architectHatchCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom hatch'**
  String get architectHatchCustom;

  /// No description provided for @architectHatchHint.
  ///
  /// In en, this message translates to:
  /// **'Layers of lines or symbols. Spacing and sizes are in mm on paper.'**
  String get architectHatchHint;

  /// No description provided for @architectHatchDiagonal.
  ///
  /// In en, this message translates to:
  /// **'Diagonal'**
  String get architectHatchDiagonal;

  /// No description provided for @architectHatchReverseDiagonal.
  ///
  /// In en, this message translates to:
  /// **'Reverse diagonal'**
  String get architectHatchReverseDiagonal;

  /// No description provided for @architectHatchHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get architectHatchHorizontal;

  /// No description provided for @architectHatchVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get architectHatchVertical;

  /// No description provided for @architectHatchCross.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get architectHatchCross;

  /// No description provided for @architectHatchDiagonalCross.
  ///
  /// In en, this message translates to:
  /// **'Crosshatch'**
  String get architectHatchDiagonalCross;

  /// No description provided for @architectHatchBrick.
  ///
  /// In en, this message translates to:
  /// **'Brick'**
  String get architectHatchBrick;

  /// No description provided for @architectHatchConcrete.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get architectHatchConcrete;

  /// No description provided for @architectHatchDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get architectHatchDots;

  /// No description provided for @architectHatchEarth.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get architectHatchEarth;

  /// No description provided for @architectHatchScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get architectHatchScale;

  /// No description provided for @architectHatchBorder.
  ///
  /// In en, this message translates to:
  /// **'Boundary'**
  String get architectHatchBorder;

  /// No description provided for @architectHatchLayer.
  ///
  /// In en, this message translates to:
  /// **'Layer {number}'**
  String architectHatchLayer(int number);

  /// No description provided for @architectHatchAddLayer.
  ///
  /// In en, this message translates to:
  /// **'Add layer'**
  String get architectHatchAddLayer;

  /// No description provided for @architectHatchSpacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get architectHatchSpacing;

  /// No description provided for @architectHatchPhase.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get architectHatchPhase;

  /// No description provided for @architectHatchShift.
  ///
  /// In en, this message translates to:
  /// **'Row shift'**
  String get architectHatchShift;

  /// No description provided for @architectHatchSymbolsOnly.
  ///
  /// In en, this message translates to:
  /// **'Symbols only'**
  String get architectHatchSymbolsOnly;

  /// No description provided for @architectHatchFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get architectHatchFinish;

  /// No description provided for @architectHatchDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Place at least three vertices and close the contour.'**
  String get architectHatchDrawHint;

  /// No description provided for @architectLineHatchBrickJoint.
  ///
  /// In en, this message translates to:
  /// **'Joints'**
  String get architectLineHatchBrickJoint;

  /// No description provided for @architectLineHatchAggregate.
  ///
  /// In en, this message translates to:
  /// **'Aggregate'**
  String get architectLineHatchAggregate;

  /// No description provided for @architectLineHatchGrain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get architectLineHatchGrain;

  /// No description provided for @architectLineHatchDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get architectLineHatchDots;

  /// No description provided for @architectLineHatchEarth.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get architectLineHatchEarth;

  /// No description provided for @architectLineSymbolNewStroke.
  ///
  /// In en, this message translates to:
  /// **'New stroke'**
  String get architectLineSymbolNewStroke;

  /// No description provided for @architectLineSymbolCloseStroke.
  ///
  /// In en, this message translates to:
  /// **'Close stroke'**
  String get architectLineSymbolCloseStroke;

  /// No description provided for @architectLineSymbolRange.
  ///
  /// In en, this message translates to:
  /// **'Enter {minimum}–{maximum} {unit}.'**
  String architectLineSymbolRange(String minimum, String maximum, String unit);

  /// No description provided for @architectViewUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get architectViewUnlimited;

  /// No description provided for @architectViewDepth.
  ///
  /// In en, this message translates to:
  /// **'View depth'**
  String get architectViewDepth;

  /// No description provided for @architectViewDepthInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a finite distance of at least 1 cm.'**
  String get architectViewDepthInvalid;

  /// No description provided for @architectDrainageTitle.
  ///
  /// In en, this message translates to:
  /// **'Drainage'**
  String get architectDrainageTitle;

  /// No description provided for @architectDrainageGutter.
  ///
  /// In en, this message translates to:
  /// **'Gutter'**
  String get architectDrainageGutter;

  /// No description provided for @architectDrainagePipes.
  ///
  /// In en, this message translates to:
  /// **'Downpipes'**
  String get architectDrainagePipes;

  /// No description provided for @architectDrainagePipe.
  ///
  /// In en, this message translates to:
  /// **'Downpipe'**
  String get architectDrainagePipe;

  /// No description provided for @architectDrainageSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart downpipe'**
  String get architectDrainageSmart;

  /// No description provided for @architectDrainageProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get architectDrainageProfile;

  /// No description provided for @architectDrainageHalfRound.
  ///
  /// In en, this message translates to:
  /// **'Half-round'**
  String get architectDrainageHalfRound;

  /// No description provided for @architectDrainageBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get architectDrainageBox;

  /// No description provided for @architectDrainageMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get architectDrainageMaterial;

  /// No description provided for @architectDrainageSteel.
  ///
  /// In en, this message translates to:
  /// **'Galvanized steel'**
  String get architectDrainageSteel;

  /// No description provided for @architectDrainageAluminium.
  ///
  /// In en, this message translates to:
  /// **'Aluminium'**
  String get architectDrainageAluminium;

  /// No description provided for @architectDrainagePvc.
  ///
  /// In en, this message translates to:
  /// **'PVC'**
  String get architectDrainagePvc;

  /// No description provided for @architectDrainageCopper.
  ///
  /// In en, this message translates to:
  /// **'Copper'**
  String get architectDrainageCopper;

  /// No description provided for @architectDrainageWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectDrainageWidth;

  /// No description provided for @architectDrainageDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get architectDrainageDepth;

  /// No description provided for @architectDrainageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add downpipe'**
  String get architectDrainageAdd;

  /// No description provided for @architectDrainagePlace.
  ///
  /// In en, this message translates to:
  /// **'Place on plan'**
  String get architectDrainagePlace;

  /// No description provided for @architectDrainagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick a position on the eaves.'**
  String get architectDrainagePrompt;

  /// No description provided for @architectDrainageOffset.
  ///
  /// In en, this message translates to:
  /// **'From eaves start'**
  String get architectDrainageOffset;

  /// No description provided for @architectDrainageDiameter.
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get architectDrainageDiameter;

  /// No description provided for @architectDrainageClearance.
  ///
  /// In en, this message translates to:
  /// **'Wall clearance'**
  String get architectDrainageClearance;

  /// No description provided for @architectDrainageOutlet.
  ///
  /// In en, this message translates to:
  /// **'Outlet elevation'**
  String get architectDrainageOutlet;

  /// No description provided for @architectDrainageBend.
  ///
  /// In en, this message translates to:
  /// **'Bend angle'**
  String get architectDrainageBend;

  /// No description provided for @architectDrainageFacade.
  ///
  /// In en, this message translates to:
  /// **'Facade'**
  String get architectDrainageFacade;

  /// No description provided for @architectDrainageWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get architectDrainageWall;

  /// No description provided for @architectDrainageAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get architectDrainageAuto;

  /// No description provided for @architectDrainageWaypoints.
  ///
  /// In en, this message translates to:
  /// **'Waypoints'**
  String get architectDrainageWaypoints;

  /// No description provided for @architectDrainageWaypointsHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty: automatic route. Manual: one point per line — inward offset; absolute elevation (m), top to bottom.'**
  String get architectDrainageWaypointsHelp;

  /// No description provided for @architectDrainageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid value.'**
  String get architectDrainageInvalid;

  /// No description provided for @architectDrainageReady.
  ///
  /// In en, this message translates to:
  /// **'Route is clear.'**
  String get architectDrainageReady;

  /// No description provided for @architectDrainageNoFacade.
  ///
  /// In en, this message translates to:
  /// **'No facade found. Select a wall.'**
  String get architectDrainageNoFacade;

  /// No description provided for @architectDrainageBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not enough room for the route. Adjust the position or waypoints.'**
  String get architectDrainageBlocked;

  /// No description provided for @architectDrainageOutside.
  ///
  /// In en, this message translates to:
  /// **'Position is outside the exposed eaves.'**
  String get architectDrainageOutside;

  /// No description provided for @architectDrainageNoRoof.
  ///
  /// In en, this message translates to:
  /// **'Create a roof first.'**
  String get architectDrainageNoRoof;

  /// No description provided for @architectRoofTimberTab.
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get architectRoofTimberTab;

  /// No description provided for @architectViewStep.
  ///
  /// In en, this message translates to:
  /// **'Add jog'**
  String get architectViewStep;

  /// No description provided for @architectViewEditHint.
  ///
  /// In en, this message translates to:
  /// **'Drag endpoints, jogs or the far boundary, then apply.'**
  String get architectViewEditHint;

  /// No description provided for @architectViewDepthBehindSteps.
  ///
  /// In en, this message translates to:
  /// **'Place the far boundary beyond every segment.'**
  String get architectViewDepthBehindSteps;

  /// No description provided for @architectViewStraight.
  ///
  /// In en, this message translates to:
  /// **'Straighten'**
  String get architectViewStraight;

  /// No description provided for @architectViewStepHint.
  ///
  /// In en, this message translates to:
  /// **'Click beside the marker to set the jog station and offset. Repeat Add jog for more segments.'**
  String get architectViewStepHint;

  /// No description provided for @stairConstruction.
  ///
  /// In en, this message translates to:
  /// **'Construction'**
  String get stairConstruction;

  /// No description provided for @stairSteel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get stairSteel;

  /// No description provided for @stairTreadThickness.
  ///
  /// In en, this message translates to:
  /// **'Tread thickness'**
  String get stairTreadThickness;

  /// No description provided for @stairStringerWidth.
  ///
  /// In en, this message translates to:
  /// **'Stringer width'**
  String get stairStringerWidth;

  /// No description provided for @stairStringerDepth.
  ///
  /// In en, this message translates to:
  /// **'Stringer depth'**
  String get stairStringerDepth;

  /// No description provided for @architectHatchWood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get architectHatchWood;

  /// No description provided for @architectHatchMetal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get architectHatchMetal;

  /// No description provided for @architectHatchGenerator.
  ///
  /// In en, this message translates to:
  /// **'Pattern generator'**
  String get architectHatchGenerator;

  /// No description provided for @architectHatchGeneratorHint.
  ///
  /// In en, this message translates to:
  /// **'Draw a motif with connected lines. Set its size and row spacing; the preview updates as you draw.'**
  String get architectHatchGeneratorHint;

  /// No description provided for @architectSketchOrtho.
  ///
  /// In en, this message translates to:
  /// **'Orthogonal lines'**
  String get architectSketchOrtho;

  /// No description provided for @architectSketchPreview.
  ///
  /// In en, this message translates to:
  /// **'Repeat preview'**
  String get architectSketchPreview;

  /// No description provided for @architectTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain line'**
  String get architectTerrain;

  /// No description provided for @architectTerrainHint.
  ///
  /// In en, this message translates to:
  /// **'Place points from left to right. Confirm to hide the building below this line in this elevation.'**
  String get architectTerrainHint;

  /// No description provided for @architectRoofPitchEdit.
  ///
  /// In en, this message translates to:
  /// **'Roof pitch'**
  String get architectRoofPitchEdit;

  /// No description provided for @architectRoofPitchHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the green point to change pitch and snap to a neighbouring roof. Tap the roof to choose a fixed axis. Pinch or use the mouse wheel to zoom.'**
  String get architectRoofPitchHint;

  /// No description provided for @architectRoofPitchAxis.
  ///
  /// In en, this message translates to:
  /// **'Use eaves axis'**
  String get architectRoofPitchAxis;

  /// No description provided for @architectStrokeWeight.
  ///
  /// In en, this message translates to:
  /// **'Line weight'**
  String get architectStrokeWeight;

  /// No description provided for @architectCutOpening.
  ///
  /// In en, this message translates to:
  /// **'Cut opening'**
  String get architectCutOpening;

  /// No description provided for @architectCutOpeningHint.
  ///
  /// In en, this message translates to:
  /// **'Draw a closed contour inside the selected element, then confirm.'**
  String get architectCutOpeningHint;

  /// No description provided for @architectCutOpeningInvalid.
  ///
  /// In en, this message translates to:
  /// **'Keep the opening inside the element, without touching its boundary or another opening.'**
  String get architectCutOpeningInvalid;

  /// No description provided for @architectHatchAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Fill: tap inside a closed contour.'**
  String get architectHatchAutoHint;

  /// No description provided for @architectHatchAutoFailed.
  ///
  /// In en, this message translates to:
  /// **'No closed contour found. Close the boundary or draw it manually.'**
  String get architectHatchAutoFailed;

  /// No description provided for @appSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appSettingsTitle;

  /// No description provided for @uiSettingsCategory.
  ///
  /// In en, this message translates to:
  /// **'UI'**
  String get uiSettingsCategory;

  /// No description provided for @contextMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Context menu'**
  String get contextMenuTitle;

  /// No description provided for @contextMenuLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get contextMenuLayout;

  /// No description provided for @contextMenuCircle.
  ///
  /// In en, this message translates to:
  /// **'Fixed circle'**
  String get contextMenuCircle;

  /// No description provided for @contextMenuGrid.
  ///
  /// In en, this message translates to:
  /// **'Fixed grid'**
  String get contextMenuGrid;

  /// No description provided for @contextMenuCombination.
  ///
  /// In en, this message translates to:
  /// **'Combination'**
  String get contextMenuCombination;

  /// No description provided for @contextMenuDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get contextMenuDefault;

  /// No description provided for @contextMenuSaveAs.
  ///
  /// In en, this message translates to:
  /// **'New combination'**
  String get contextMenuSaveAs;

  /// No description provided for @contextMenuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get contextMenuEdit;

  /// No description provided for @contextMenuName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contextMenuName;

  /// No description provided for @contextMenuEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get contextMenuEmpty;

  /// No description provided for @contextMenuMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get contextMenuMore;

  /// No description provided for @contextMenuAssignHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a slot to choose a command. Choosing a command already in use swaps the two slots. Other commands remain under More.'**
  String get contextMenuAssignHint;

  /// No description provided for @contextMenuPage.
  ///
  /// In en, this message translates to:
  /// **'More commands: page {page} of {total}. Tap for the next page.'**
  String contextMenuPage(int page, int total);

  /// No description provided for @uiSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be saved. Try again.'**
  String get uiSettingsSaveFailed;

  /// No description provided for @architectViewVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get architectViewVisibility;

  /// No description provided for @architectSectionVisibility.
  ///
  /// In en, this message translates to:
  /// **'Section visibility'**
  String get architectSectionVisibility;

  /// No description provided for @architectSectionProjectRules.
  ///
  /// In en, this message translates to:
  /// **'Project defaults'**
  String get architectSectionProjectRules;

  /// No description provided for @architectSectionViewRules.
  ///
  /// In en, this message translates to:
  /// **'This section'**
  String get architectSectionViewRules;

  /// No description provided for @architectSectionInherit.
  ///
  /// In en, this message translates to:
  /// **'Use project'**
  String get architectSectionInherit;

  /// No description provided for @architectSectionCutAndView.
  ///
  /// In en, this message translates to:
  /// **'Cut and view'**
  String get architectSectionCutAndView;

  /// No description provided for @architectSectionCutOnly.
  ///
  /// In en, this message translates to:
  /// **'Cut only'**
  String get architectSectionCutOnly;

  /// No description provided for @architectSectionHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get architectSectionHidden;

  /// No description provided for @architectSectionVisibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Project defaults apply to all sections unless a section overrides them. Cut only shows the actual intersection with the section plane and omits the projection behind it. 3D and elevations keep their normal visibility.'**
  String get architectSectionVisibilityHelp;

  /// No description provided for @bimGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get bimGroup;

  /// No description provided for @bimUngroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get bimUngroup;

  /// No description provided for @bimEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get bimEditGroup;

  /// No description provided for @bimInsideGroup.
  ///
  /// In en, this message translates to:
  /// **'Inside group'**
  String get bimInsideGroup;

  /// No description provided for @bimGroupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bimGroupDone;

  /// No description provided for @bimGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get bimGroupLabel;

  /// No description provided for @bimOffsetDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get bimOffsetDistance;

  /// No description provided for @bimOffsetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get bimOffsetCopy;

  /// No description provided for @bimOffsetSide.
  ///
  /// In en, this message translates to:
  /// **'Pick a side'**
  String get bimOffsetSide;

  /// No description provided for @bimOffsetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Cannot offset. Check the selection, distance and side.'**
  String get bimOffsetInvalid;

  /// No description provided for @bimOffsetHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter a distance and pick a side. Copy creates parallel elements; uncheck it to change the selection. Connected segments meet at shared corners. Openings in closed contours stay in place. Copying a whole group creates a new group; copies made while editing a group stay in it. For branched chains or groups containing text and symbols, use Edit group to select applicable segments without branches. For walls, the distance is measured between core axes, independently of the drawing reference.'**
  String get bimOffsetHelp;

  /// Floor drain tool: wet-area floor with falls to a drain
  ///
  /// In en, this message translates to:
  /// **'Drain'**
  String get architectToolFloorDrain;

  /// Round floor drain
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get architectDrainRound;

  /// Linear channel floor drain
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get architectDrainLinear;

  /// Floor fall towards the drain
  ///
  /// In en, this message translates to:
  /// **'Fall'**
  String get architectDrainSlope;

  /// Round drain grate diameter
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get architectDrainDiameter;

  /// Linear drain length
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get architectDrainLength;

  /// Linear drain grate width
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectDrainWidth;

  /// Take the floor outline from the closed room under the click
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get architectDrainFromRoom;

  /// Draw the floor outline point by point
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get architectDrainOutline;

  /// Floor drain tool tooltip
  ///
  /// In en, this message translates to:
  /// **'Click the first point or the green tick to confirm the floor. Drag the grip to move the drain.'**
  String get architectDrainHint;

  /// Floor drain validation
  ///
  /// In en, this message translates to:
  /// **'Drain is outside the floor'**
  String get architectDrainOutsideFloor;

  /// Floor drain validation
  ///
  /// In en, this message translates to:
  /// **'Drain is close to a door'**
  String get architectDrainNearDoor;

  /// Floor drain automatic room detection failed
  ///
  /// In en, this message translates to:
  /// **'No closed room here'**
  String get architectDrainRoomNotFound;

  /// Floor drain placement rejected
  ///
  /// In en, this message translates to:
  /// **'Drain cannot be placed here'**
  String get architectDrainInvalid;

  /// No description provided for @architectSelectionDrainsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 drain} other{{count} drains}}'**
  String architectSelectionDrainsCount(int count);

  /// Linear shower channel floor drain component
  ///
  /// In en, this message translates to:
  /// **'Linear Floor Drain'**
  String get architectComponentLinearDrain;

  /// Round or square point floor drain component
  ///
  /// In en, this message translates to:
  /// **'Floor Drain'**
  String get architectComponentFloorDrain;

  /// Description in library dialog for the sloped floor drain tool
  ///
  /// In en, this message translates to:
  /// **'Draft wet room floor with falls and levels to drain'**
  String get architectFloorDrainLibraryDesc;

  /// Architectural views tool category
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get architectCategoryViews;

  /// Architectural section cut tool
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get architectToolSection;

  /// Architectural facade elevation tool
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectToolElevation;

  /// Action to open a section or elevation projection view
  ///
  /// In en, this message translates to:
  /// **'Open View'**
  String get architectOpenView;

  /// Action to open section view
  ///
  /// In en, this message translates to:
  /// **'Open Section'**
  String get architectOpenSection;

  /// Action to open elevation view
  ///
  /// In en, this message translates to:
  /// **'Open Elevation'**
  String get architectOpenElevation;

  /// Action to rename section or elevation
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get architectViewRename;

  /// Hint for placing a section line
  ///
  /// In en, this message translates to:
  /// **'Two points → direction'**
  String get architectSectionHint;

  /// Hint for placing an elevation line
  ///
  /// In en, this message translates to:
  /// **'Two points → direction'**
  String get architectElevationHint;

  /// Rectangular marquee selection mode
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get architectSelectModeRect;

  /// Polygonal marquee selection mode
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get architectSelectModePolygon;

  /// Hint for rectangular marquee selection
  ///
  /// In en, this message translates to:
  /// **'Click or drag opposite corners to select'**
  String get architectSelectMarqueeHint;

  /// Confirm button for polygon marquee selection
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get architectSelectFinish;

  /// No description provided for @architectFillSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get architectFillSolid;

  /// No description provided for @architectDrawingColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get architectDrawingColor;

  /// No description provided for @architectColorGeneral.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get architectColorGeneral;

  /// No description provided for @architectColorBgOup.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria · OUP'**
  String get architectColorBgOup;

  /// No description provided for @architectColorBgPup.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria · PUP'**
  String get architectColorBgPup;

  /// No description provided for @architectColorGermany.
  ///
  /// In en, this message translates to:
  /// **'Germany · PlanZV'**
  String get architectColorGermany;

  /// No description provided for @architectColorSearch.
  ///
  /// In en, this message translates to:
  /// **'Code or name'**
  String get architectColorSearch;

  /// No description provided for @architectColorCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get architectColorCustom;

  /// No description provided for @architectColorOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get architectColorOpacity;

  /// No description provided for @architectColorInfo.
  ///
  /// In en, this message translates to:
  /// **'About the palette'**
  String get architectColorInfo;

  /// No description provided for @architectColorHexError.
  ///
  /// In en, this message translates to:
  /// **'Enter six hexadecimal digits.'**
  String get architectColorHexError;

  /// No description provided for @architectColorApprox.
  ///
  /// In en, this message translates to:
  /// **'Screen colors are approximate. The RAL reference is stored separately; use a calibrated palette for precise print matching.'**
  String get architectColorApprox;

  /// No description provided for @architectColorBgInfo.
  ///
  /// In en, this message translates to:
  /// **'Ordinance No. 8, Annex 2: table 1 for OUP, table 2 for PUP. + and ++ mean lighter shades; − means darker. These are color palettes; complete planning symbols may also require borders, stripes and labels. PUP zone colors apply to PRZ/PZ drawings.'**
  String get architectColorBgInfo;

  /// No description provided for @architectColorDeInfo.
  ///
  /// In en, this message translates to:
  /// **'FNP/B-Plan color groups from PlanZV. The ordinance specifies named tones, not mandatory RGB or RAL codes. These are working approximations; complete planning symbols also include lines, hatching and labels.'**
  String get architectColorDeInfo;

  /// No description provided for @architectColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get architectColorBlack;

  /// No description provided for @architectColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get architectColorWhite;

  /// No description provided for @architectColorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get architectColorGray;

  /// No description provided for @architectColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get architectColorRed;

  /// No description provided for @architectColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get architectColorBlue;

  /// No description provided for @architectColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get architectColorGreen;

  /// No description provided for @architectColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get architectColorYellow;

  /// No description provided for @architectColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get architectColorOrange;

  /// No description provided for @architectColorResidential.
  ///
  /// In en, this message translates to:
  /// **'Residential use'**
  String get architectColorResidential;

  /// No description provided for @architectColorPublicServices.
  ///
  /// In en, this message translates to:
  /// **'Public services'**
  String get architectColorPublicServices;

  /// No description provided for @architectColorIndustrial.
  ///
  /// In en, this message translates to:
  /// **'Industrial use'**
  String get architectColorIndustrial;

  /// No description provided for @architectColorStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get architectColorStorage;

  /// No description provided for @architectColorGreenSpace.
  ///
  /// In en, this message translates to:
  /// **'Green space'**
  String get architectColorGreenSpace;

  /// No description provided for @architectColorArable.
  ///
  /// In en, this message translates to:
  /// **'Arable land'**
  String get architectColorArable;

  /// No description provided for @architectColorPerennial.
  ///
  /// In en, this message translates to:
  /// **'Permanent crops'**
  String get architectColorPerennial;

  /// No description provided for @architectColorUncultivated.
  ///
  /// In en, this message translates to:
  /// **'Uncultivated land'**
  String get architectColorUncultivated;

  /// No description provided for @architectColorForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get architectColorForest;

  /// No description provided for @architectColorRecreationalForest.
  ///
  /// In en, this message translates to:
  /// **'Recreational forest'**
  String get architectColorRecreationalForest;

  /// No description provided for @architectColorWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get architectColorWater;

  /// No description provided for @architectColorTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get architectColorTransport;

  /// No description provided for @architectColorUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get architectColorUtilities;

  /// No description provided for @architectColorHousingLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Housing zones · Zhm/Zhg'**
  String get architectColorHousingLowHigh;

  /// No description provided for @architectColorHousingMediumComplex.
  ///
  /// In en, this message translates to:
  /// **'Housing zones · Zhs/Zhk'**
  String get architectColorHousingMediumComplex;

  /// No description provided for @architectColorVillas.
  ///
  /// In en, this message translates to:
  /// **'Villa zones · base'**
  String get architectColorVillas;

  /// No description provided for @architectColorSpecialPurpose.
  ///
  /// In en, this message translates to:
  /// **'Special purpose'**
  String get architectColorSpecialPurpose;

  /// No description provided for @architectColorCulturalLand.
  ///
  /// In en, this message translates to:
  /// **'Cultural heritage land'**
  String get architectColorCulturalLand;

  /// No description provided for @architectColorPrimaryRoad.
  ///
  /// In en, this message translates to:
  /// **'Primary roads'**
  String get architectColorPrimaryRoad;

  /// No description provided for @architectColorSecondaryRoad.
  ///
  /// In en, this message translates to:
  /// **'Secondary roads'**
  String get architectColorSecondaryRoad;

  /// No description provided for @architectColorCollectingRoad.
  ///
  /// In en, this message translates to:
  /// **'Collector roads'**
  String get architectColorCollectingRoad;

  /// No description provided for @architectColorServingRoad.
  ///
  /// In en, this message translates to:
  /// **'Local roads and parking'**
  String get architectColorServingRoad;

  /// No description provided for @architectColorPedestrian.
  ///
  /// In en, this message translates to:
  /// **'Sidewalks and pedestrian areas'**
  String get architectColorPedestrian;

  /// No description provided for @architectColorHousingExisting.
  ///
  /// In en, this message translates to:
  /// **'Housing · existing'**
  String get architectColorHousingExisting;

  /// No description provided for @architectColorHousingNew.
  ///
  /// In en, this message translates to:
  /// **'Housing · proposed'**
  String get architectColorHousingNew;

  /// No description provided for @architectColorPublicExisting.
  ///
  /// In en, this message translates to:
  /// **'Public buildings · existing'**
  String get architectColorPublicExisting;

  /// No description provided for @architectColorPublicNew.
  ///
  /// In en, this message translates to:
  /// **'Public buildings · proposed'**
  String get architectColorPublicNew;

  /// No description provided for @architectColorHeritageBuilding.
  ///
  /// In en, this message translates to:
  /// **'Heritage buildings'**
  String get architectColorHeritageBuilding;

  /// No description provided for @architectColorMixedUse.
  ///
  /// In en, this message translates to:
  /// **'Mixed use'**
  String get architectColorMixedUse;

  /// No description provided for @architectColorSpecialUse.
  ///
  /// In en, this message translates to:
  /// **'Special building areas'**
  String get architectColorSpecialUse;

  /// No description provided for @architectColorRailway.
  ///
  /// In en, this message translates to:
  /// **'Railway land'**
  String get architectColorRailway;

  /// No description provided for @architectColorAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Agricultural land'**
  String get architectColorAgriculture;

  /// No description provided for @architectRotationPivot.
  ///
  /// In en, this message translates to:
  /// **'Pick centre'**
  String get architectRotationPivot;

  /// No description provided for @architectRotationReference.
  ///
  /// In en, this message translates to:
  /// **'Pick point on element'**
  String get architectRotationReference;

  /// No description provided for @architectRotationTarget.
  ///
  /// In en, this message translates to:
  /// **'Pick angle'**
  String get architectRotationTarget;

  /// No description provided for @architectRotationPickPivot.
  ///
  /// In en, this message translates to:
  /// **'Pick centre again'**
  String get architectRotationPickPivot;

  /// No description provided for @architectMirrorPickAnchor.
  ///
  /// In en, this message translates to:
  /// **'Pick anchor again'**
  String get architectMirrorPickAnchor;

  /// No description provided for @architectViewChooseArrow.
  ///
  /// In en, this message translates to:
  /// **'Choose an arrow'**
  String get architectViewChooseArrow;

  /// Toggle whether a component is visible in building sections
  ///
  /// In en, this message translates to:
  /// **'Visible in section'**
  String get architectVisibleInSection;

  /// Tooltip for one of the two viewing direction arrows
  ///
  /// In en, this message translates to:
  /// **'Viewing direction {side}'**
  String architectViewDirectionSide(int side);

  /// No description provided for @wallPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get wallPickerTitle;

  /// No description provided for @wallCategoryExterior.
  ///
  /// In en, this message translates to:
  /// **'Exterior'**
  String get wallCategoryExterior;

  /// No description provided for @wallCategoryInterior.
  ///
  /// In en, this message translates to:
  /// **'Interior'**
  String get wallCategoryInterior;

  /// No description provided for @wallCategoryParapet.
  ///
  /// In en, this message translates to:
  /// **'Parapets'**
  String get wallCategoryParapet;

  /// No description provided for @wallFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get wallFavorites;

  /// No description provided for @wallFavoriteToggle.
  ///
  /// In en, this message translates to:
  /// **'Favorite type'**
  String get wallFavoriteToggle;

  /// No description provided for @wallPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Type, material, thickness'**
  String get wallPickerSearch;

  /// No description provided for @wallPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get wallPickerEmpty;

  /// No description provided for @wallVariantCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 variant} other{{count} variants}}'**
  String wallVariantCount(int count);

  /// No description provided for @wallVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get wallVariant;

  /// No description provided for @wallNewVariant.
  ///
  /// In en, this message translates to:
  /// **'New variant'**
  String get wallNewVariant;

  /// No description provided for @wallTypesShort.
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get wallTypesShort;

  /// No description provided for @wallNoInsulation.
  ///
  /// In en, this message translates to:
  /// **'Uninsulated'**
  String get wallNoInsulation;

  /// No description provided for @wallParapetCap.
  ///
  /// In en, this message translates to:
  /// **'Coping cap'**
  String get wallParapetCap;

  /// No description provided for @wallParapetHandrail.
  ///
  /// In en, this message translates to:
  /// **'Handrail'**
  String get wallParapetHandrail;

  /// No description provided for @wallMaterialThickness.
  ///
  /// In en, this message translates to:
  /// **'{material} {thickness}'**
  String wallMaterialThickness(String material, String thickness);

  /// No description provided for @wallNewTypeScope.
  ///
  /// In en, this message translates to:
  /// **'New type · existing walls are preserved'**
  String get wallNewTypeScope;

  /// No description provided for @wallOptionalName.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get wallOptionalName;

  /// No description provided for @wallSaveToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Save as type'**
  String get wallSaveToCatalog;

  /// No description provided for @wallLayerDetails.
  ///
  /// In en, this message translates to:
  /// **'Layer details'**
  String get wallLayerDetails;

  /// No description provided for @wallTypeDetails.
  ///
  /// In en, this message translates to:
  /// **'Type details'**
  String get wallTypeDetails;

  /// No description provided for @wallLayerPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get wallLayerPosition;

  /// No description provided for @wallLayerBefore.
  ///
  /// In en, this message translates to:
  /// **'Before {layer}'**
  String wallLayerBefore(String layer);

  /// No description provided for @wallLayerAtEnd.
  ///
  /// In en, this message translates to:
  /// **'At end'**
  String get wallLayerAtEnd;

  /// No description provided for @wallLayerMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get wallLayerMaterial;

  /// No description provided for @wallLayerCoatings.
  ///
  /// In en, this message translates to:
  /// **'Finishes'**
  String get wallLayerCoatings;

  /// No description provided for @wallCopyFinish.
  ///
  /// In en, this message translates to:
  /// **'Copy A → B'**
  String get wallCopyFinish;

  /// No description provided for @wallCopyFinishHelp.
  ///
  /// In en, this message translates to:
  /// **'Copy finishes from A to unfinished side B'**
  String get wallCopyFinishHelp;

  /// No description provided for @wallLayerCoreError.
  ///
  /// In en, this message translates to:
  /// **'The core must be continuous and use base materials.'**
  String get wallLayerCoreError;

  /// No description provided for @wallDrawingMode.
  ///
  /// In en, this message translates to:
  /// **'Drawing mode'**
  String get wallDrawingMode;

  /// No description provided for @wallParapetDefaultHeight.
  ///
  /// In en, this message translates to:
  /// **'Default height'**
  String get wallParapetDefaultHeight;

  /// No description provided for @wallCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get wallCreate;

  /// No description provided for @wallLayerLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to 20 layers are supported.'**
  String get wallLayerLimit;

  /// No description provided for @wallInvalidHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive height.'**
  String get wallInvalidHeight;

  /// No description provided for @wallParapetGroup.
  ///
  /// In en, this message translates to:
  /// **'{finish} · {material}'**
  String wallParapetGroup(String finish, String material);

  /// No description provided for @roofUiShape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get roofUiShape;

  /// No description provided for @roofUiAssembly.
  ///
  /// In en, this message translates to:
  /// **'Build-up'**
  String get roofUiAssembly;

  /// No description provided for @roofUiDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get roofUiDetails;

  /// No description provided for @roofUiSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get roofUiSettings;

  /// No description provided for @roofUiMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get roofUiMethod;

  /// No description provided for @roofUiOnlyPlane.
  ///
  /// In en, this message translates to:
  /// **'This plane'**
  String get roofUiOnlyPlane;

  /// No description provided for @roofUiWholeRoof.
  ///
  /// In en, this message translates to:
  /// **'Whole roof ({count})'**
  String roofUiWholeRoof(int count);

  /// No description provided for @roofUiNewScope.
  ///
  /// In en, this message translates to:
  /// **'For new roofs'**
  String get roofUiNewScope;

  /// No description provided for @roofUiSaveDefaults.
  ///
  /// In en, this message translates to:
  /// **'Use for future roofs'**
  String get roofUiSaveDefaults;

  /// No description provided for @roofSaveLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get roofSaveLibrary;

  /// No description provided for @roofDeleteLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete from library'**
  String get roofDeleteLibrary;

  /// No description provided for @roofLibrarySaved.
  ///
  /// In en, this message translates to:
  /// **'Roof build-up saved to library.'**
  String get roofLibrarySaved;

  /// No description provided for @roofLibraryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Roof build-up deleted from library.'**
  String get roofLibraryDeleted;

  /// No description provided for @roofDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from personal library?'**
  String roofDeleteConfirm(String name);

  /// No description provided for @roofCustomNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Build-up name'**
  String get roofCustomNamePrompt;

  /// No description provided for @roofUiScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'Only edited fields change. Pipe positions stay with their own plane.'**
  String get roofUiScopeHelp;

  /// No description provided for @roofUiIndependentHelp.
  ///
  /// In en, this message translates to:
  /// **'Changing one pitch makes the plane independent.'**
  String get roofUiIndependentHelp;

  /// No description provided for @roofUiPreview.
  ///
  /// In en, this message translates to:
  /// **'Diagram'**
  String get roofUiPreview;

  /// No description provided for @roofUiPreviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Section follows the current settings. Tap to zoom.'**
  String get roofUiPreviewHelp;

  /// No description provided for @roofUiNumericInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid value.'**
  String get roofUiNumericInvalid;

  /// No description provided for @roofUiLayerPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get roofUiLayerPosition;

  /// No description provided for @roofUiBeforeLayer.
  ///
  /// In en, this message translates to:
  /// **'Before {layer}'**
  String roofUiBeforeLayer(String layer);

  /// No description provided for @roofUiLayerEnd.
  ///
  /// In en, this message translates to:
  /// **'At end'**
  String get roofUiLayerEnd;

  /// No description provided for @roofUiAbove.
  ///
  /// In en, this message translates to:
  /// **'Above rafters'**
  String get roofUiAbove;

  /// No description provided for @roofUiBetween.
  ///
  /// In en, this message translates to:
  /// **'Between rafters'**
  String get roofUiBetween;

  /// No description provided for @roofUiBelow.
  ///
  /// In en, this message translates to:
  /// **'Below rafters'**
  String get roofUiBelow;

  /// No description provided for @roofUiLayerActions.
  ///
  /// In en, this message translates to:
  /// **'Layer actions'**
  String get roofUiLayerActions;

  /// No description provided for @roofUiLayerEdit.
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get roofUiLayerEdit;

  /// No description provided for @roofUiStructureZone.
  ///
  /// In en, this message translates to:
  /// **'Structural zone'**
  String get roofUiStructureZone;

  /// No description provided for @roofUiInsulationFit.
  ///
  /// In en, this message translates to:
  /// **'Between-rafter insulation exceeds the rafter depth.'**
  String get roofUiInsulationFit;

  /// No description provided for @roofUiParallelZone.
  ///
  /// In en, this message translates to:
  /// **'Use one entry for the shared rafter and between-rafter zone.'**
  String get roofUiParallelZone;

  /// No description provided for @roofUiAutoBreak.
  ///
  /// In en, this message translates to:
  /// **'Automatic break position'**
  String get roofUiAutoBreak;

  /// No description provided for @roofUiPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 point} other{{count} points}}'**
  String roofUiPoints(int count);

  /// No description provided for @roofUiAutoPreview.
  ///
  /// In en, this message translates to:
  /// **'New roof'**
  String get roofUiAutoPreview;

  /// No description provided for @roofUiAddRoof.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get roofUiAddRoof;

  /// No description provided for @roofUiReplaceRoof.
  ///
  /// In en, this message translates to:
  /// **'Replace roof {index} ({count})'**
  String roofUiReplaceRoof(int index, int count);

  /// No description provided for @roofUiCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get roofUiCreate;

  /// No description provided for @roofUiReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get roofUiReplace;

  /// No description provided for @roofUiTarget.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get roofUiTarget;

  /// No description provided for @roofUiGeneratedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 plane} other{{count} planes}}'**
  String roofUiGeneratedCount(int count);

  /// No description provided for @roofUiReviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Other roofs are preserved.'**
  String get roofUiReviewHelp;

  /// No description provided for @roofUiUntouched.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get roofUiUntouched;

  /// No description provided for @roofUiReplaceFloor.
  ///
  /// In en, this message translates to:
  /// **'All on storey ({count})'**
  String roofUiReplaceFloor(int count);

  /// No description provided for @roofUiNewLegend.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get roofUiNewLegend;

  /// No description provided for @roofUiKeptLegend.
  ///
  /// In en, this message translates to:
  /// **'Preserved'**
  String get roofUiKeptLegend;

  /// No description provided for @architectHatchTransformHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate the hatch and change its scale. Scale snaps in 10% steps; direction snaps every 45°.'**
  String get architectHatchTransformHelp;

  /// No description provided for @wallSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get wallSystem;

  /// No description provided for @wallSystemLayered.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get wallSystemLayered;

  /// No description provided for @wallSystemLogs.
  ///
  /// In en, this message translates to:
  /// **'Round logs'**
  String get wallSystemLogs;

  /// No description provided for @wallSystemFrame.
  ///
  /// In en, this message translates to:
  /// **'Stud partition'**
  String get wallSystemFrame;

  /// No description provided for @wallSystemPanels.
  ///
  /// In en, this message translates to:
  /// **'Sandwich panels'**
  String get wallSystemPanels;

  /// No description provided for @wallMaterialSteel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get wallMaterialSteel;

  /// No description provided for @wallMaterialPir.
  ///
  /// In en, this message translates to:
  /// **'PIR'**
  String get wallMaterialPir;

  /// No description provided for @wallLogOverlap.
  ///
  /// In en, this message translates to:
  /// **'Overlap (%)'**
  String get wallLogOverlap;

  /// No description provided for @wallLogTail.
  ///
  /// In en, this message translates to:
  /// **'End extension (× diameter)'**
  String get wallLogTail;

  /// No description provided for @wallLogPitch.
  ///
  /// In en, this message translates to:
  /// **'Course height'**
  String get wallLogPitch;

  /// No description provided for @wallStudSpacing.
  ///
  /// In en, this message translates to:
  /// **'Profile spacing'**
  String get wallStudSpacing;

  /// No description provided for @wallStudWidth.
  ///
  /// In en, this message translates to:
  /// **'Profile width'**
  String get wallStudWidth;

  /// No description provided for @wallMetalThickness.
  ///
  /// In en, this message translates to:
  /// **'Metal thickness'**
  String get wallMetalThickness;

  /// No description provided for @wallCavityInsulation.
  ///
  /// In en, this message translates to:
  /// **'Cavity insulation'**
  String get wallCavityInsulation;

  /// No description provided for @wallSupportDepth.
  ///
  /// In en, this message translates to:
  /// **'Support depth'**
  String get wallSupportDepth;

  /// No description provided for @wallPanelModule.
  ///
  /// In en, this message translates to:
  /// **'Panel width'**
  String get wallPanelModule;

  /// No description provided for @wallPanelMount.
  ///
  /// In en, this message translates to:
  /// **'Mounting'**
  String get wallPanelMount;

  /// No description provided for @wallPanelInFront.
  ///
  /// In en, this message translates to:
  /// **'In front of columns'**
  String get wallPanelInFront;

  /// No description provided for @wallPanelBetween.
  ///
  /// In en, this message translates to:
  /// **'Between columns'**
  String get wallPanelBetween;

  /// No description provided for @wallPanelsHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal panels'**
  String get wallPanelsHorizontal;

  /// No description provided for @wallSystemInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the construction dimensions.'**
  String get wallSystemInvalid;

  /// No description provided for @wallSystemStraightOnly.
  ///
  /// In en, this message translates to:
  /// **'This system uses straight walls.'**
  String get wallSystemStraightOnly;

  /// No description provided for @wallLogHelp.
  ///
  /// In en, this message translates to:
  /// **'Plans show the nominal diameter. Sections and 3D retain round logs, overlap and alternating corner courses.'**
  String get wallLogHelp;

  /// No description provided for @wallFrameHelp.
  ///
  /// In en, this message translates to:
  /// **'Boards, profiles and cavity insulation have independent dimensions.'**
  String get wallFrameHelp;

  /// No description provided for @wallPanelHelp.
  ///
  /// In en, this message translates to:
  /// **'Panel and support depth are separate. Supports attach to the selected column faces.'**
  String get wallPanelHelp;

  /// No description provided for @wallColumnSupports.
  ///
  /// In en, this message translates to:
  /// **'Column supports'**
  String get wallColumnSupports;

  /// No description provided for @wallMountingOffset.
  ///
  /// In en, this message translates to:
  /// **'Mounting offset'**
  String get wallMountingOffset;

  /// No description provided for @wallMissingSupports.
  ///
  /// In en, this message translates to:
  /// **'A support column is missing. Select its replacement.'**
  String get wallMissingSupports;

  /// No description provided for @wallLogCasing.
  ///
  /// In en, this message translates to:
  /// **'Opening casing'**
  String get wallLogCasing;

  /// No description provided for @wallLogCasingWidth.
  ///
  /// In en, this message translates to:
  /// **'Casing width'**
  String get wallLogCasingWidth;

  /// No description provided for @wallLogSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement allowance'**
  String get wallLogSettlement;

  /// No description provided for @architectRoofPresetLogTimber.
  ///
  /// In en, this message translates to:
  /// **'Timber · logs'**
  String get architectRoofPresetLogTimber;

  /// No description provided for @wallLogDiameter.
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get wallLogDiameter;

  /// No description provided for @wallRemoveMissingSupports.
  ///
  /// In en, this message translates to:
  /// **'Remove missing'**
  String get wallRemoveMissingSupports;

  /// No description provided for @roofPanelPitched.
  ///
  /// In en, this message translates to:
  /// **'Panels · pitched'**
  String get roofPanelPitched;

  /// No description provided for @roofPanelMembrane.
  ///
  /// In en, this message translates to:
  /// **'Panels · membrane'**
  String get roofPanelMembrane;

  /// No description provided for @roofPanelThickness.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get roofPanelThickness;

  /// No description provided for @roofPanelSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get roofPanelSkin;

  /// No description provided for @roofPanelModule.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get roofPanelModule;

  /// No description provided for @roofPanelRib.
  ///
  /// In en, this message translates to:
  /// **'Rib height'**
  String get roofPanelRib;

  /// No description provided for @roofPanelMinSlope.
  ///
  /// In en, this message translates to:
  /// **'Min. pitch'**
  String get roofPanelMinSlope;

  /// No description provided for @roofPanelFrame.
  ///
  /// In en, this message translates to:
  /// **'Steel frame'**
  String get roofPanelFrame;

  /// No description provided for @roofPanelBeamDepth.
  ///
  /// In en, this message translates to:
  /// **'Beam depth'**
  String get roofPanelBeamDepth;

  /// No description provided for @roofPanelBeamWidth.
  ///
  /// In en, this message translates to:
  /// **'Beam width'**
  String get roofPanelBeamWidth;

  /// No description provided for @roofPanelWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get roofPanelWeb;

  /// No description provided for @roofPanelFlange.
  ///
  /// In en, this message translates to:
  /// **'Flange'**
  String get roofPanelFlange;

  /// No description provided for @roofPanelFramesSpacing.
  ///
  /// In en, this message translates to:
  /// **'Frame spacing'**
  String get roofPanelFramesSpacing;

  /// No description provided for @roofPanelPurlinDepth.
  ///
  /// In en, this message translates to:
  /// **'Purlin depth'**
  String get roofPanelPurlinDepth;

  /// No description provided for @roofPanelPurlinWidth.
  ///
  /// In en, this message translates to:
  /// **'Purlin flange'**
  String get roofPanelPurlinWidth;

  /// No description provided for @roofPanelPurlinMetal.
  ///
  /// In en, this message translates to:
  /// **'Purlin gauge'**
  String get roofPanelPurlinMetal;

  /// No description provided for @roofPanelPurlinSpacing.
  ///
  /// In en, this message translates to:
  /// **'Purlin spacing'**
  String get roofPanelPurlinSpacing;

  /// No description provided for @roofPanelCutback.
  ///
  /// In en, this message translates to:
  /// **'Core cutback'**
  String get roofPanelCutback;

  /// No description provided for @roofPanelUpstand.
  ///
  /// In en, this message translates to:
  /// **'Upstand'**
  String get roofPanelUpstand;

  /// No description provided for @roofPanelInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the panel and frame dimensions.'**
  String get roofPanelInvalid;

  /// No description provided for @roofPanelSlopeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Pitch is below the minimum for this system.'**
  String get roofPanelSlopeInvalid;

  /// No description provided for @roofPanelHelp.
  ///
  /// In en, this message translates to:
  /// **'Continuous panels on Z purlins and I beams. Set dimensions and minimum pitch for the selected system.'**
  String get roofPanelHelp;

  /// No description provided for @roofPanelColumns.
  ///
  /// In en, this message translates to:
  /// **'Supporting columns'**
  String get roofPanelColumns;

  /// No description provided for @roofGutterPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get roofGutterPosition;

  /// No description provided for @roofGutterExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get roofGutterExternal;

  /// No description provided for @roofGutterInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get roofGutterInternal;

  /// No description provided for @roofGutterInternalHelp.
  ///
  /// In en, this message translates to:
  /// **'Open box channel at the roof edge. The pipe drops vertically; a structural collision requires another outlet or an opening.'**
  String get roofGutterInternalHelp;

  /// No description provided for @architectOffsetOuterContour.
  ///
  /// In en, this message translates to:
  /// **'Outer contour'**
  String get architectOffsetOuterContour;

  /// No description provided for @architectOffsetInnerContour.
  ///
  /// In en, this message translates to:
  /// **'Opening contour'**
  String get architectOffsetInnerContour;

  /// No description provided for @architectOffsetContourHint.
  ///
  /// In en, this message translates to:
  /// **'Offset every edge of the selected contour. Positive values expand it; negative values shrink it.'**
  String get architectOffsetContourHint;

  /// No description provided for @architectToolPan.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get architectToolPan;

  /// No description provided for @architectSelectionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get architectSelectionClear;

  /// No description provided for @architectSelectRectangleHint.
  ///
  /// In en, this message translates to:
  /// **'Pick two opposite corners or drag a box. Use two fingers to pan.'**
  String get architectSelectRectangleHint;

  /// Hint for polygon marquee selection
  ///
  /// In en, this message translates to:
  /// **'Place vertices and close the polygon at its first point or with the check button.'**
  String get architectSelectPolygonHint;

  /// No description provided for @architectCategoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get architectCategoryEdit;

  /// No description provided for @architectSelectReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get architectSelectReplace;

  /// No description provided for @architectSelectAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get architectSelectAdd;

  /// No description provided for @architectSelectRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get architectSelectRemove;

  /// No description provided for @architectSelectCrossing.
  ///
  /// In en, this message translates to:
  /// **'Crossing'**
  String get architectSelectCrossing;

  /// No description provided for @architectSelectContained.
  ///
  /// In en, this message translates to:
  /// **'Inside'**
  String get architectSelectContained;

  /// No description provided for @architectSelectCrossingHelp.
  ///
  /// In en, this message translates to:
  /// **'Select elements inside or crossing the selection boundary.'**
  String get architectSelectCrossingHelp;

  /// No description provided for @architectSelectContainedHelp.
  ///
  /// In en, this message translates to:
  /// **'Select only elements entirely inside the selection boundary.'**
  String get architectSelectContainedHelp;

  /// No description provided for @architectSelectPreviewCount.
  ///
  /// In en, this message translates to:
  /// **'After selection: {count}'**
  String architectSelectPreviewCount(int count);

  /// No description provided for @wallLogSize.
  ///
  /// In en, this message translates to:
  /// **'Diameter {size}'**
  String wallLogSize(String size);

  /// No description provided for @wallChooseType.
  ///
  /// In en, this message translates to:
  /// **'Choose type'**
  String get wallChooseType;

  /// No description provided for @wallSystemOptions.
  ///
  /// In en, this message translates to:
  /// **'Construction details'**
  String get wallSystemOptions;

  /// Tooltip for drawing another element of the selected type
  ///
  /// In en, this message translates to:
  /// **'Start drawing: {tool}'**
  String architectDrawSelectedType(String tool);

  /// No description provided for @architectToolComponent.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get architectToolComponent;

  /// No description provided for @architectProjectionLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating view…'**
  String get architectProjectionLoading;

  /// No description provided for @architectProjectionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate the view.'**
  String get architectProjectionLoadFailed;

  /// No description provided for @wallMaterialAeratedConcrete.
  ///
  /// In en, this message translates to:
  /// **'Aerated concrete'**
  String get wallMaterialAeratedConcrete;

  /// No description provided for @wallAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get wallAutomatic;

  /// No description provided for @wallManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get wallManual;

  /// No description provided for @wallExteriorSideLabel.
  ///
  /// In en, this message translates to:
  /// **'Exterior side'**
  String get wallExteriorSideLabel;

  /// No description provided for @wallLocationAutoHelp.
  ///
  /// In en, this message translates to:
  /// **'Determines wall location from the closed contours of the storey.'**
  String get wallLocationAutoHelp;

  /// No description provided for @wallSideAutoHelp.
  ///
  /// In en, this message translates to:
  /// **'Points the exterior side outwards. Flipping manually preserves your chosen side.'**
  String get wallSideAutoHelp;

  /// No description provided for @wallTypeLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Initial value; automatic detection refines it from the contour.'**
  String get wallTypeLocationHint;

  /// No description provided for @wallExteriorUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Some walls need their location or exterior side specified.'**
  String get wallExteriorUnresolved;

  /// No description provided for @wallExteriorReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get wallExteriorReview;

  /// No description provided for @architectPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose element'**
  String get architectPickTitle;

  /// No description provided for @architectPickPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous element'**
  String get architectPickPrevious;

  /// No description provided for @architectPickNext.
  ///
  /// In en, this message translates to:
  /// **'Next element'**
  String get architectPickNext;

  /// No description provided for @architectPickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to selection'**
  String get architectPickAdd;

  /// No description provided for @architectPickRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from selection'**
  String get architectPickRemove;

  /// No description provided for @architectPickNamed.
  ///
  /// In en, this message translates to:
  /// **'{type} · {name}'**
  String architectPickNamed(String type, String name);

  /// No description provided for @architectPickItem.
  ///
  /// In en, this message translates to:
  /// **'{label} · {index}'**
  String architectPickItem(String label, int index);

  /// No description provided for @architectPickPosition.
  ///
  /// In en, this message translates to:
  /// **'{label} · {index}/{count}'**
  String architectPickPosition(String label, int index, int count);

  /// No description provided for @architectTouchSelectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap to select; use arrows for overlaps. Hold for actions.'**
  String get architectTouchSelectionHelp;

  /// No description provided for @architectSelectAll.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get architectSelectAll;

  /// No description provided for @propertiesBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get propertiesBasic;

  /// No description provided for @propertiesMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get propertiesMore;

  /// No description provided for @propertiesExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get propertiesExpand;

  /// No description provided for @propertiesCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get propertiesCollapse;

  /// No description provided for @propertiesUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get propertiesUnsaved;

  /// No description provided for @propertiesUnsavedHelp.
  ///
  /// In en, this message translates to:
  /// **'Save your changes or discard them before closing.'**
  String get propertiesUnsavedHelp;

  /// No description provided for @propertiesStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get propertiesStay;

  /// No description provided for @propertiesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get propertiesDiscard;

  /// No description provided for @propertiesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get propertiesInvalid;

  /// No description provided for @propertiesStale.
  ///
  /// In en, this message translates to:
  /// **'The document changed. Reopen properties to edit the current version.'**
  String get propertiesStale;

  /// No description provided for @propertiesAutomaticValue.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get propertiesAutomaticValue;

  /// No description provided for @propertiesCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get propertiesCalculated;

  /// No description provided for @propertiesSelection.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count})'**
  String propertiesSelection(String name, int count);

  /// No description provided for @propertiesGeometry.
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get propertiesGeometry;

  /// No description provided for @propertiesAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get propertiesAppearance;

  /// No description provided for @propertiesManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get propertiesManual;

  /// No description provided for @propertiesClear.
  ///
  /// In en, this message translates to:
  /// **'Clear value'**
  String get propertiesClear;

  /// No description provided for @propertiesDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get propertiesDone;

  /// No description provided for @propertiesSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get propertiesSource;

  /// No description provided for @propertiesScopeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected elements'**
  String get propertiesScopeSelected;

  /// No description provided for @propertiesRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get propertiesRadius;

  /// No description provided for @propertiesTextHeight.
  ///
  /// In en, this message translates to:
  /// **'Text height'**
  String get propertiesTextHeight;

  /// No description provided for @propertiesSaveOpen.
  ///
  /// In en, this message translates to:
  /// **'Save and open'**
  String get propertiesSaveOpen;

  /// No description provided for @propertiesSlope.
  ///
  /// In en, this message translates to:
  /// **'Slope'**
  String get propertiesSlope;

  /// No description provided for @propertiesBaseOffset.
  ///
  /// In en, this message translates to:
  /// **'Base offset'**
  String get propertiesBaseOffset;

  /// No description provided for @propertiesMixedCompositionHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a type to replace the selected compositions.'**
  String get propertiesMixedCompositionHelp;

  /// No description provided for @propertiesDiameter.
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get propertiesDiameter;

  /// No description provided for @commandIconAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commandIconAdd;

  /// No description provided for @commandIconRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commandIconRemove;

  /// No description provided for @commandIconClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commandIconClose;

  /// No description provided for @commandIconConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commandIconConfirm;

  /// No description provided for @commandIconAddBox.
  ///
  /// In en, this message translates to:
  /// **'Add to selection'**
  String get commandIconAddBox;

  /// No description provided for @commandIconAddCircle.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get commandIconAddCircle;

  /// No description provided for @commandIconRemoveCircle.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get commandIconRemoveCircle;

  /// No description provided for @commandIconCheckBox.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get commandIconCheckBox;

  /// No description provided for @commandIconCheckBoxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get commandIconCheckBoxEmpty;

  /// No description provided for @commandIconRemoveBox.
  ///
  /// In en, this message translates to:
  /// **'Subtract from selection'**
  String get commandIconRemoveBox;

  /// No description provided for @commandIconCheckCircle.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get commandIconCheckCircle;

  /// No description provided for @commandIconRadioOn.
  ///
  /// In en, this message translates to:
  /// **'Active option'**
  String get commandIconRadioOn;

  /// No description provided for @commandIconRadioOff.
  ///
  /// In en, this message translates to:
  /// **'Inactive option'**
  String get commandIconRadioOff;

  /// No description provided for @commandIconBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commandIconBack;

  /// No description provided for @commandIconForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get commandIconForward;

  /// No description provided for @commandIconUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get commandIconUp;

  /// No description provided for @commandIconDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get commandIconDown;

  /// No description provided for @commandIconChevronLeft.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commandIconChevronLeft;

  /// No description provided for @commandIconChevronRight.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commandIconChevronRight;

  /// No description provided for @commandIconExpandLess.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get commandIconExpandLess;

  /// No description provided for @commandIconExpandMore.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get commandIconExpandMore;

  /// No description provided for @commandIconFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get commandIconFirstPage;

  /// No description provided for @commandIconLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get commandIconLastPage;

  /// No description provided for @commandIconOutward.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get commandIconOutward;

  /// No description provided for @commandIconDiagonalDown.
  ///
  /// In en, this message translates to:
  /// **'Move diagonally'**
  String get commandIconDiagonalDown;

  /// No description provided for @commandIconMoreHorizontal.
  ///
  /// In en, this message translates to:
  /// **'More commands'**
  String get commandIconMoreHorizontal;

  /// No description provided for @commandIconMoreVertical.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get commandIconMoreVertical;

  /// No description provided for @commandIconSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commandIconSearch;

  /// No description provided for @commandIconSearchOff.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commandIconSearchOff;

  /// No description provided for @commandIconZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get commandIconZoomIn;

  /// No description provided for @commandIconZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get commandIconZoomOut;

  /// No description provided for @commandIconRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commandIconRefresh;

  /// No description provided for @commandIconSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get commandIconSync;

  /// No description provided for @commandIconSyncProblem.
  ///
  /// In en, this message translates to:
  /// **'Synchronization issue'**
  String get commandIconSyncProblem;

  /// No description provided for @commandIconUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commandIconUndo;

  /// No description provided for @commandIconRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get commandIconRedo;

  /// No description provided for @commandIconHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get commandIconHistory;

  /// No description provided for @commandIconSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commandIconSettings;

  /// No description provided for @commandIconProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get commandIconProperties;

  /// No description provided for @commandIconInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get commandIconInfo;

  /// No description provided for @commandIconHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get commandIconHelp;

  /// No description provided for @commandIconWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get commandIconWarning;

  /// No description provided for @commandIconError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commandIconError;

  /// No description provided for @commandIconFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commandIconFilter;

  /// No description provided for @commandIconFilterOff.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get commandIconFilterOff;

  /// No description provided for @commandIconFilterList.
  ///
  /// In en, this message translates to:
  /// **'Filter list'**
  String get commandIconFilterList;

  /// No description provided for @commandIconSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commandIconSort;

  /// No description provided for @commandIconDrag.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get commandIconDrag;

  /// No description provided for @commandIconClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get commandIconClearAll;

  /// No description provided for @commandIconBackspace.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get commandIconBackspace;

  /// No description provided for @commandIconSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commandIconSelect;

  /// No description provided for @commandIconSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get commandIconSelectAll;

  /// No description provided for @commandIconDeselect.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get commandIconDeselect;

  /// No description provided for @commandIconMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multiple selection'**
  String get commandIconMultiSelect;

  /// No description provided for @commandIconPan.
  ///
  /// In en, this message translates to:
  /// **'Pan'**
  String get commandIconPan;

  /// No description provided for @commandIconMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get commandIconMove;

  /// No description provided for @commandIconMoveTransverse.
  ///
  /// In en, this message translates to:
  /// **'Move perpendicular'**
  String get commandIconMoveTransverse;

  /// No description provided for @commandIconDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get commandIconDuplicate;

  /// No description provided for @commandIconEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commandIconEdit;

  /// No description provided for @commandIconRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commandIconRename;

  /// No description provided for @commandIconDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commandIconDelete;

  /// No description provided for @commandIconDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get commandIconDeleteAll;

  /// No description provided for @commandIconRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get commandIconRotate;

  /// No description provided for @commandIconRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get commandIconRotateLeft;

  /// No description provided for @commandIconMirrorMove.
  ///
  /// In en, this message translates to:
  /// **'Mirror and move'**
  String get commandIconMirrorMove;

  /// No description provided for @commandIconMirrorCopy.
  ///
  /// In en, this message translates to:
  /// **'Mirror and copy'**
  String get commandIconMirrorCopy;

  /// No description provided for @commandIconFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip horizontally'**
  String get commandIconFlipHorizontal;

  /// No description provided for @commandIconFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip vertically'**
  String get commandIconFlipVertical;

  /// No description provided for @commandIconSwapHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Swap horizontally'**
  String get commandIconSwapHorizontal;

  /// No description provided for @commandIconSwapVertical.
  ///
  /// In en, this message translates to:
  /// **'Swap vertically'**
  String get commandIconSwapVertical;

  /// No description provided for @commandIconSplit.
  ///
  /// In en, this message translates to:
  /// **'Split element'**
  String get commandIconSplit;

  /// No description provided for @commandIconCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get commandIconCut;

  /// No description provided for @commandIconCutOpening.
  ///
  /// In en, this message translates to:
  /// **'Cut opening'**
  String get commandIconCutOpening;

  /// No description provided for @commandIconOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get commandIconOffset;

  /// No description provided for @commandIconNewPoint.
  ///
  /// In en, this message translates to:
  /// **'New point'**
  String get commandIconNewPoint;

  /// No description provided for @commandIconJoin.
  ///
  /// In en, this message translates to:
  /// **'Join elements'**
  String get commandIconJoin;

  /// No description provided for @commandIconStraighten.
  ///
  /// In en, this message translates to:
  /// **'Straighten'**
  String get commandIconStraighten;

  /// No description provided for @commandIconGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get commandIconGroup;

  /// No description provided for @commandIconUngroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get commandIconUngroup;

  /// No description provided for @commandIconEditGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get commandIconEditGroup;

  /// No description provided for @commandIconFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get commandIconFile;

  /// No description provided for @commandIconOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get commandIconOpenFile;

  /// No description provided for @commandIconFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get commandIconFolder;

  /// No description provided for @commandIconOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get commandIconOpenFolder;

  /// No description provided for @commandIconNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get commandIconNewFolder;

  /// No description provided for @commandIconCopyFolder.
  ///
  /// In en, this message translates to:
  /// **'Copy folder'**
  String get commandIconCopyFolder;

  /// No description provided for @commandIconFolderOff.
  ///
  /// In en, this message translates to:
  /// **'Unavailable folder'**
  String get commandIconFolderOff;

  /// No description provided for @commandIconFolderFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite folder'**
  String get commandIconFolderFavorite;

  /// No description provided for @commandIconArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commandIconArchive;

  /// No description provided for @commandIconSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commandIconSave;

  /// No description provided for @commandIconSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get commandIconSaveAs;

  /// No description provided for @commandIconDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commandIconDownload;

  /// No description provided for @commandIconUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get commandIconUpload;

  /// No description provided for @commandIconPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get commandIconPrint;

  /// No description provided for @commandIconShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commandIconShare;

  /// No description provided for @commandIconLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get commandIconLink;

  /// No description provided for @commandIconUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get commandIconUnlink;

  /// No description provided for @commandIconExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in new window'**
  String get commandIconExternal;

  /// No description provided for @commandIconThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get commandIconThemeDark;

  /// No description provided for @commandIconThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get commandIconThemeLight;

  /// No description provided for @commandIconThemeAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic theme'**
  String get commandIconThemeAuto;

  /// No description provided for @commandIconLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get commandIconLanguage;

  /// No description provided for @commandIconUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get commandIconUpdate;

  /// No description provided for @commandIconBug.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get commandIconBug;

  /// No description provided for @commandIconHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get commandIconHome;

  /// No description provided for @commandIconFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get commandIconFavorite;

  /// No description provided for @commandIconStar.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get commandIconStar;

  /// No description provided for @commandIconBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get commandIconBookmark;

  /// No description provided for @commandIconBookmarkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get commandIconBookmarkAdd;

  /// No description provided for @commandIconBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get commandIconBookmarks;

  /// No description provided for @commandIconEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commandIconEmail;

  /// No description provided for @commandIconWifi.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get commandIconWifi;

  /// No description provided for @commandIconWifiOff.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable'**
  String get commandIconWifiOff;

  /// No description provided for @commandIconComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get commandIconComputer;

  /// No description provided for @commandIconStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get commandIconStorage;

  /// No description provided for @commandIconPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get commandIconPayment;

  /// No description provided for @commandIconSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get commandIconSecurity;

  /// No description provided for @commandIconVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get commandIconVerified;

  /// No description provided for @commandIconLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get commandIconLock;

  /// No description provided for @commandIconUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get commandIconUnlock;

  /// No description provided for @commandIconWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get commandIconWall;

  /// No description provided for @commandIconDoor.
  ///
  /// In en, this message translates to:
  /// **'Door'**
  String get commandIconDoor;

  /// No description provided for @commandIconWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get commandIconWindow;

  /// No description provided for @commandIconColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get commandIconColumn;

  /// No description provided for @commandIconBeam.
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get commandIconBeam;

  /// No description provided for @commandIconSlab.
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get commandIconSlab;

  /// No description provided for @commandIconOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get commandIconOpening;

  /// No description provided for @commandIconRoof.
  ///
  /// In en, this message translates to:
  /// **'Roof'**
  String get commandIconRoof;

  /// No description provided for @commandIconStairs.
  ///
  /// In en, this message translates to:
  /// **'Stair'**
  String get commandIconStairs;

  /// No description provided for @commandIconAxis.
  ///
  /// In en, this message translates to:
  /// **'Grid axis'**
  String get commandIconAxis;

  /// No description provided for @commandIconSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get commandIconSection;

  /// No description provided for @commandIconElevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get commandIconElevation;

  /// No description provided for @commandIconBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get commandIconBuilding;

  /// No description provided for @commandIconNewBuilding.
  ///
  /// In en, this message translates to:
  /// **'New building'**
  String get commandIconNewBuilding;

  /// No description provided for @commandIconBuildingOff.
  ///
  /// In en, this message translates to:
  /// **'Hide building'**
  String get commandIconBuildingOff;

  /// No description provided for @commandIconStoreys.
  ///
  /// In en, this message translates to:
  /// **'Storeys'**
  String get commandIconStoreys;

  /// No description provided for @commandIconZone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get commandIconZone;

  /// No description provided for @commandIconSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule table'**
  String get commandIconSchedule;

  /// No description provided for @commandIconZoneSchedule.
  ///
  /// In en, this message translates to:
  /// **'Zone schedule'**
  String get commandIconZoneSchedule;

  /// No description provided for @commandIconDimension.
  ///
  /// In en, this message translates to:
  /// **'Dimension'**
  String get commandIconDimension;

  /// No description provided for @commandIconLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get commandIconLevel;

  /// No description provided for @commandIconMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure distance'**
  String get commandIconMeasure;

  /// No description provided for @commandIconMeasureArea.
  ///
  /// In en, this message translates to:
  /// **'Measure area'**
  String get commandIconMeasureArea;

  /// No description provided for @commandIconMeasureAngle.
  ///
  /// In en, this message translates to:
  /// **'Measure angle'**
  String get commandIconMeasureAngle;

  /// No description provided for @commandIconMeasureRadius.
  ///
  /// In en, this message translates to:
  /// **'Measure radius'**
  String get commandIconMeasureRadius;

  /// No description provided for @commandIconLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get commandIconLine;

  /// No description provided for @commandIconPolyline.
  ///
  /// In en, this message translates to:
  /// **'Polyline'**
  String get commandIconPolyline;

  /// No description provided for @commandIconRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get commandIconRectangle;

  /// No description provided for @commandIconHatch.
  ///
  /// In en, this message translates to:
  /// **'Hatch'**
  String get commandIconHatch;

  /// No description provided for @commandIconText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get commandIconText;

  /// No description provided for @commandIconTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get commandIconTextSize;

  /// No description provided for @commandIconTextIncrease.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get commandIconTextIncrease;

  /// No description provided for @commandIconTextDecrease.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get commandIconTextDecrease;

  /// No description provided for @commandIconAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get commandIconAlignLeft;

  /// No description provided for @commandIconAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Align center'**
  String get commandIconAlignCenter;

  /// No description provided for @commandIconAlignTop.
  ///
  /// In en, this message translates to:
  /// **'Align top'**
  String get commandIconAlignTop;

  /// No description provided for @commandIconAlignBottom.
  ///
  /// In en, this message translates to:
  /// **'Align bottom'**
  String get commandIconAlignBottom;

  /// No description provided for @commandIconLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get commandIconLayers;

  /// No description provided for @commandIconLayersOff.
  ///
  /// In en, this message translates to:
  /// **'Hide layers'**
  String get commandIconLayersOff;

  /// No description provided for @commandIconGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get commandIconGrid;

  /// No description provided for @commandIconGridOff.
  ///
  /// In en, this message translates to:
  /// **'Hide grid'**
  String get commandIconGridOff;

  /// No description provided for @commandIconTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get commandIconTerrain;

  /// No description provided for @commandIconFloorDrain.
  ///
  /// In en, this message translates to:
  /// **'Floor drain'**
  String get commandIconFloorDrain;

  /// No description provided for @commandIconWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get commandIconWater;

  /// No description provided for @commandIconFoundation.
  ///
  /// In en, this message translates to:
  /// **'Foundation'**
  String get commandIconFoundation;

  /// No description provided for @commandIconWallJoint.
  ///
  /// In en, this message translates to:
  /// **'Wall junction'**
  String get commandIconWallJoint;

  /// No description provided for @commandIconRoundedCorner.
  ///
  /// In en, this message translates to:
  /// **'Round corner'**
  String get commandIconRoundedCorner;

  /// No description provided for @commandIconLineStyle.
  ///
  /// In en, this message translates to:
  /// **'Line style'**
  String get commandIconLineStyle;

  /// No description provided for @commandIconLineWeight.
  ///
  /// In en, this message translates to:
  /// **'Line weight'**
  String get commandIconLineWeight;

  /// No description provided for @commandIconPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get commandIconPoints;

  /// No description provided for @commandIconMagnet.
  ///
  /// In en, this message translates to:
  /// **'Snap'**
  String get commandIconMagnet;

  /// No description provided for @commandIconGesture.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get commandIconGesture;

  /// No description provided for @commandIconComponent.
  ///
  /// In en, this message translates to:
  /// **'Component library'**
  String get commandIconComponent;

  /// No description provided for @commandIconFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get commandIconFurniture;

  /// No description provided for @commandIconBed.
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get commandIconBed;

  /// No description provided for @commandIconBath.
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get commandIconBath;

  /// No description provided for @commandIconKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get commandIconKitchen;

  /// No description provided for @commandIconBalcony.
  ///
  /// In en, this message translates to:
  /// **'Balcony'**
  String get commandIconBalcony;

  /// No description provided for @commandIconFence.
  ///
  /// In en, this message translates to:
  /// **'Fence'**
  String get commandIconFence;

  /// No description provided for @commandIconCabin.
  ///
  /// In en, this message translates to:
  /// **'Timber building'**
  String get commandIconCabin;

  /// No description provided for @commandIconTree.
  ///
  /// In en, this message translates to:
  /// **'Landscape element'**
  String get commandIconTree;

  /// No description provided for @commandIconAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get commandIconAnalysis;

  /// No description provided for @commandIconSeismic.
  ///
  /// In en, this message translates to:
  /// **'Seismic analysis'**
  String get commandIconSeismic;

  /// No description provided for @commandIconBolt.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get commandIconBolt;

  /// No description provided for @commandIconEngineering.
  ///
  /// In en, this message translates to:
  /// **'Engineering'**
  String get commandIconEngineering;

  /// No description provided for @commandIconGraph.
  ///
  /// In en, this message translates to:
  /// **'Model relationships'**
  String get commandIconGraph;

  /// No description provided for @commandIconChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get commandIconChart;

  /// No description provided for @commandIconView3D.
  ///
  /// In en, this message translates to:
  /// **'3D view'**
  String get commandIconView3D;

  /// No description provided for @commandIconOrbit.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get commandIconOrbit;

  /// No description provided for @commandIconFly.
  ///
  /// In en, this message translates to:
  /// **'Fly through'**
  String get commandIconFly;

  /// No description provided for @commandIconViewTop.
  ///
  /// In en, this message translates to:
  /// **'Top view'**
  String get commandIconViewTop;

  /// No description provided for @commandIconViewFront.
  ///
  /// In en, this message translates to:
  /// **'Front view'**
  String get commandIconViewFront;

  /// No description provided for @commandIconViewRight.
  ///
  /// In en, this message translates to:
  /// **'Right view'**
  String get commandIconViewRight;

  /// No description provided for @commandIconViewBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom view'**
  String get commandIconViewBottom;

  /// No description provided for @commandIconViewBack.
  ///
  /// In en, this message translates to:
  /// **'Back view'**
  String get commandIconViewBack;

  /// No description provided for @commandIconVisible.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get commandIconVisible;

  /// No description provided for @commandIconHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commandIconHidden;

  /// No description provided for @commandIconFitView.
  ///
  /// In en, this message translates to:
  /// **'Fit view'**
  String get commandIconFitView;

  /// No description provided for @commandIconFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get commandIconFullscreen;

  /// No description provided for @commandIconExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get commandIconExitFullscreen;

  /// No description provided for @commandIconAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get commandIconAspectRatio;

  /// No description provided for @commandIconPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait orientation'**
  String get commandIconPortrait;

  /// No description provided for @commandIconScreenRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate screen'**
  String get commandIconScreenRotate;

  /// No description provided for @commandIconScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Lock orientation'**
  String get commandIconScreenLock;

  /// No description provided for @commandIconCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get commandIconCompare;

  /// No description provided for @commandIconCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get commandIconCrop;

  /// No description provided for @commandIconOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get commandIconOpacity;

  /// No description provided for @commandIconImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get commandIconImage;

  /// No description provided for @commandIconImageAdd.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get commandIconImageAdd;

  /// No description provided for @commandIconImageFilter.
  ///
  /// In en, this message translates to:
  /// **'Image effects'**
  String get commandIconImageFilter;

  /// No description provided for @commandIconImageBroken.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get commandIconImageBroken;

  /// No description provided for @commandIconCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get commandIconCamera;

  /// No description provided for @commandIconPalette.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get commandIconPalette;

  /// No description provided for @commandIconFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get commandIconFill;

  /// No description provided for @commandIconBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get commandIconBrush;

  /// No description provided for @commandIconPixelated.
  ///
  /// In en, this message translates to:
  /// **'Pixel rendering'**
  String get commandIconPixelated;

  /// No description provided for @commandIconSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth rendering'**
  String get commandIconSmooth;

  /// No description provided for @commandIconBook.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get commandIconBook;

  /// No description provided for @commandIconLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get commandIconLibrary;

  /// No description provided for @commandIconBookClosed.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get commandIconBookClosed;

  /// No description provided for @commandIconNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commandIconNotes;

  /// No description provided for @commandIconComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commandIconComment;

  /// No description provided for @commandIconList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get commandIconList;

  /// No description provided for @commandIconNumberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get commandIconNumberedList;

  /// No description provided for @commandIconChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get commandIconChecklist;

  /// No description provided for @commandIconWrapText.
  ///
  /// In en, this message translates to:
  /// **'Wrap text'**
  String get commandIconWrapText;

  /// No description provided for @commandIconLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get commandIconLineSpacing;

  /// No description provided for @commandIconTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get commandIconTable;

  /// No description provided for @commandIconPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF document'**
  String get commandIconPdf;

  /// No description provided for @commandIconCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get commandIconCode;

  /// No description provided for @commandIconCodeOff.
  ///
  /// In en, this message translates to:
  /// **'Hide code'**
  String get commandIconCodeOff;

  /// No description provided for @commandIconFunctions.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get commandIconFunctions;

  /// No description provided for @commandIconWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get commandIconWatermark;

  /// No description provided for @commandIconLayoutGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid layout'**
  String get commandIconLayoutGrid;

  /// No description provided for @commandIconLayoutRows.
  ///
  /// In en, this message translates to:
  /// **'Row layout'**
  String get commandIconLayoutRows;

  /// No description provided for @commandIconLayoutSidebar.
  ///
  /// In en, this message translates to:
  /// **'Side panel'**
  String get commandIconLayoutSidebar;

  /// No description provided for @commandIconLayoutCarousel.
  ///
  /// In en, this message translates to:
  /// **'Carousel view'**
  String get commandIconLayoutCarousel;

  /// No description provided for @commandIconLayoutCustom.
  ///
  /// In en, this message translates to:
  /// **'Customize layout'**
  String get commandIconLayoutCustom;

  /// No description provided for @commandIconPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commandIconPlay;

  /// No description provided for @commandIconPlayCircle.
  ///
  /// In en, this message translates to:
  /// **'Start playback'**
  String get commandIconPlayCircle;

  /// No description provided for @commandIconPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commandIconPause;

  /// No description provided for @commandIconPauseCircle.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get commandIconPauseCircle;

  /// No description provided for @commandIconStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commandIconStop;

  /// No description provided for @commandIconStopCircle.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get commandIconStopCircle;

  /// No description provided for @commandIconNextTrack.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get commandIconNextTrack;

  /// No description provided for @commandIconPreviousTrack.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get commandIconPreviousTrack;

  /// No description provided for @commandIconFastForward.
  ///
  /// In en, this message translates to:
  /// **'Fast forward'**
  String get commandIconFastForward;

  /// No description provided for @commandIconFastRewind.
  ///
  /// In en, this message translates to:
  /// **'Rewind'**
  String get commandIconFastRewind;

  /// No description provided for @commandIconForwardTen.
  ///
  /// In en, this message translates to:
  /// **'Forward ten seconds'**
  String get commandIconForwardTen;

  /// No description provided for @commandIconReplayTen.
  ///
  /// In en, this message translates to:
  /// **'Back ten seconds'**
  String get commandIconReplayTen;

  /// No description provided for @commandIconRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get commandIconRepeat;

  /// No description provided for @commandIconRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat current'**
  String get commandIconRepeatOne;

  /// No description provided for @commandIconVolume.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get commandIconVolume;

  /// No description provided for @commandIconMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get commandIconMute;

  /// No description provided for @commandIconVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get commandIconVideo;

  /// No description provided for @commandIconPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get commandIconPresentation;

  /// No description provided for @commandIconAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get commandIconAnimation;

  /// No description provided for @commandIconMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get commandIconMap;

  /// No description provided for @commandIconLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get commandIconLocation;

  /// No description provided for @commandIconLocationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get commandIconLocationAdd;

  /// No description provided for @commandIconLocationEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get commandIconLocationEdit;

  /// No description provided for @commandIconLocate.
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get commandIconLocate;

  /// No description provided for @commandIconCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get commandIconCompass;

  /// No description provided for @commandIconGlobe.
  ///
  /// In en, this message translates to:
  /// **'Coordinate system'**
  String get commandIconGlobe;

  /// No description provided for @commandIconRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get commandIconRoute;

  /// No description provided for @commandIconAlternativeRoute.
  ///
  /// In en, this message translates to:
  /// **'Alternative route'**
  String get commandIconAlternativeRoute;

  /// No description provided for @commandIconTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get commandIconTurnLeft;

  /// No description provided for @commandIconTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get commandIconTurnRight;

  /// No description provided for @commandIconFlag.
  ///
  /// In en, this message translates to:
  /// **'Waypoint'**
  String get commandIconFlag;

  /// No description provided for @commandIconFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commandIconFinish;

  /// No description provided for @commandIconWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get commandIconWalk;

  /// No description provided for @commandIconBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get commandIconBicycle;

  /// No description provided for @commandIconTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get commandIconTag;

  /// No description provided for @commandIconPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get commandIconPin;

  /// No description provided for @commandIconCalendar.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commandIconCalendar;

  /// No description provided for @commandIconMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical tools'**
  String get commandIconMedical;

  /// No description provided for @commandIconFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get commandIconFingerprint;

  /// No description provided for @commandIconAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get commandIconAuto;

  /// No description provided for @commandIconScience.
  ///
  /// In en, this message translates to:
  /// **'Experimental tools'**
  String get commandIconScience;

  /// No description provided for @commandIconRocket.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get commandIconRocket;

  /// No description provided for @commandIconInventory.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get commandIconInventory;

  /// No description provided for @commandIconBalance.
  ///
  /// In en, this message translates to:
  /// **'Structural checks'**
  String get commandIconBalance;

  /// No description provided for @commandIconWeb.
  ///
  /// In en, this message translates to:
  /// **'Web page'**
  String get commandIconWeb;

  /// No description provided for @commandIconSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get commandIconSpace;

  /// No description provided for @commandIconRoadEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit route'**
  String get commandIconRoadEdit;

  /// No description provided for @commandIconLightbulb.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get commandIconLightbulb;

  /// No description provided for @commandIconGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Command icons'**
  String get commandIconGalleryTitle;

  /// No description provided for @commandIconGallerySearch.
  ///
  /// In en, this message translates to:
  /// **'Search commands'**
  String get commandIconGallerySearch;

  /// No description provided for @commandIconGalleryLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get commandIconGalleryLight;

  /// No description provided for @commandIconGalleryDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get commandIconGalleryDark;

  /// No description provided for @commandIconAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get commandIconAlignRight;

  /// No description provided for @commandIconPolygon.
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get commandIconPolygon;

  /// No description provided for @commandIconArc.
  ///
  /// In en, this message translates to:
  /// **'Arc'**
  String get commandIconArc;

  /// No description provided for @commandIconRoofGable.
  ///
  /// In en, this message translates to:
  /// **'Gable roof'**
  String get commandIconRoofGable;

  /// No description provided for @commandIconRoofHip.
  ///
  /// In en, this message translates to:
  /// **'Hip roof'**
  String get commandIconRoofHip;

  /// No description provided for @commandIconRoofShed.
  ///
  /// In en, this message translates to:
  /// **'Shed roof'**
  String get commandIconRoofShed;

  /// No description provided for @commandIconRoofFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat roof'**
  String get commandIconRoofFlat;

  /// No description provided for @commandIconRoofMansard.
  ///
  /// In en, this message translates to:
  /// **'Mansard roof'**
  String get commandIconRoofMansard;

  /// No description provided for @commandIconSelectionContained.
  ///
  /// In en, this message translates to:
  /// **'Select contained'**
  String get commandIconSelectionContained;

  /// No description provided for @commandIconSelectionCrossing.
  ///
  /// In en, this message translates to:
  /// **'Select crossing'**
  String get commandIconSelectionCrossing;

  /// No description provided for @commandIconShadingEdges.
  ///
  /// In en, this message translates to:
  /// **'Shaded edges'**
  String get commandIconShadingEdges;

  /// No description provided for @commandIconShadingSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth shading'**
  String get commandIconShadingSmooth;

  /// No description provided for @commandIconShadingFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat shading'**
  String get commandIconShadingFlat;

  /// No description provided for @commandIconShadingWire.
  ///
  /// In en, this message translates to:
  /// **'Wireframe'**
  String get commandIconShadingWire;

  /// No description provided for @commandIconShadingXray.
  ///
  /// In en, this message translates to:
  /// **'X-ray'**
  String get commandIconShadingXray;

  /// No description provided for @commandIconMask.
  ///
  /// In en, this message translates to:
  /// **'Mask (Wipeout)'**
  String get commandIconMask;

  /// No description provided for @commandIconMultileader.
  ///
  /// In en, this message translates to:
  /// **'Multileader'**
  String get commandIconMultileader;

  /// No description provided for @commandIconSpline.
  ///
  /// In en, this message translates to:
  /// **'Spline'**
  String get commandIconSpline;

  /// No description provided for @commandIconEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get commandIconEllipse;

  /// No description provided for @commandIconRoofSlope.
  ///
  /// In en, this message translates to:
  /// **'Roof slope'**
  String get commandIconRoofSlope;

  /// No description provided for @commandIconLineArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow line'**
  String get commandIconLineArrow;

  /// No description provided for @commandIconLineDot.
  ///
  /// In en, this message translates to:
  /// **'Dot line'**
  String get commandIconLineDot;

  /// No description provided for @commandUiCopyThisError.
  ///
  /// In en, this message translates to:
  /// **'Copy this error'**
  String get commandUiCopyThisError;

  /// No description provided for @commandUiErrorCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Error copied to clipboard'**
  String get commandUiErrorCopiedToClipboard;

  /// No description provided for @commandUiCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get commandUiCopied;

  /// No description provided for @commandUiCopyAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy All Logs'**
  String get commandUiCopyAllLogs;

  /// No description provided for @commandUiGoToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get commandUiGoToHome;

  /// No description provided for @commandUiCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy Report'**
  String get commandUiCopyReport;

  /// No description provided for @commandUiViewErrorLog.
  ///
  /// In en, this message translates to:
  /// **'View Error Log'**
  String get commandUiViewErrorLog;

  /// No description provided for @commandUiHideTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide technical details'**
  String get commandUiHideTechnicalDetails;

  /// No description provided for @commandUiShowTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Show technical details'**
  String get commandUiShowTechnicalDetails;

  /// No description provided for @commandUiSearchByCountryProjectionOrEpsgCode.
  ///
  /// In en, this message translates to:
  /// **'Search by country, projection, or EPSG code...'**
  String get commandUiSearchByCountryProjectionOrEpsgCode;

  /// No description provided for @commandUiSaveSelection.
  ///
  /// In en, this message translates to:
  /// **'Save Selection'**
  String get commandUiSaveSelection;

  /// No description provided for @commandUiHex.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get commandUiHex;

  /// No description provided for @commandUiJsonBimJson.
  ///
  /// In en, this message translates to:
  /// **'JSON (.bim.json)'**
  String get commandUiJsonBimJson;

  /// No description provided for @commandUiCanvasBackground.
  ///
  /// In en, this message translates to:
  /// **'Canvas Background'**
  String get commandUiCanvasBackground;

  /// No description provided for @commandUiFlipOrientation.
  ///
  /// In en, this message translates to:
  /// **'Flip Orientation'**
  String get commandUiFlipOrientation;

  /// No description provided for @commandUiFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get commandUiFlipHorizontal;

  /// No description provided for @commandUiFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get commandUiFlipVertical;

  /// No description provided for @commandUiShareExport.
  ///
  /// In en, this message translates to:
  /// **'Share & Export'**
  String get commandUiShareExport;

  /// No description provided for @commandUiShareOriginalCdr.
  ///
  /// In en, this message translates to:
  /// **'Share Original .CDR'**
  String get commandUiShareOriginalCdr;

  /// No description provided for @commandUiExportAsPngImage.
  ///
  /// In en, this message translates to:
  /// **'Export as PNG Image'**
  String get commandUiExportAsPngImage;

  /// No description provided for @commandUiPrintExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Print / Export PDF'**
  String get commandUiPrintExportPdf;

  /// No description provided for @commandUiTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commandUiTryAgain;

  /// No description provided for @commandUiSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get commandUiSearch;

  /// No description provided for @commandUiViewAsPlainText.
  ///
  /// In en, this message translates to:
  /// **'View as Plain Text'**
  String get commandUiViewAsPlainText;

  /// No description provided for @commandUiContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get commandUiContinueAnyway;

  /// No description provided for @commandUiCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close Search'**
  String get commandUiCloseSearch;

  /// No description provided for @commandUiDisableWordWrap.
  ///
  /// In en, this message translates to:
  /// **'Disable Word Wrap'**
  String get commandUiDisableWordWrap;

  /// No description provided for @commandUiEnableWordWrap.
  ///
  /// In en, this message translates to:
  /// **'Enable Word Wrap'**
  String get commandUiEnableWordWrap;

  /// No description provided for @commandUiCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy All'**
  String get commandUiCopyAll;

  /// No description provided for @commandUiShowRaw.
  ///
  /// In en, this message translates to:
  /// **'Show Raw'**
  String get commandUiShowRaw;

  /// No description provided for @commandUiPrettyPrint.
  ///
  /// In en, this message translates to:
  /// **'Pretty Print'**
  String get commandUiPrettyPrint;

  /// No description provided for @commandUiShowSecrets.
  ///
  /// In en, this message translates to:
  /// **'Show Secrets'**
  String get commandUiShowSecrets;

  /// No description provided for @commandUiHideSecrets.
  ///
  /// In en, this message translates to:
  /// **'Hide Secrets'**
  String get commandUiHideSecrets;

  /// No description provided for @commandUiEnableSyntaxHighlighting.
  ///
  /// In en, this message translates to:
  /// **'Enable Syntax Highlighting'**
  String get commandUiEnableSyntaxHighlighting;

  /// No description provided for @commandUiFontSizeValue.
  ///
  /// In en, this message translates to:
  /// **'Font Size ({value1})'**
  String commandUiFontSizeValue(String value1);

  /// No description provided for @commandUiFontSizeValue2.
  ///
  /// In en, this message translates to:
  /// **'Font Size: {value1}'**
  String commandUiFontSizeValue2(String value1);

  /// No description provided for @commandUiReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading Mode'**
  String get commandUiReadingMode;

  /// No description provided for @commandUiValueTapToChange.
  ///
  /// In en, this message translates to:
  /// **'{value1} (Tap to change)'**
  String commandUiValueTapToChange(String value1);

  /// No description provided for @commandUiRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove Bookmark'**
  String get commandUiRemoveBookmark;

  /// No description provided for @commandUiAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get commandUiAddBookmark;

  /// No description provided for @commandUiSavedBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Saved Bookmarks'**
  String get commandUiSavedBookmarks;

  /// No description provided for @commandUiComicInfo.
  ///
  /// In en, this message translates to:
  /// **'Comic Info'**
  String get commandUiComicInfo;

  /// No description provided for @commandUiPageValueError.
  ///
  /// In en, this message translates to:
  /// **'Page {value1} Error'**
  String commandUiPageValueError(String value1);

  /// No description provided for @commandUiDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get commandUiDecrease;

  /// No description provided for @commandUiIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get commandUiIncrease;

  /// No description provided for @commandUiRestartFromPage1UponReachingTheEnd.
  ///
  /// In en, this message translates to:
  /// **'Restart from page 1 upon reaching the end'**
  String get commandUiRestartFromPage1UponReachingTheEnd;

  /// No description provided for @commandUiAutomaticallySuspendPageTurnsWhileInspectingPanelsZoomedIn.
  ///
  /// In en, this message translates to:
  /// **'Automatically suspend page turns while inspecting panels zoomed in'**
  String
  get commandUiAutomaticallySuspendPageTurnsWhileInspectingPanelsZoomedIn;

  /// No description provided for @commandUiErrorLoadingPageValue.
  ///
  /// In en, this message translates to:
  /// **'Error loading page {value1}'**
  String commandUiErrorLoadingPageValue(String value1);

  /// No description provided for @commandUiToggleRawText.
  ///
  /// In en, this message translates to:
  /// **'Toggle Raw Text'**
  String get commandUiToggleRawText;

  /// No description provided for @commandUiDelimiter.
  ///
  /// In en, this message translates to:
  /// **'Delimiter'**
  String get commandUiDelimiter;

  /// No description provided for @commandUiComma.
  ///
  /// In en, this message translates to:
  /// **'Comma (,)'**
  String get commandUiComma;

  /// No description provided for @commandUiSemicolon.
  ///
  /// In en, this message translates to:
  /// **'Semicolon (;)'**
  String get commandUiSemicolon;

  /// No description provided for @commandUiTabT.
  ///
  /// In en, this message translates to:
  /// **'Tab (\\t)'**
  String get commandUiTabT;

  /// No description provided for @commandUiPipe.
  ///
  /// In en, this message translates to:
  /// **'Pipe (|)'**
  String get commandUiPipe;

  /// No description provided for @commandUiSearchRows.
  ///
  /// In en, this message translates to:
  /// **'Search rows...'**
  String get commandUiSearchRows;

  /// No description provided for @commandUiEmptyCsv.
  ///
  /// In en, this message translates to:
  /// **'Empty CSV'**
  String get commandUiEmptyCsv;

  /// No description provided for @commandUiNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get commandUiNoMatches;

  /// No description provided for @commandUiShowingFirst1000RowsForPerformance.
  ///
  /// In en, this message translates to:
  /// **'Showing first 1000 rows for performance'**
  String get commandUiShowingFirst1000RowsForPerformance;

  /// No description provided for @commandUiToggleHudText.
  ///
  /// In en, this message translates to:
  /// **'Toggle HUD text'**
  String get commandUiToggleHudText;

  /// No description provided for @commandUiShowMetadata.
  ///
  /// In en, this message translates to:
  /// **'Show metadata'**
  String get commandUiShowMetadata;

  /// No description provided for @commandUiPanZoom.
  ///
  /// In en, this message translates to:
  /// **'Pan & Zoom'**
  String get commandUiPanZoom;

  /// No description provided for @commandUiWindowLevelDragDragOnScreen.
  ///
  /// In en, this message translates to:
  /// **'Window / Level Drag (Drag on screen)'**
  String get commandUiWindowLevelDragDragOnScreen;

  /// No description provided for @commandUiRulerMeasurementMm.
  ///
  /// In en, this message translates to:
  /// **'Ruler Measurement (mm)'**
  String get commandUiRulerMeasurementMm;

  /// No description provided for @commandUiClearValue.
  ///
  /// In en, this message translates to:
  /// **'Clear ({value1})'**
  String commandUiClearValue(String value1);

  /// No description provided for @commandUiSelectSeries.
  ///
  /// In en, this message translates to:
  /// **'Select Series'**
  String get commandUiSelectSeries;

  /// No description provided for @commandUiRulerMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Ruler Measurement'**
  String get commandUiRulerMeasurement;

  /// No description provided for @commandUiPauseCine.
  ///
  /// In en, this message translates to:
  /// **'Pause Cine'**
  String get commandUiPauseCine;

  /// No description provided for @commandUiPlayCine.
  ///
  /// In en, this message translates to:
  /// **'Play Cine'**
  String get commandUiPlayCine;

  /// No description provided for @commandUiReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commandUiReset;

  /// No description provided for @commandUiSearchInDocument.
  ///
  /// In en, this message translates to:
  /// **'Search in Document'**
  String get commandUiSearchInDocument;

  /// No description provided for @commandUiCopyDocumentText.
  ///
  /// In en, this message translates to:
  /// **'Copy Document Text'**
  String get commandUiCopyDocumentText;

  /// No description provided for @commandUiDocumentProperties.
  ///
  /// In en, this message translates to:
  /// **'Document Properties'**
  String get commandUiDocumentProperties;

  /// No description provided for @commandUiSearchInDocument2.
  ///
  /// In en, this message translates to:
  /// **'Search in document...'**
  String get commandUiSearchInDocument2;

  /// No description provided for @commandUiMinimizeControls.
  ///
  /// In en, this message translates to:
  /// **'Minimize Controls'**
  String get commandUiMinimizeControls;

  /// No description provided for @commandUiExitFullscreenEsc.
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen (ESC)'**
  String get commandUiExitFullscreenEsc;

  /// No description provided for @commandUiElevationValueValueElements.
  ///
  /// In en, this message translates to:
  /// **'Elevation: {value1} • {value2} elements'**
  String commandUiElevationValueValueElements(String value1, String value2);

  /// No description provided for @commandUiIsolateStorey.
  ///
  /// In en, this message translates to:
  /// **'Isolate Storey'**
  String get commandUiIsolateStorey;

  /// No description provided for @commandUiValueItems.
  ///
  /// In en, this message translates to:
  /// **'{value1} items'**
  String commandUiValueItems(String value1);

  /// No description provided for @commandUiIsolateCategory.
  ///
  /// In en, this message translates to:
  /// **'Isolate Category'**
  String get commandUiIsolateCategory;

  /// No description provided for @commandUiValueElements.
  ///
  /// In en, this message translates to:
  /// **'{value1} elements'**
  String commandUiValueElements(String value1);

  /// No description provided for @commandUiIsolateLayer.
  ///
  /// In en, this message translates to:
  /// **'Isolate Layer'**
  String get commandUiIsolateLayer;

  /// No description provided for @commandUiApplyClose.
  ///
  /// In en, this message translates to:
  /// **'Apply & Close'**
  String get commandUiApplyClose;

  /// No description provided for @commandUiFitToScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit to Screen'**
  String get commandUiFitToScreen;

  /// No description provided for @commandUiImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commandUiImport;

  /// No description provided for @commandUiExitMeasureMarkup.
  ///
  /// In en, this message translates to:
  /// **'Exit Measure & Markup'**
  String get commandUiExitMeasureMarkup;

  /// No description provided for @commandUiMeasureTools.
  ///
  /// In en, this message translates to:
  /// **'Measure Tools'**
  String get commandUiMeasureTools;

  /// No description provided for @commandUiSaveMergedDxf.
  ///
  /// In en, this message translates to:
  /// **'Save Merged DXF'**
  String get commandUiSaveMergedDxf;

  /// No description provided for @commandUiSaveAnnotatedDxf.
  ///
  /// In en, this message translates to:
  /// **'Save Annotated DXF'**
  String get commandUiSaveAnnotatedDxf;

  /// No description provided for @commandUiCanvasTheme.
  ///
  /// In en, this message translates to:
  /// **'Canvas Theme'**
  String get commandUiCanvasTheme;

  /// No description provided for @commandUiExportAsFastKcad.
  ///
  /// In en, this message translates to:
  /// **'Export as Fast KCAD'**
  String get commandUiExportAsFastKcad;

  /// No description provided for @commandUiHideCadGrid.
  ///
  /// In en, this message translates to:
  /// **'Hide CAD Grid'**
  String get commandUiHideCadGrid;

  /// No description provided for @commandUiShowCadGrid.
  ///
  /// In en, this message translates to:
  /// **'Show CAD Grid'**
  String get commandUiShowCadGrid;

  /// No description provided for @commandUiDrawingProperties.
  ///
  /// In en, this message translates to:
  /// **'Drawing Properties'**
  String get commandUiDrawingProperties;

  /// No description provided for @commandUiShareFile.
  ///
  /// In en, this message translates to:
  /// **'Share File'**
  String get commandUiShareFile;

  /// No description provided for @commandUiPrintExport.
  ///
  /// In en, this message translates to:
  /// **'Print / Export'**
  String get commandUiPrintExport;

  /// No description provided for @commandUiEnterAnnotationTextOrSelectAPresetBelow.
  ///
  /// In en, this message translates to:
  /// **'Enter annotation text or select a preset below...'**
  String get commandUiEnterAnnotationTextOrSelectAPresetBelow;

  /// No description provided for @commandUiDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get commandUiDeleteNote;

  /// No description provided for @commandUiUpdateNote.
  ///
  /// In en, this message translates to:
  /// **'Update Note'**
  String get commandUiUpdateNote;

  /// No description provided for @commandUiAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get commandUiAddNote;

  /// No description provided for @commandUiSnapValue.
  ///
  /// In en, this message translates to:
  /// **'Snap {value1}'**
  String commandUiSnapValue(String value1);

  /// No description provided for @commandUiClearMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Clear measurement'**
  String get commandUiClearMeasurement;

  /// No description provided for @commandUiExitMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Exit measurement'**
  String get commandUiExitMeasurement;

  /// No description provided for @commandUiTight.
  ///
  /// In en, this message translates to:
  /// **'Tight'**
  String get commandUiTight;

  /// No description provided for @commandUiRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get commandUiRelaxed;

  /// No description provided for @commandUiPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get commandUiPages;

  /// No description provided for @commandUiScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get commandUiScroll;

  /// No description provided for @commandUiSearchBook.
  ///
  /// In en, this message translates to:
  /// **'Search Book'**
  String get commandUiSearchBook;

  /// No description provided for @commandUiPageFlipModeTapForContinuous.
  ///
  /// In en, this message translates to:
  /// **'Page Flip Mode (Tap for Continuous)'**
  String get commandUiPageFlipModeTapForContinuous;

  /// No description provided for @commandUiContinuousScrollTapForPages.
  ///
  /// In en, this message translates to:
  /// **'Continuous Scroll (Tap for Pages)'**
  String get commandUiContinuousScrollTapForPages;

  /// No description provided for @commandUiReadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get commandUiReadingSettings;

  /// No description provided for @commandUiBookInfo.
  ///
  /// In en, this message translates to:
  /// **'Book Info'**
  String get commandUiBookInfo;

  /// No description provided for @commandUiSearchInBookText.
  ///
  /// In en, this message translates to:
  /// **'Search in book text...'**
  String get commandUiSearchInBookText;

  /// No description provided for @commandUiOpeningEBook.
  ///
  /// In en, this message translates to:
  /// **'Opening E-Book...'**
  String get commandUiOpeningEBook;

  /// No description provided for @commandUiNoContentFound.
  ///
  /// In en, this message translates to:
  /// **'No content found'**
  String get commandUiNoContentFound;

  /// No description provided for @commandUiPrevChapter.
  ///
  /// In en, this message translates to:
  /// **'Prev Chapter'**
  String get commandUiPrevChapter;

  /// No description provided for @commandUiNextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next Chapter'**
  String get commandUiNextChapter;

  /// No description provided for @commandUiChapterValue.
  ///
  /// In en, this message translates to:
  /// **'Chapter {value1}'**
  String commandUiChapterValue(String value1);

  /// No description provided for @commandUiPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get commandUiPrev;

  /// No description provided for @commandUiRotate90Clockwise.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° Clockwise'**
  String get commandUiRotate90Clockwise;

  /// No description provided for @commandUiFitToViewCenter.
  ///
  /// In en, this message translates to:
  /// **'Fit to View (Center)'**
  String get commandUiFitToViewCenter;

  /// No description provided for @commandUiTypeHereToPreview.
  ///
  /// In en, this message translates to:
  /// **'Type here to preview'**
  String get commandUiTypeHereToPreview;

  /// No description provided for @commandUiFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get commandUiFolderName;

  /// No description provided for @commandUiEnterFolderDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Enter folder display name'**
  String get commandUiEnterFolderDisplayName;

  /// No description provided for @commandUiEnterAmountInMax20.
  ///
  /// In en, this message translates to:
  /// **'Enter amount in € (max 20€)'**
  String get commandUiEnterAmountInMax20;

  /// No description provided for @commandUiEG10.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10'**
  String get commandUiEG10;

  /// No description provided for @commandUiRevolut.
  ///
  /// In en, this message translates to:
  /// **'Revolut'**
  String get commandUiRevolut;

  /// No description provided for @commandUiPaypal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get commandUiPaypal;

  /// No description provided for @commandUiFilterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get commandUiFilterByCategory;

  /// No description provided for @commandUiIncludeSubfoldersOn.
  ///
  /// In en, this message translates to:
  /// **'Include subfolders: ON'**
  String get commandUiIncludeSubfoldersOn;

  /// No description provided for @commandUiIncludeSubfoldersOff.
  ///
  /// In en, this message translates to:
  /// **'Include subfolders: OFF'**
  String get commandUiIncludeSubfoldersOff;

  /// No description provided for @commandUiRenameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename Folder'**
  String get commandUiRenameFolder;

  /// No description provided for @commandUiRemoveFolderFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove Folder from list'**
  String get commandUiRemoveFolderFromList;

  /// No description provided for @commandUiSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get commandUiSelectFolder;

  /// No description provided for @commandUiFileNoLongerExistsOnTheDevice.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists on the device.'**
  String get commandUiFileNoLongerExistsOnTheDevice;

  /// No description provided for @commandUiLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get commandUiLicenses;

  /// No description provided for @commandUiLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get commandUiLogs;

  /// No description provided for @commandUiGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get commandUiGithub;

  /// No description provided for @commandUiCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get commandUiCopyUrl;

  /// No description provided for @commandUiCloseServer.
  ///
  /// In en, this message translates to:
  /// **'Close Server'**
  String get commandUiCloseServer;

  /// No description provided for @commandUiStopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop Sharing'**
  String get commandUiStopSharing;

  /// No description provided for @commandUiAllOptions.
  ///
  /// In en, this message translates to:
  /// **'All Options'**
  String get commandUiAllOptions;

  /// No description provided for @commandUiPlotterProperties.
  ///
  /// In en, this message translates to:
  /// **'Plotter Properties'**
  String get commandUiPlotterProperties;

  /// No description provided for @commandUiBackgroundCheckerboard.
  ///
  /// In en, this message translates to:
  /// **'Background: Checkerboard'**
  String get commandUiBackgroundCheckerboard;

  /// No description provided for @commandUiBackgroundDark.
  ///
  /// In en, this message translates to:
  /// **'Background: Dark'**
  String get commandUiBackgroundDark;

  /// No description provided for @commandUiBackgroundLight.
  ///
  /// In en, this message translates to:
  /// **'Background: Light'**
  String get commandUiBackgroundLight;

  /// No description provided for @commandUiRenderingCrispPixelPerfect.
  ///
  /// In en, this message translates to:
  /// **'Rendering: Crisp (Pixel-perfect)'**
  String get commandUiRenderingCrispPixelPerfect;

  /// No description provided for @commandUiRenderingSmooth.
  ///
  /// In en, this message translates to:
  /// **'Rendering: Smooth'**
  String get commandUiRenderingSmooth;

  /// No description provided for @commandUiSingleImageView.
  ///
  /// In en, this message translates to:
  /// **'Single Image View'**
  String get commandUiSingleImageView;

  /// No description provided for @commandUiAllResolutionsGrid.
  ///
  /// In en, this message translates to:
  /// **'All Resolutions Grid'**
  String get commandUiAllResolutionsGrid;

  /// No description provided for @commandUiShareSizeValueValuePng.
  ///
  /// In en, this message translates to:
  /// **'Share size ({value1}×{value2} PNG)'**
  String commandUiShareSizeValueValuePng(String value1, String value2);

  /// No description provided for @commandUiShareOriginalIcoFile.
  ///
  /// In en, this message translates to:
  /// **'Share original .ico file'**
  String get commandUiShareOriginalIcoFile;

  /// No description provided for @commandUiPrintSaveAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Print / Save as PDF'**
  String get commandUiPrintSaveAsPdf;

  /// No description provided for @commandUiFlipImage.
  ///
  /// In en, this message translates to:
  /// **'Flip Image'**
  String get commandUiFlipImage;

  /// No description provided for @commandUiMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get commandUiMoreActions;

  /// No description provided for @commandUiPrintSavePdf.
  ///
  /// In en, this message translates to:
  /// **'Print / Save PDF'**
  String get commandUiPrintSavePdf;

  /// No description provided for @commandUiResetViewTransforms.
  ///
  /// In en, this message translates to:
  /// **'Reset View & Transforms'**
  String get commandUiResetViewTransforms;

  /// No description provided for @commandUiFailedToRenderImageValue.
  ///
  /// In en, this message translates to:
  /// **'Failed to render image: {value1}'**
  String commandUiFailedToRenderImageValue(String value1);

  /// No description provided for @commandUiBackToProject.
  ///
  /// In en, this message translates to:
  /// **'Back to Project'**
  String get commandUiBackToProject;

  /// No description provided for @commandUiResetZoom11.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom (1:1)'**
  String get commandUiResetZoom11;

  /// No description provided for @commandUiFormattedView.
  ///
  /// In en, this message translates to:
  /// **'Formatted View'**
  String get commandUiFormattedView;

  /// No description provided for @commandUiRawMarkdownSource.
  ///
  /// In en, this message translates to:
  /// **'Raw Markdown Source'**
  String get commandUiRawMarkdownSource;

  /// No description provided for @commandUiCopyMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get commandUiCopyMarkdown;

  /// No description provided for @commandUiMarkdownProperties.
  ///
  /// In en, this message translates to:
  /// **'Markdown Properties'**
  String get commandUiMarkdownProperties;

  /// No description provided for @commandUiPcbLayersValueValue.
  ///
  /// In en, this message translates to:
  /// **'PCB Layers ({value1}/{value2})'**
  String commandUiPcbLayersValueValue(String value1, String value2);

  /// No description provided for @commandUi1MmMeasurementGrid.
  ///
  /// In en, this message translates to:
  /// **'1mm Measurement Grid'**
  String get commandUi1MmMeasurementGrid;

  /// No description provided for @commandUiTogglePadNumbers.
  ///
  /// In en, this message translates to:
  /// **'Toggle Pad Numbers'**
  String get commandUiTogglePadNumbers;

  /// No description provided for @commandUiBoardArchiveProperties.
  ///
  /// In en, this message translates to:
  /// **'Board / Archive Properties'**
  String get commandUiBoardArchiveProperties;

  /// No description provided for @commandUiPcbCanvasTheme.
  ///
  /// In en, this message translates to:
  /// **'PCB Canvas Theme'**
  String get commandUiPcbCanvasTheme;

  /// No description provided for @commandUiViewArchiveFiles.
  ///
  /// In en, this message translates to:
  /// **'View Archive Files'**
  String get commandUiViewArchiveFiles;

  /// No description provided for @commandUiTop.
  ///
  /// In en, this message translates to:
  /// **'TOP'**
  String get commandUiTop;

  /// No description provided for @commandUiBottom.
  ///
  /// In en, this message translates to:
  /// **'BOTTOM'**
  String get commandUiBottom;

  /// No description provided for @commandUiAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get commandUiAll;

  /// No description provided for @commandUiFitBoardToViewCenter.
  ///
  /// In en, this message translates to:
  /// **'Fit Board to View (Center)'**
  String get commandUiFitBoardToViewCenter;

  /// No description provided for @commandUiInteractiveZoomViewer.
  ///
  /// In en, this message translates to:
  /// **'Interactive Zoom Viewer'**
  String get commandUiInteractiveZoomViewer;

  /// No description provided for @commandUiSearchDesignatorValuePackageEGR110K.
  ///
  /// In en, this message translates to:
  /// **'Search designator, value, package (e.g. R1, 10k)...'**
  String get commandUiSearchDesignatorValuePackageEGR110K;

  /// No description provided for @commandUiPackageValuevalue.
  ///
  /// In en, this message translates to:
  /// **'Package: {value1}{value2}'**
  String commandUiPackageValuevalue(String value1, String value2);

  /// No description provided for @commandUiOpenIn3DCadViewer.
  ///
  /// In en, this message translates to:
  /// **'Open in 3D CAD Viewer'**
  String get commandUiOpenIn3DCadViewer;

  /// No description provided for @commandUiOpenPdfSchematic.
  ///
  /// In en, this message translates to:
  /// **'Open PDF Schematic'**
  String get commandUiOpenPdfSchematic;

  /// No description provided for @commandUiViewKicadSchematic.
  ///
  /// In en, this message translates to:
  /// **'View KiCad Schematic'**
  String get commandUiViewKicadSchematic;

  /// No description provided for @commandUiSearchFilesInArchive.
  ///
  /// In en, this message translates to:
  /// **'Search files in archive...'**
  String get commandUiSearchFilesInArchive;

  /// No description provided for @commandUiAllValue.
  ///
  /// In en, this message translates to:
  /// **'All ({value1})'**
  String commandUiAllValue(String value1);

  /// No description provided for @commandUiCouldNotLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get commandUiCouldNotLoadImage;

  /// No description provided for @commandUiCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get commandUiCloseEsc;

  /// No description provided for @commandUiResetZoom100.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom (100%)'**
  String get commandUiResetZoom100;

  /// No description provided for @commandUiPreviousImageLeftArrow.
  ///
  /// In en, this message translates to:
  /// **'Previous Image (Left Arrow)'**
  String get commandUiPreviousImageLeftArrow;

  /// No description provided for @commandUiNextImageRightArrow.
  ///
  /// In en, this message translates to:
  /// **'Next Image (Right Arrow)'**
  String get commandUiNextImageRightArrow;

  /// No description provided for @commandUiZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In (+)'**
  String get commandUiZoomIn;

  /// No description provided for @commandUiZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out (-)'**
  String get commandUiZoomOut;

  /// No description provided for @commandUiFitToView.
  ///
  /// In en, this message translates to:
  /// **'Fit to View'**
  String get commandUiFitToView;

  /// No description provided for @commandUiExitReadingModeBackToOriginalPdf.
  ///
  /// In en, this message translates to:
  /// **'Exit Reading Mode (Back to Original PDF)'**
  String get commandUiExitReadingModeBackToOriginalPdf;

  /// No description provided for @commandUiReadingModeReflowEBook.
  ///
  /// In en, this message translates to:
  /// **'Reading Mode (Reflow / E-Book)'**
  String get commandUiReadingModeReflowEBook;

  /// No description provided for @commandUiToggleInvertColors.
  ///
  /// In en, this message translates to:
  /// **'Toggle Invert Colors'**
  String get commandUiToggleInvertColors;

  /// No description provided for @commandUiPdfProperties.
  ///
  /// In en, this message translates to:
  /// **'PDF Properties'**
  String get commandUiPdfProperties;

  /// No description provided for @commandUiSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get commandUiSharePdf;

  /// No description provided for @commandUiPrintPdf.
  ///
  /// In en, this message translates to:
  /// **'Print PDF'**
  String get commandUiPrintPdf;

  /// No description provided for @commandUiFitPageToScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit Page to Screen'**
  String get commandUiFitPageToScreen;

  /// No description provided for @commandUiEnterPfxPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter PFX password'**
  String get commandUiEnterPfxPassword;

  /// No description provided for @commandUiOriginalPdf.
  ///
  /// In en, this message translates to:
  /// **'Original PDF'**
  String get commandUiOriginalPdf;

  /// No description provided for @commandUiDecreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get commandUiDecreaseFontSize;

  /// No description provided for @commandUiIncreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get commandUiIncreaseFontSize;

  /// No description provided for @commandUiSwipePages.
  ///
  /// In en, this message translates to:
  /// **'Swipe Pages'**
  String get commandUiSwipePages;

  /// No description provided for @commandUiViewOriginalPdfPage.
  ///
  /// In en, this message translates to:
  /// **'View Original PDF Page'**
  String get commandUiViewOriginalPdfPage;

  /// No description provided for @commandUiGroupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Group by category'**
  String get commandUiGroupByCategory;

  /// No description provided for @commandUiSearchFilesInProject.
  ///
  /// In en, this message translates to:
  /// **'Search files in project...'**
  String get commandUiSearchFilesInProject;

  /// No description provided for @commandUiByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get commandUiByCategory;

  /// No description provided for @commandUiMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get commandUiMoveUp;

  /// No description provided for @commandUiMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get commandUiMoveDown;

  /// No description provided for @commandUiExitPresentation.
  ///
  /// In en, this message translates to:
  /// **'Exit Presentation'**
  String get commandUiExitPresentation;

  /// No description provided for @commandUiRouteDetails.
  ///
  /// In en, this message translates to:
  /// **'Route Details'**
  String get commandUiRouteDetails;

  /// No description provided for @commandUiShareRoute.
  ///
  /// In en, this message translates to:
  /// **'Share Route'**
  String get commandUiShareRoute;

  /// No description provided for @commandUiMapOverlays.
  ///
  /// In en, this message translates to:
  /// **'Map Overlays'**
  String get commandUiMapOverlays;

  /// No description provided for @commandUiFitRoute.
  ///
  /// In en, this message translates to:
  /// **'Fit Route'**
  String get commandUiFitRoute;

  /// No description provided for @commandUiCenterOnLocation.
  ///
  /// In en, this message translates to:
  /// **'Center on Location'**
  String get commandUiCenterOnLocation;

  /// No description provided for @commandUiShowMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Show My Location'**
  String get commandUiShowMyLocation;

  /// No description provided for @commandUiCalibrateCompass.
  ///
  /// In en, this message translates to:
  /// **'Calibrate Compass'**
  String get commandUiCalibrateCompass;

  /// No description provided for @commandUiHikingTrailsMarkings.
  ///
  /// In en, this message translates to:
  /// **'Hiking Trails & Markings'**
  String get commandUiHikingTrailsMarkings;

  /// No description provided for @commandUiWaymarkedTrailsOfficialMountainRouteColorsCodesFromOsm.
  ///
  /// In en, this message translates to:
  /// **'Waymarked Trails: official mountain route colors & codes from OSM'**
  String get commandUiWaymarkedTrailsOfficialMountainRouteColorsCodesFromOsm;

  /// No description provided for @commandUiMtbCyclingRoutes.
  ///
  /// In en, this message translates to:
  /// **'MTB & Cycling Routes'**
  String get commandUiMtbCyclingRoutes;

  /// No description provided for @commandUiWaymarkedTrailsDedicatedMountainBikeAndCyclingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waymarked Trails: dedicated mountain bike and cycling network'**
  String get commandUiWaymarkedTrailsDedicatedMountainBikeAndCyclingNetwork;

  /// No description provided for @commandUiAutocadDxfSColSWallSBeamSSlabSAxis.
  ///
  /// In en, this message translates to:
  /// **'AutoCAD DXF (S-COL, S-WALL, S-BEAM, S-SLAB, S-AXIS)'**
  String get commandUiAutocadDxfSColSWallSBeamSSlabSAxis;

  /// No description provided for @commandUiValueEntities.
  ///
  /// In en, this message translates to:
  /// **'{value1} entities'**
  String commandUiValueEntities(String value1);

  /// No description provided for @commandUiWhitePageOn.
  ///
  /// In en, this message translates to:
  /// **'White Page: ON'**
  String get commandUiWhitePageOn;

  /// No description provided for @commandUiWhitePageOffTransparent.
  ///
  /// In en, this message translates to:
  /// **'White Page: OFF (Transparent)'**
  String get commandUiWhitePageOffTransparent;

  /// No description provided for @commandUiFindInText.
  ///
  /// In en, this message translates to:
  /// **'Find in Text'**
  String get commandUiFindInText;

  /// No description provided for @commandUiExitReadingModeCodeLogView.
  ///
  /// In en, this message translates to:
  /// **'Exit Reading Mode (Code/Log View)'**
  String get commandUiExitReadingModeCodeLogView;

  /// No description provided for @commandUiReadingModeReflowOverflowEBook.
  ///
  /// In en, this message translates to:
  /// **'Reading Mode (Reflow / Overflow / E-Book)'**
  String get commandUiReadingModeReflowOverflowEBook;

  /// No description provided for @commandUiSwitchToProportionalFont.
  ///
  /// In en, this message translates to:
  /// **'Switch to Proportional Font'**
  String get commandUiSwitchToProportionalFont;

  /// No description provided for @commandUiSwitchToMonospaceFont.
  ///
  /// In en, this message translates to:
  /// **'Switch to Monospace Font'**
  String get commandUiSwitchToMonospaceFont;

  /// No description provided for @commandUiTextProperties.
  ///
  /// In en, this message translates to:
  /// **'Text Properties'**
  String get commandUiTextProperties;

  /// No description provided for @commandUiFindInText2.
  ///
  /// In en, this message translates to:
  /// **'Find in text...'**
  String get commandUiFindInText2;

  /// No description provided for @commandUiPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous Match'**
  String get commandUiPreviousMatch;

  /// No description provided for @commandUiNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next Match'**
  String get commandUiNextMatch;

  /// No description provided for @commandUiRawView.
  ///
  /// In en, this message translates to:
  /// **'Raw View'**
  String get commandUiRawView;

  /// No description provided for @commandUiGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get commandUiGoBack;

  /// No description provided for @commandUiLoopOn.
  ///
  /// In en, this message translates to:
  /// **'Loop: ON'**
  String get commandUiLoopOn;

  /// No description provided for @commandUiLoopOff.
  ///
  /// In en, this message translates to:
  /// **'Loop: OFF'**
  String get commandUiLoopOff;

  /// No description provided for @commandUiPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get commandUiPlaybackSpeed;

  /// No description provided for @commandUiUnlockOrientation.
  ///
  /// In en, this message translates to:
  /// **'Unlock Orientation'**
  String get commandUiUnlockOrientation;

  /// No description provided for @commandUiLockLandscape.
  ///
  /// In en, this message translates to:
  /// **'Lock Landscape'**
  String get commandUiLockLandscape;

  /// No description provided for @commandUiUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get commandUiUnmute;

  /// No description provided for @commandUiWorkbookSheetsValue.
  ///
  /// In en, this message translates to:
  /// **'Workbook Sheets ({value1})'**
  String commandUiWorkbookSheetsValue(String value1);

  /// No description provided for @commandUiSheetValue.
  ///
  /// In en, this message translates to:
  /// **'Sheet {value1}'**
  String commandUiSheetValue(String value1);

  /// No description provided for @commandUiSearchInSheet.
  ///
  /// In en, this message translates to:
  /// **'Search in Sheet'**
  String get commandUiSearchInSheet;

  /// No description provided for @commandUiAllSheets.
  ///
  /// In en, this message translates to:
  /// **'All Sheets'**
  String get commandUiAllSheets;

  /// No description provided for @commandUiSpreadsheetProperties.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet Properties'**
  String get commandUiSpreadsheetProperties;

  /// No description provided for @commandUiSearchInActiveSheet.
  ///
  /// In en, this message translates to:
  /// **'Search in active sheet...'**
  String get commandUiSearchInActiveSheet;

  /// No description provided for @commandUiCopyCellText.
  ///
  /// In en, this message translates to:
  /// **'Copy Cell Text'**
  String get commandUiCopyCellText;

  /// No description provided for @commandUiCellContentCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Cell content copied to clipboard'**
  String get commandUiCellContentCopiedToClipboard;

  /// No description provided for @commandUiAllSheetsValue.
  ///
  /// In en, this message translates to:
  /// **'All Sheets ({value1})'**
  String commandUiAllSheetsValue(String value1);

  /// No description provided for @commandOptionLightStudio.
  ///
  /// In en, this message translates to:
  /// **'Light Studio'**
  String get commandOptionLightStudio;

  /// No description provided for @commandOptionDarkStudio.
  ///
  /// In en, this message translates to:
  /// **'Dark Studio'**
  String get commandOptionDarkStudio;

  /// No description provided for @commandOptionPureWhite.
  ///
  /// In en, this message translates to:
  /// **'Pure White'**
  String get commandOptionPureWhite;

  /// No description provided for @commandOptionPureBlack.
  ///
  /// In en, this message translates to:
  /// **'Pure Black'**
  String get commandOptionPureBlack;

  /// No description provided for @commandOptionDarkCad.
  ///
  /// In en, this message translates to:
  /// **'Dark CAD'**
  String get commandOptionDarkCad;

  /// No description provided for @commandOptionTransparencyGrid.
  ///
  /// In en, this message translates to:
  /// **'Transparency Grid'**
  String get commandOptionTransparencyGrid;

  /// No description provided for @commandOptionFr4Green.
  ///
  /// In en, this message translates to:
  /// **'FR4 Green'**
  String get commandOptionFr4Green;

  /// No description provided for @commandOptionMatteBlack.
  ///
  /// In en, this message translates to:
  /// **'Matte Black'**
  String get commandOptionMatteBlack;

  /// No description provided for @commandOptionArduinoBlue.
  ///
  /// In en, this message translates to:
  /// **'Arduino Blue'**
  String get commandOptionArduinoBlue;

  /// No description provided for @commandOptionSparkfunRed.
  ///
  /// In en, this message translates to:
  /// **'SparkFun Red'**
  String get commandOptionSparkfunRed;

  /// No description provided for @commandOptionHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get commandOptionHighContrast;

  /// No description provided for @commandOptionPcbLayersGerber.
  ///
  /// In en, this message translates to:
  /// **'PCB Layers (Gerber)'**
  String get commandOptionPcbLayersGerber;

  /// No description provided for @commandOptionCncDrillHoles.
  ///
  /// In en, this message translates to:
  /// **'CNC Drill Holes'**
  String get commandOptionCncDrillHoles;

  /// No description provided for @commandOption3DCadModels.
  ///
  /// In en, this message translates to:
  /// **'3D CAD Models'**
  String get commandOption3DCadModels;

  /// No description provided for @commandOptionSchematicsCircuits.
  ///
  /// In en, this message translates to:
  /// **'Schematics & Circuits'**
  String get commandOptionSchematicsCircuits;

  /// No description provided for @commandOptionImages3DRenders.
  ///
  /// In en, this message translates to:
  /// **'Images & 3D Renders'**
  String get commandOptionImages3DRenders;

  /// No description provided for @commandOptionBillOfMaterialsBom.
  ///
  /// In en, this message translates to:
  /// **'Bill of Materials (BOM)'**
  String get commandOptionBillOfMaterialsBom;

  /// No description provided for @commandOptionAssemblyPlacementCpl.
  ///
  /// In en, this message translates to:
  /// **'Assembly & Placement (CPL)'**
  String get commandOptionAssemblyPlacementCpl;

  /// No description provided for @commandOptionDocumentationDrawings.
  ///
  /// In en, this message translates to:
  /// **'Documentation & Drawings'**
  String get commandOptionDocumentationDrawings;

  /// No description provided for @commandOptionSourceCadProject.
  ///
  /// In en, this message translates to:
  /// **'Source CAD Project'**
  String get commandOptionSourceCadProject;

  /// No description provided for @commandOptionReportsNotes.
  ///
  /// In en, this message translates to:
  /// **'Reports & Notes'**
  String get commandOptionReportsNotes;

  /// No description provided for @commandOptionOtherFiles.
  ///
  /// In en, this message translates to:
  /// **'Other Files'**
  String get commandOptionOtherFiles;

  /// No description provided for @commandOptionGerbers.
  ///
  /// In en, this message translates to:
  /// **'Gerbers'**
  String get commandOptionGerbers;

  /// No description provided for @commandOptionPhotosRenders.
  ///
  /// In en, this message translates to:
  /// **'Photos & Renders'**
  String get commandOptionPhotosRenders;

  /// No description provided for @commandOptionBomParts.
  ///
  /// In en, this message translates to:
  /// **'BOM & Parts'**
  String get commandOptionBomParts;

  /// No description provided for @commandOptionSchematics.
  ///
  /// In en, this message translates to:
  /// **'Schematics'**
  String get commandOptionSchematics;

  /// No description provided for @commandOptionDocsReports.
  ///
  /// In en, this message translates to:
  /// **'Docs & Reports'**
  String get commandOptionDocsReports;

  /// No description provided for @commandOptionAllFiles.
  ///
  /// In en, this message translates to:
  /// **'All Files'**
  String get commandOptionAllFiles;

  /// No description provided for @commandOptionLeftToRightWestern.
  ///
  /// In en, this message translates to:
  /// **'Left to Right (Western)'**
  String get commandOptionLeftToRightWestern;

  /// No description provided for @commandOptionRightToLeftManga.
  ///
  /// In en, this message translates to:
  /// **'Right to Left (Manga)'**
  String get commandOptionRightToLeftManga;

  /// No description provided for @commandOptionVerticalScrollWebtoon.
  ///
  /// In en, this message translates to:
  /// **'Vertical Scroll (Webtoon)'**
  String get commandOptionVerticalScrollWebtoon;

  /// No description provided for @commandOptionLtr.
  ///
  /// In en, this message translates to:
  /// **'LTR'**
  String get commandOptionLtr;

  /// No description provided for @commandOptionManga.
  ///
  /// In en, this message translates to:
  /// **'Manga'**
  String get commandOptionManga;

  /// No description provided for @commandOptionWebtoon.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get commandOptionWebtoon;

  /// No description provided for @commandOptionLightPaper.
  ///
  /// In en, this message translates to:
  /// **'Light Paper'**
  String get commandOptionLightPaper;

  /// No description provided for @commandOptionWarmSepia.
  ///
  /// In en, this message translates to:
  /// **'Warm Sepia'**
  String get commandOptionWarmSepia;

  /// No description provided for @commandOptionDarkCharcoal.
  ///
  /// In en, this message translates to:
  /// **'Dark Charcoal'**
  String get commandOptionDarkCharcoal;

  /// No description provided for @commandOptionSerifBook.
  ///
  /// In en, this message translates to:
  /// **'Serif (Book)'**
  String get commandOptionSerifBook;

  /// No description provided for @commandOptionSansSerifModern.
  ///
  /// In en, this message translates to:
  /// **'Sans-Serif (Modern)'**
  String get commandOptionSansSerifModern;

  /// No description provided for @commandOptionMonospaceClean.
  ///
  /// In en, this message translates to:
  /// **'Monospace (Clean)'**
  String get commandOptionMonospaceClean;

  /// No description provided for @commandOptionPagesSwipe.
  ///
  /// In en, this message translates to:
  /// **'Pages (Swipe)'**
  String get commandOptionPagesSwipe;

  /// No description provided for @commandOptionMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get commandOptionMonospace;

  /// No description provided for @commandOptionPaginatedSwipe.
  ///
  /// In en, this message translates to:
  /// **'Paginated (Swipe)'**
  String get commandOptionPaginatedSwipe;

  /// No description provided for @commandUiCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get commandUiCheck;

  /// No description provided for @architectColumnClearance.
  ///
  /// In en, this message translates to:
  /// **'Column clearance'**
  String get architectColumnClearance;

  /// No description provided for @architectLevelFormat.
  ///
  /// In en, this message translates to:
  /// **'Level units'**
  String get architectLevelFormat;

  /// No description provided for @architectLevelSymbol.
  ///
  /// In en, this message translates to:
  /// **'Symbol'**
  String get architectLevelSymbol;

  /// No description provided for @architectLevelPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get architectLevelPlan;

  /// No description provided for @architectInheritProject.
  ///
  /// In en, this message translates to:
  /// **'Use project setting'**
  String get architectInheritProject;

  /// No description provided for @architectPrecision.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get architectPrecision;

  /// No description provided for @architectTextPaperHeight.
  ///
  /// In en, this message translates to:
  /// **'Text height (mm on paper)'**
  String get architectTextPaperHeight;

  /// No description provided for @architectTextAlignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get architectTextAlignment;

  /// No description provided for @architectTextLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get architectTextLeft;

  /// No description provided for @architectTextCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get architectTextCenter;

  /// No description provided for @architectTextRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get architectTextRight;

  /// No description provided for @architectTextWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get architectTextWeight;

  /// No description provided for @architectTextRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get architectTextRegular;

  /// No description provided for @architectTextSemibold.
  ///
  /// In en, this message translates to:
  /// **'Semibold'**
  String get architectTextSemibold;

  /// No description provided for @architectTextBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get architectTextBold;

  /// No description provided for @architectTextItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get architectTextItalic;

  /// No description provided for @architectTextUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get architectTextUnderline;

  /// No description provided for @architectPolylineOpen.
  ///
  /// In en, this message translates to:
  /// **'Open contour'**
  String get architectPolylineOpen;

  /// No description provided for @architectPolylineEdge.
  ///
  /// In en, this message translates to:
  /// **'Move segment'**
  String get architectPolylineEdge;

  /// No description provided for @architectDrainInvalidSurface.
  ///
  /// In en, this message translates to:
  /// **'The floor cannot drain continuously to this grate. Adjust the contour or drain position.'**
  String get architectDrainInvalidSurface;

  /// No description provided for @architectPolylineClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed contour'**
  String get architectPolylineClosed;

  /// No description provided for @architectFenestrationLeafShort.
  ///
  /// In en, this message translates to:
  /// **'Leaf'**
  String get architectFenestrationLeafShort;

  /// No description provided for @architectFenestrationDetailsShort.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get architectFenestrationDetailsShort;

  /// No description provided for @architectFenestrationTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get architectFenestrationTemplates;

  /// No description provided for @architectFenestrationElevationShort.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectFenestrationElevationShort;

  /// No description provided for @architectFenestrationPlanShort.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get architectFenestrationPlanShort;

  /// No description provided for @architectFenestrationTransom.
  ///
  /// In en, this message translates to:
  /// **'Transom'**
  String get architectFenestrationTransom;

  /// No description provided for @architectFenestrationTransomHeight.
  ///
  /// In en, this message translates to:
  /// **'Transom height'**
  String get architectFenestrationTransomHeight;

  /// No description provided for @architectFenestrationDoorBodyHeight.
  ///
  /// In en, this message translates to:
  /// **'Door height'**
  String get architectFenestrationDoorBodyHeight;

  /// No description provided for @architectFenestrationTotalHeight.
  ///
  /// In en, this message translates to:
  /// **'Overall height'**
  String get architectFenestrationTotalHeight;

  /// No description provided for @architectFenestrationName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get architectFenestrationName;

  /// No description provided for @architectFenestrationNewWindow.
  ///
  /// In en, this message translates to:
  /// **'New window'**
  String get architectFenestrationNewWindow;

  /// No description provided for @architectFenestrationNewDoor.
  ///
  /// In en, this message translates to:
  /// **'New door'**
  String get architectFenestrationNewDoor;

  /// No description provided for @architectFenestrationDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get architectFenestrationDiscardTitle;

  /// No description provided for @architectFenestrationDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your model changes have not been saved.'**
  String get architectFenestrationDiscardMessage;

  /// No description provided for @architectFenestrationDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get architectFenestrationDiscard;

  /// No description provided for @architectFenestrationKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get architectFenestrationKeepEditing;

  /// No description provided for @architectFenestrationSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the model. Try again.'**
  String get architectFenestrationSaveError;

  /// No description provided for @architectFenestrationRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get architectFenestrationRedo;

  /// No description provided for @architectFenestrationEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit model'**
  String get architectFenestrationEdit;

  /// No description provided for @architectFenestrationInvalidSize.
  ///
  /// In en, this message translates to:
  /// **'Invalid size'**
  String get architectFenestrationInvalidSize;

  /// No description provided for @architectFenestrationInfill.
  ///
  /// In en, this message translates to:
  /// **'Infill'**
  String get architectFenestrationInfill;

  /// No description provided for @architectFenestrationProfileDepth.
  ///
  /// In en, this message translates to:
  /// **'Frame depth'**
  String get architectFenestrationProfileDepth;

  /// No description provided for @architectFenestrationProfileFace.
  ///
  /// In en, this message translates to:
  /// **'Frame face width'**
  String get architectFenestrationProfileFace;

  /// No description provided for @architectFenestration3DShort.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get architectFenestration3DShort;

  /// No description provided for @architectFenestrationGlazing.
  ///
  /// In en, this message translates to:
  /// **'Glazing'**
  String get architectFenestrationGlazing;

  /// No description provided for @architectFenestrationGlazingSingleShort.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get architectFenestrationGlazingSingleShort;

  /// No description provided for @architectFenestrationGlazingDoubleShort.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get architectFenestrationGlazingDoubleShort;

  /// No description provided for @architectFenestrationGlazingTripleShort.
  ///
  /// In en, this message translates to:
  /// **'Triple'**
  String get architectFenestrationGlazingTripleShort;

  /// No description provided for @architectToolSearch.
  ///
  /// In en, this message translates to:
  /// **'Find a tool'**
  String get architectToolSearch;

  /// No description provided for @architectToolNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tools found.'**
  String get architectToolNoResults;

  /// No description provided for @architectSheetFit.
  ///
  /// In en, this message translates to:
  /// **'Fit sheet'**
  String get architectSheetFit;

  /// No description provided for @architectSheetReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for PDF'**
  String get architectSheetReady;

  /// No description provided for @architectSheetCheck.
  ///
  /// In en, this message translates to:
  /// **'Check layout'**
  String get architectSheetCheck;

  /// No description provided for @architectSheetOutside.
  ///
  /// In en, this message translates to:
  /// **'A drawing or its title extends beyond the sheet margins. Move it or reduce its frame.'**
  String get architectSheetOutside;

  /// No description provided for @architectSheetOverlap.
  ///
  /// In en, this message translates to:
  /// **'Drawings overlap. Move their frames apart.'**
  String get architectSheetOverlap;

  /// No description provided for @architectSheetTitleOverlap.
  ///
  /// In en, this message translates to:
  /// **'A drawing overlaps the title block. Move it or edit its boundary.'**
  String get architectSheetTitleOverlap;

  /// No description provided for @architectSheetMissingTemplate.
  ///
  /// In en, this message translates to:
  /// **'The title block template is missing. Select a template.'**
  String get architectSheetMissingTemplate;

  /// No description provided for @architectSheetExported.
  ///
  /// In en, this message translates to:
  /// **'PDF saved.'**
  String get architectSheetExported;

  /// No description provided for @architectSheetScaleAdjusted.
  ///
  /// In en, this message translates to:
  /// **'The view fits at 1:{scale}.'**
  String architectSheetScaleAdjusted(int scale);

  /// No description provided for @architectSheetCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get architectSheetCrop;

  /// No description provided for @architectSheetCropRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get architectSheetCropRectangle;

  /// No description provided for @architectSheetCropPolygon.
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get architectSheetCropPolygon;

  /// No description provided for @architectSheetCropAddPoint.
  ///
  /// In en, this message translates to:
  /// **'Add point'**
  String get architectSheetCropAddPoint;

  /// No description provided for @architectSheetCropRemovePoint.
  ///
  /// In en, this message translates to:
  /// **'Remove point'**
  String get architectSheetCropRemovePoint;

  /// No description provided for @architectSheetCropInvalid.
  ///
  /// In en, this message translates to:
  /// **'The boundary crosses itself or has no area.'**
  String get architectSheetCropInvalid;

  /// No description provided for @architectSheetPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a position for the drawing.'**
  String get architectSheetPlaceHint;

  /// No description provided for @architectSheetSnap.
  ///
  /// In en, this message translates to:
  /// **'Snap'**
  String get architectSheetSnap;

  /// No description provided for @architectSheetSelectDrawing.
  ///
  /// In en, this message translates to:
  /// **'Select drawing'**
  String get architectSheetSelectDrawing;

  /// No description provided for @architectSheetCropHint.
  ///
  /// In en, this message translates to:
  /// **'Move the boundary to crop the drawing without changing its scale. Fit view restores the full source.'**
  String get architectSheetCropHint;

  /// No description provided for @architectSheetScaleHint.
  ///
  /// In en, this message translates to:
  /// **'Changing scale also resizes the boundary. For example, 1:50 to 1:100 halves its width and height.'**
  String get architectSheetScaleHint;

  /// No description provided for @architectSheetVisibilityHint.
  ///
  /// In en, this message translates to:
  /// **'Visibility applies only to this placement.'**
  String get architectSheetVisibilityHint;

  /// No description provided for @architectSheetFitView.
  ///
  /// In en, this message translates to:
  /// **'Fit view'**
  String get architectSheetFitView;

  /// No description provided for @architectSheetExportOrder.
  ///
  /// In en, this message translates to:
  /// **'PDF page order follows your selection.'**
  String get architectSheetExportOrder;

  /// No description provided for @architectSheetNoSpace.
  ///
  /// In en, this message translates to:
  /// **'The view cannot fit in the available space. Move or resize the drawings, or place it freely.'**
  String get architectSheetNoSpace;

  /// No description provided for @architectSheetPlaceShort.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get architectSheetPlaceShort;

  /// No description provided for @architectCategoryServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get architectCategoryServices;

  /// No description provided for @architectServiceBodies.
  ///
  /// In en, this message translates to:
  /// **'Risers'**
  String get architectServiceBodies;

  /// No description provided for @architectOpeningCircular.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get architectOpeningCircular;

  /// No description provided for @architectOpeningCircularHelp.
  ///
  /// In en, this message translates to:
  /// **'Round penetration for drainage, water or pipes. Two points define its bounds; the shorter side sets the diameter.'**
  String get architectOpeningCircularHelp;

  /// No description provided for @architectServiceVentSingle.
  ///
  /// In en, this message translates to:
  /// **'Single vent block'**
  String get architectServiceVentSingle;

  /// No description provided for @architectServiceVentDouble.
  ///
  /// In en, this message translates to:
  /// **'Twin vent block'**
  String get architectServiceVentDouble;

  /// No description provided for @architectServiceVentTransition.
  ///
  /// In en, this message translates to:
  /// **'Concrete transition'**
  String get architectServiceVentTransition;

  /// No description provided for @architectServiceCompactVent.
  ///
  /// In en, this message translates to:
  /// **'Compact LS 1'**
  String get architectServiceCompactVent;

  /// No description provided for @architectServiceCompactTransition.
  ///
  /// In en, this message translates to:
  /// **'LS 1 transition'**
  String get architectServiceCompactTransition;

  /// No description provided for @architectServiceCombinedRiser.
  ///
  /// In en, this message translates to:
  /// **'Combined plumbing riser'**
  String get architectServiceCombinedRiser;

  /// No description provided for @architectServiceSewer.
  ///
  /// In en, this message translates to:
  /// **'Drain Ø110'**
  String get architectServiceSewer;

  /// No description provided for @architectServiceWater.
  ///
  /// In en, this message translates to:
  /// **'Water Ø32'**
  String get architectServiceWater;

  /// No description provided for @architectServiceDryRiser.
  ///
  /// In en, this message translates to:
  /// **'Dry riser DN100'**
  String get architectServiceDryRiser;

  /// No description provided for @architectServiceSleeve.
  ///
  /// In en, this message translates to:
  /// **'Sleeve Ø160'**
  String get architectServiceSleeve;

  /// No description provided for @architectServiceChimney.
  ///
  /// In en, this message translates to:
  /// **'Chimney Ø180'**
  String get architectServiceChimney;

  /// No description provided for @architectServiceVentHelp.
  ///
  /// In en, this message translates to:
  /// **'Concrete ventilation blocks, 300×250×200 or 500×300×200 mm, stacked vertically with hollow channels. For ventilation.'**
  String get architectServiceVentHelp;

  /// No description provided for @architectServiceTransitionHelp.
  ///
  /// In en, this message translates to:
  /// **'Transition comprising two 500×300×200 mm concrete blocks. A schematic opening in the web connects the branch to the main channel; check the manufacturer’s installation detail.'**
  String get architectServiceTransitionHelp;

  /// No description provided for @architectServiceCompactHelp.
  ///
  /// In en, this message translates to:
  /// **'Envelope based on Schiedel LS 1: 355×220 mm, 330 mm course. Main channel 200×170 mm and branch 90×170 mm. Transition geometry is schematic.'**
  String get architectServiceCompactHelp;

  /// No description provided for @architectServiceCombinedHelp.
  ///
  /// In en, this message translates to:
  /// **'Coordination layout, 500×250 mm: Ø110 drain, Ø50 pipe and two insulated Ø32 water pipes with an inspection cover. Coordinate the enclosure size for the project.'**
  String get architectServiceCombinedHelp;

  /// No description provided for @architectServicePipeHelp.
  ///
  /// In en, this message translates to:
  /// **'Hollow pipe or sleeve with a clear bore. Intersected slabs are cut automatically; dimensions are in centimetres.'**
  String get architectServicePipeHelp;

  /// No description provided for @architectServiceDryHelp.
  ///
  /// In en, this message translates to:
  /// **'Vertical DN100 steel pipe, 114.3 mm outside diameter. Coordination element; fittings and fire service design are specified by the project.'**
  String get architectServiceDryHelp;

  /// No description provided for @architectServiceChimneyHelp.
  ///
  /// In en, this message translates to:
  /// **'Envelope 360×360 mm with Ø180 flue based on Schiedel ABSOLUT. Hollow ceramic liner, insulation, casing and ventilated cap. Above-roof height and clearances are project parameters.'**
  String get architectServiceChimneyHelp;

  /// No description provided for @architectServiceCap.
  ///
  /// In en, this message translates to:
  /// **'Cap'**
  String get architectServiceCap;

  /// No description provided for @architectServiceCapNone.
  ///
  /// In en, this message translates to:
  /// **'Open top'**
  String get architectServiceCapNone;

  /// No description provided for @architectServiceCapFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get architectServiceCapFlat;

  /// No description provided for @architectServiceCapPitched.
  ///
  /// In en, this message translates to:
  /// **'Pitched'**
  String get architectServiceCapPitched;

  /// No description provided for @architectServiceCapConical.
  ///
  /// In en, this message translates to:
  /// **'Conical'**
  String get architectServiceCapConical;

  /// No description provided for @architectServiceAutoHeight.
  ///
  /// In en, this message translates to:
  /// **'Follow roof'**
  String get architectServiceAutoHeight;

  /// No description provided for @architectServiceAutoHeightHelp.
  ///
  /// In en, this message translates to:
  /// **'Height follows the highest intersected roof surface plus the chosen extension. This is a geometry setting; the required height is determined by the project.'**
  String get architectServiceAutoHeightHelp;

  /// No description provided for @architectServiceAboveRoof.
  ///
  /// In en, this message translates to:
  /// **'Above roof'**
  String get architectServiceAboveRoof;

  /// No description provided for @architectServiceFlueDiameter.
  ///
  /// In en, this message translates to:
  /// **'Flue Ø'**
  String get architectServiceFlueDiameter;

  /// No description provided for @architectServiceRoofClearance.
  ///
  /// In en, this message translates to:
  /// **'Roof clearance'**
  String get architectServiceRoofClearance;

  /// No description provided for @architectServiceVent.
  ///
  /// In en, this message translates to:
  /// **'Vent Ø110'**
  String get architectServiceVent;

  /// No description provided for @architectServiceFireplace.
  ///
  /// In en, this message translates to:
  /// **'Fireplace'**
  String get architectServiceFireplace;

  /// No description provided for @architectServiceFireplaceHelp.
  ///
  /// In en, this message translates to:
  /// **'Compact 550×600 mm fireplace with combustion chamber, door, grate and Ø180 flue. Upper levels show only the chimney; its roof opening and flashing follow the fireplace when moved. The coordination envelope follows compact fireplace modules.'**
  String get architectServiceFireplaceHelp;

  /// No description provided for @architectServiceAllStoreys.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get architectServiceAllStoreys;

  /// No description provided for @architectServiceAllStoreysHelp.
  ///
  /// In en, this message translates to:
  /// **'One continuous element from the lowest storey to the roof. Switch off to start at its placement level. Edit or delete it on the placement level to update every plan.'**
  String get architectServiceAllStoreysHelp;

  /// No description provided for @architectServiceVentOutletHelp.
  ///
  /// In en, this message translates to:
  /// **'Open Ø110 roof vent with weather collar and flashing. Automatic height and the above-roof extension can be adjusted.'**
  String get architectServiceVentOutletHelp;

  /// No description provided for @architectNewPointDistanceTitle.
  ///
  /// In en, this message translates to:
  /// **'From end {endpoint}'**
  String architectNewPointDistanceTitle(int endpoint);

  /// No description provided for @architectNewPointDistanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Distance along the wall from end {endpoint}. Tap to enter an exact value.'**
  String architectNewPointDistanceHelp(int endpoint);

  /// No description provided for @architectNewPointDistanceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Place the point within the wall, away from ends and openings.'**
  String get architectNewPointDistanceInvalid;

  /// No description provided for @wallFamilyBrick.
  ///
  /// In en, this message translates to:
  /// **'Brick'**
  String get wallFamilyBrick;

  /// No description provided for @wallFamilyAerated.
  ///
  /// In en, this message translates to:
  /// **'Aerated concrete'**
  String get wallFamilyAerated;

  /// No description provided for @wallFamilyConcrete.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get wallFamilyConcrete;

  /// No description provided for @wallFamilyPlasterboard.
  ///
  /// In en, this message translates to:
  /// **'Plasterboard'**
  String get wallFamilyPlasterboard;

  /// No description provided for @wallFamilyBrickEps.
  ///
  /// In en, this message translates to:
  /// **'Brick + EPS'**
  String get wallFamilyBrickEps;

  /// No description provided for @wallFamilyBrickWool.
  ///
  /// In en, this message translates to:
  /// **'Brick + wool'**
  String get wallFamilyBrickWool;

  /// No description provided for @wallFamilyAeratedWool.
  ///
  /// In en, this message translates to:
  /// **'Aerated concrete + wool'**
  String get wallFamilyAeratedWool;

  /// No description provided for @wallFamilyConcreteWool.
  ///
  /// In en, this message translates to:
  /// **'Concrete + wool'**
  String get wallFamilyConcreteWool;

  /// No description provided for @wallFamilySandwich.
  ///
  /// In en, this message translates to:
  /// **'Sandwich panel'**
  String get wallFamilySandwich;

  /// No description provided for @wallFamilyLogs.
  ///
  /// In en, this message translates to:
  /// **'Round logs'**
  String get wallFamilyLogs;

  /// No description provided for @compositionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get compositionDetails;

  /// No description provided for @compositionTab.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get compositionTab;

  /// No description provided for @compositionPreset.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get compositionPreset;

  /// No description provided for @compositionTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get compositionTotal;

  /// No description provided for @compositionScopeType.
  ///
  /// In en, this message translates to:
  /// **'Type ({count})'**
  String compositionScopeType(int count);

  /// No description provided for @compositionScopeSelection.
  ///
  /// In en, this message translates to:
  /// **'Selected ({count})'**
  String compositionScopeSelection(int count);

  /// No description provided for @compositionScopeThis.
  ///
  /// In en, this message translates to:
  /// **'Only this'**
  String get compositionScopeThis;

  /// No description provided for @compositionFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get compositionFavorites;

  /// No description provided for @compositionNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get compositionNoMatches;

  /// No description provided for @railingModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get railingModel;

  /// No description provided for @railingLegacy.
  ///
  /// In en, this message translates to:
  /// **'Current parapet'**
  String get railingLegacy;

  /// No description provided for @railingSolidCap.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get railingSolidCap;

  /// No description provided for @railingSolidStainless.
  ///
  /// In en, this message translates to:
  /// **'Solid + stainless'**
  String get railingSolidStainless;

  /// No description provided for @railingGlassChannel.
  ///
  /// In en, this message translates to:
  /// **'Glass · channel'**
  String get railingGlassChannel;

  /// No description provided for @railingGlassPosts.
  ///
  /// In en, this message translates to:
  /// **'Glass · posts'**
  String get railingGlassPosts;

  /// No description provided for @railingVerticalBars.
  ///
  /// In en, this message translates to:
  /// **'Vertical bars'**
  String get railingVerticalBars;

  /// No description provided for @railingVerticalSlats.
  ///
  /// In en, this message translates to:
  /// **'Slats'**
  String get railingVerticalSlats;

  /// No description provided for @railingHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get railingHeight;

  /// No description provided for @railingSolidHeight.
  ///
  /// In en, this message translates to:
  /// **'Solid part'**
  String get railingSolidHeight;

  /// No description provided for @railingTotalHeightHelp.
  ///
  /// In en, this message translates to:
  /// **'Total height, including the handrail.'**
  String get railingTotalHeightHelp;

  /// No description provided for @railingMount.
  ///
  /// In en, this message translates to:
  /// **'Mounting'**
  String get railingMount;

  /// No description provided for @railingMountTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get railingMountTop;

  /// No description provided for @railingMountSide.
  ///
  /// In en, this message translates to:
  /// **'Fascia'**
  String get railingMountSide;

  /// No description provided for @railingHandrailDiameter.
  ///
  /// In en, this message translates to:
  /// **'Handrail Ø'**
  String get railingHandrailDiameter;

  /// No description provided for @railingPostSize.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get railingPostSize;

  /// No description provided for @railingPostSpacing.
  ///
  /// In en, this message translates to:
  /// **'Maximum bay'**
  String get railingPostSpacing;

  /// No description provided for @railingGlassThickness.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get railingGlassThickness;

  /// No description provided for @railingPanelWidth.
  ///
  /// In en, this message translates to:
  /// **'Maximum panel'**
  String get railingPanelWidth;

  /// No description provided for @railingPanelGap.
  ///
  /// In en, this message translates to:
  /// **'Joint'**
  String get railingPanelGap;

  /// No description provided for @railingBottomGap.
  ///
  /// In en, this message translates to:
  /// **'Bottom gap'**
  String get railingBottomGap;

  /// No description provided for @railingInfillSpacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get railingInfillSpacing;

  /// No description provided for @railingInfillWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get railingInfillWidth;

  /// No description provided for @railingInfillDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get railingInfillDepth;

  /// No description provided for @railingCopingThickness.
  ///
  /// In en, this message translates to:
  /// **'Coping'**
  String get railingCopingThickness;

  /// No description provided for @railingChannelWidth.
  ///
  /// In en, this message translates to:
  /// **'Channel width'**
  String get railingChannelWidth;

  /// No description provided for @railingChannelHeight.
  ///
  /// In en, this message translates to:
  /// **'Channel height'**
  String get railingChannelHeight;

  /// No description provided for @railingInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the railing dimensions.'**
  String get railingInvalid;

  /// No description provided for @railingHasOpenings.
  ///
  /// In en, this message translates to:
  /// **'Move or remove the wall’s doors and windows first.'**
  String get railingHasOpenings;

  /// No description provided for @railingUnsupportedOpenings.
  ///
  /// In en, this message translates to:
  /// **'This railing cannot host doors or windows.'**
  String get railingUnsupportedOpenings;

  /// No description provided for @roofParapet.
  ///
  /// In en, this message translates to:
  /// **'Parapet'**
  String get roofParapet;

  /// No description provided for @roofParapetEnable.
  ///
  /// In en, this message translates to:
  /// **'Parapet (Attic Wall)'**
  String get roofParapetEnable;

  /// No description provided for @roofParapetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Parapet'**
  String get roofParapetAdd;

  /// No description provided for @roofParapetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Parapet'**
  String get roofParapetRemove;

  /// No description provided for @roofParapetHeight.
  ///
  /// In en, this message translates to:
  /// **'Parapet Height'**
  String get roofParapetHeight;

  /// No description provided for @roofParapetCore.
  ///
  /// In en, this message translates to:
  /// **'Structural Core'**
  String get roofParapetCore;

  /// No description provided for @roofParapetInsulation.
  ///
  /// In en, this message translates to:
  /// **'Exterior Insulation'**
  String get roofParapetInsulation;

  /// No description provided for @roofParapetInteriorFinish.
  ///
  /// In en, this message translates to:
  /// **'Interior Finish'**
  String get roofParapetInteriorFinish;

  /// No description provided for @roofParapetCoping.
  ///
  /// In en, this message translates to:
  /// **'Coping Cap'**
  String get roofParapetCoping;

  /// No description provided for @roofParapetCopingProjection.
  ///
  /// In en, this message translates to:
  /// **'Coping Drip Overhang'**
  String get roofParapetCopingProjection;

  /// No description provided for @roofDownpipeType.
  ///
  /// In en, this message translates to:
  /// **'Discharge Route'**
  String get roofDownpipeType;

  /// No description provided for @roofDownpipeExternal.
  ///
  /// In en, this message translates to:
  /// **'External on Facade'**
  String get roofDownpipeExternal;

  /// No description provided for @roofDownpipeInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal Vertical Shaft (VT)'**
  String get roofDownpipeInternal;

  /// No description provided for @architectCategoryDecorative.
  ///
  /// In en, this message translates to:
  /// **'3D Decor'**
  String get architectCategoryDecorative;

  /// No description provided for @architectToolDecorativeProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get architectToolDecorativeProfile;

  /// No description provided for @architectToolDecorativeFrame.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get architectToolDecorativeFrame;

  /// No description provided for @architectToolDecorativeArc.
  ///
  /// In en, this message translates to:
  /// **'Arc / Circle'**
  String get architectToolDecorativeArc;

  /// No description provided for @architectToolDecorativeVoid.
  ///
  /// In en, this message translates to:
  /// **'Cutout'**
  String get architectToolDecorativeVoid;

  /// No description provided for @architectToolDecorativeLibrary.
  ///
  /// In en, this message translates to:
  /// **'3D Studio'**
  String get architectToolDecorativeLibrary;

  /// No description provided for @architectDecorativeDepth.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get architectDecorativeDepth;

  /// No description provided for @architectDecorativeLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get architectDecorativeLength;

  /// No description provided for @architectDecorativeWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectDecorativeWidth;

  /// No description provided for @architectDecorativeHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectDecorativeHeight;

  /// No description provided for @architectDecorativeFrameWidth.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get architectDecorativeFrameWidth;

  /// No description provided for @architectDecorativeSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get architectDecorativeSolid;

  /// No description provided for @architectDecorativeNormalOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get architectDecorativeNormalOffset;

  /// No description provided for @architectDecorativeMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get architectDecorativeMaterial;

  /// No description provided for @architectDecorativeShowOnPlan.
  ///
  /// In en, this message translates to:
  /// **'Show on plan'**
  String get architectDecorativeShowOnPlan;

  /// No description provided for @architectDecorativeShowAllOnPlan.
  ///
  /// In en, this message translates to:
  /// **'3D decor on plan'**
  String get architectDecorativeShowAllOnPlan;

  /// No description provided for @architectDecorativeStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'3D Decorative Detail Studio'**
  String get architectDecorativeStudioTitle;

  /// No description provided for @architectDecorativeTabFront.
  ///
  /// In en, this message translates to:
  /// **'Front (Facade)'**
  String get architectDecorativeTabFront;

  /// No description provided for @architectDecorativeTabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile (Section)'**
  String get architectDecorativeTabProfile;

  /// No description provided for @architectDecorativeTab3D.
  ///
  /// In en, this message translates to:
  /// **'3D View'**
  String get architectDecorativeTab3D;

  /// No description provided for @architectDecorativeAddHole.
  ///
  /// In en, this message translates to:
  /// **'Cut opening'**
  String get architectDecorativeAddHole;

  /// No description provided for @architectDecorativeClearHoles.
  ///
  /// In en, this message translates to:
  /// **'Clear openings'**
  String get architectDecorativeClearHoles;

  /// No description provided for @architectDecorativeSaveLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get architectDecorativeSaveLibrary;

  /// No description provided for @architectDecorativeSavedMsg.
  ///
  /// In en, this message translates to:
  /// **'3D decorative element saved to library.'**
  String get architectDecorativeSavedMsg;

  /// No description provided for @architectDecorativeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get architectDecorativeTemplates;

  /// No description provided for @architectDecorativePresetCornice.
  ///
  /// In en, this message translates to:
  /// **'Eaves cornice'**
  String get architectDecorativePresetCornice;

  /// No description provided for @architectDecorativePresetWindowFrame.
  ///
  /// In en, this message translates to:
  /// **'Window frame'**
  String get architectDecorativePresetWindowFrame;

  /// No description provided for @architectDecorativePresetWindowSill.
  ///
  /// In en, this message translates to:
  /// **'Window sill'**
  String get architectDecorativePresetWindowSill;

  /// No description provided for @architectDecorativePresetBracket.
  ///
  /// In en, this message translates to:
  /// **'Eaves bracket'**
  String get architectDecorativePresetBracket;

  /// No description provided for @architectDecorativePresetKeystone.
  ///
  /// In en, this message translates to:
  /// **'Keystone'**
  String get architectDecorativePresetKeystone;

  /// No description provided for @architectDecorativePresetPilaster.
  ///
  /// In en, this message translates to:
  /// **'Pilaster'**
  String get architectDecorativePresetPilaster;

  /// No description provided for @architectDecorativePresetPerforatedPanel.
  ///
  /// In en, this message translates to:
  /// **'Perforated panel'**
  String get architectDecorativePresetPerforatedPanel;

  /// No description provided for @architectDecorativeMaterialEps.
  ///
  /// In en, this message translates to:
  /// **'EPS profile'**
  String get architectDecorativeMaterialEps;

  /// No description provided for @architectDecorativeMaterialPlaster.
  ///
  /// In en, this message translates to:
  /// **'Plaster'**
  String get architectDecorativeMaterialPlaster;

  /// No description provided for @architectDecorativeMaterialStone.
  ///
  /// In en, this message translates to:
  /// **'Stone'**
  String get architectDecorativeMaterialStone;

  /// No description provided for @architectDecorativeMaterialTimber.
  ///
  /// In en, this message translates to:
  /// **'Timber'**
  String get architectDecorativeMaterialTimber;

  /// No description provided for @architectDecorativeMaterialConcrete.
  ///
  /// In en, this message translates to:
  /// **'Concrete'**
  String get architectDecorativeMaterialConcrete;

  /// No description provided for @architectDecorativeMaterialMetal.
  ///
  /// In en, this message translates to:
  /// **'Metal'**
  String get architectDecorativeMaterialMetal;

  /// No description provided for @architectDecorativeStretchLeft.
  ///
  /// In en, this message translates to:
  /// **'Stretch left'**
  String get architectDecorativeStretchLeft;

  /// No description provided for @architectDecorativeStretchRight.
  ///
  /// In en, this message translates to:
  /// **'Stretch right'**
  String get architectDecorativeStretchRight;

  /// No description provided for @architectDecorativeEditStudio.
  ///
  /// In en, this message translates to:
  /// **'3D Editor'**
  String get architectDecorativeEditStudio;

  /// No description provided for @architectDecorativeHintSection.
  ///
  /// In en, this message translates to:
  /// **'Draw profile in section. Tap start point to close.'**
  String get architectDecorativeHintSection;

  /// No description provided for @architectDecorativeHintFacade.
  ///
  /// In en, this message translates to:
  /// **'Draw decorative shape on facade.'**
  String get architectDecorativeHintFacade;

  /// No description provided for @architectDecorativeHintFrame.
  ///
  /// In en, this message translates to:
  /// **'Tap two corners to place frame or panel.'**
  String get architectDecorativeHintFrame;

  /// No description provided for @architectDecorativeHintArc.
  ///
  /// In en, this message translates to:
  /// **'Tap center and radius (or 3 arc points).'**
  String get architectDecorativeHintArc;

  /// No description provided for @architectDecorativeHintVoid.
  ///
  /// In en, this message translates to:
  /// **'Tap two corners on a decorative element to cut an opening.'**
  String get architectDecorativeHintVoid;

  /// Wall start height for sloped gable walls
  ///
  /// In en, this message translates to:
  /// **'Start Height (H1)'**
  String get architectPropertyStartHeight;

  /// Wall end height for sloped gable walls
  ///
  /// In en, this message translates to:
  /// **'End Height (H2)'**
  String get architectPropertyEndHeight;

  /// Transverse slant/tilt angle of a wall from vertical in degrees
  ///
  /// In en, this message translates to:
  /// **'Tilt Angle'**
  String get architectPropertyTiltAngle;

  /// Toggle to make a wall sloped/trapezoidal at the top for gables
  ///
  /// In en, this message translates to:
  /// **'Sloped top (Gable)'**
  String get architectWallSlopedTop;

  /// Help subtitle for sloped gable walls
  ///
  /// In en, this message translates to:
  /// **'Different height at start and end for gables and ramp walls'**
  String get architectWallSlopedTopHelp;

  /// Whether roof underside cuts the wall top
  ///
  /// In en, this message translates to:
  /// **'Clip to roof'**
  String get architectWallClipToRoof;

  /// Calculated slope of a sloped gable wall
  ///
  /// In en, this message translates to:
  /// **'Slope: {angle}° ({percent}%)'**
  String architectWallCalculatedSlope(String angle, String percent);

  /// Chamfer command to bevel a corner
  ///
  /// In en, this message translates to:
  /// **'Chamfer'**
  String get architectChamfer;

  /// Fillet command to round a corner in an arc
  ///
  /// In en, this message translates to:
  /// **'Fillet'**
  String get architectFillet;

  /// Distance to cut back corner for chamfer
  ///
  /// In en, this message translates to:
  /// **'Chamfer distance'**
  String get architectChamferDistance;

  /// Radius of corner fillet arc
  ///
  /// In en, this message translates to:
  /// **'Fillet radius'**
  String get architectFilletRadius;

  /// Apply chamfer or fillet to all polygon corners
  ///
  /// In en, this message translates to:
  /// **'Apply to all corners'**
  String get architectApplyToAllCorners;

  /// Apply chamfer or fillet to selected corner
  ///
  /// In en, this message translates to:
  /// **'Apply to selected corner'**
  String get architectApplyToCorner;

  /// Error when chamfer or fillet exceeds segment length
  ///
  /// In en, this message translates to:
  /// **'Cannot form this corner. Check the distance or radius, wall types and openings.'**
  String get architectChamferFilletInvalid;

  /// Layers management title
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get architectLayers;

  /// Button to create a new custom layer
  ///
  /// In en, this message translates to:
  /// **'New Layer'**
  String get architectNewLayer;

  /// Label for layer name input
  ///
  /// In en, this message translates to:
  /// **'Layer name'**
  String get architectLayerName;

  /// Delete custom layer action
  ///
  /// In en, this message translates to:
  /// **'Delete layer'**
  String get architectDeleteLayer;

  /// Change layer of selected element(s)
  ///
  /// In en, this message translates to:
  /// **'Change layer'**
  String get architectChangeLayer;

  /// Indicates current layer of element
  ///
  /// In en, this message translates to:
  /// **'Current layer: {name}'**
  String architectCurrentLayer(String name);

  /// Prompt to pick a target layer
  ///
  /// In en, this message translates to:
  /// **'Select layer'**
  String get architectSelectLayer;

  /// Warning when trying to delete built-in layer
  ///
  /// In en, this message translates to:
  /// **'Standard layers cannot be deleted'**
  String get architectCannotDeleteStandardLayer;

  /// Color associated with layer
  ///
  /// In en, this message translates to:
  /// **'Layer color'**
  String get architectLayerColor;

  /// Button to make all layers visible
  ///
  /// In en, this message translates to:
  /// **'Show all layers'**
  String get architectAllLayersVisible;

  /// Layer for walls
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get architectLayerWalls;

  /// Layer for doors
  ///
  /// In en, this message translates to:
  /// **'Doors'**
  String get architectLayerDoors;

  /// Layer for windows
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get architectLayerWindows;

  /// Layer for slabs
  ///
  /// In en, this message translates to:
  /// **'Slabs'**
  String get architectLayerSlabs;

  /// Layer for roofs
  ///
  /// In en, this message translates to:
  /// **'Roofs'**
  String get architectLayerRoofs;

  /// Layer for columns
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get architectLayerColumns;

  /// Layer for beams
  ///
  /// In en, this message translates to:
  /// **'Beams'**
  String get architectLayerBeams;

  /// Layer for stairs
  ///
  /// In en, this message translates to:
  /// **'Stairs'**
  String get architectLayerStairs;

  /// Layer for zones and rooms
  ///
  /// In en, this message translates to:
  /// **'Rooms & Zones'**
  String get architectLayerZones;

  /// Layer for dimensions
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get architectLayerDimensions;

  /// Layer for text and annotations
  ///
  /// In en, this message translates to:
  /// **'Text & Annotations'**
  String get architectLayerText;

  /// Layer for structural grid axes
  ///
  /// In en, this message translates to:
  /// **'Grid Axes'**
  String get architectLayerGrid;

  /// Layer for hatches and fills
  ///
  /// In en, this message translates to:
  /// **'Hatches'**
  String get architectLayerHatches;

  /// Layer for CAD drawing primitives
  ///
  /// In en, this message translates to:
  /// **'CAD Lines'**
  String get architectLayerCad;

  /// Layer for site contours and drainage
  ///
  /// In en, this message translates to:
  /// **'Site & Drainage'**
  String get architectLayerDrainage;

  /// Title and tool name for criteria-based selection
  ///
  /// In en, this message translates to:
  /// **'Find & Select'**
  String get architectFindAndSelect;

  /// Tooltip explaining find and select tool
  ///
  /// In en, this message translates to:
  /// **'Filter elements by criteria across storeys and batch modify properties'**
  String get architectFindAndSelectHelp;

  /// Search scope option for all storeys
  ///
  /// In en, this message translates to:
  /// **'All storeys'**
  String get architectScopeAllStoreys;

  /// Search scope option for current active storey
  ///
  /// In en, this message translates to:
  /// **'Active storey'**
  String get architectScopeActiveStorey;

  /// Search scope option for a selected storey
  ///
  /// In en, this message translates to:
  /// **'Specific storey'**
  String get architectScopeSpecificStorey;

  /// Button to populate criteria from selected element
  ///
  /// In en, this message translates to:
  /// **'Pick from selected'**
  String get architectSampleFromSelection;

  /// Tooltip for pick from selected element
  ///
  /// In en, this message translates to:
  /// **'Populate criteria matching the currently selected element'**
  String get architectSampleFromSelectionTooltip;

  /// Header for filter criteria section
  ///
  /// In en, this message translates to:
  /// **'Criteria'**
  String get architectFilterCriteria;

  /// Counter of matching elements across storeys
  ///
  /// In en, this message translates to:
  /// **'{count} elements found ({storeys, plural, one{1 storey} other{{storeys} storeys}})'**
  String architectFilterMatchesCount(int count, int storeys);

  /// Simple match counter
  ///
  /// In en, this message translates to:
  /// **'{count} matching elements'**
  String architectFilterMatchesSimple(int count);

  /// Tab and action label for batch property modification
  ///
  /// In en, this message translates to:
  /// **'Batch Modify'**
  String get architectBatchModify;

  /// Commit button label for batch modify
  ///
  /// In en, this message translates to:
  /// **'Apply changes to {count} elements'**
  String architectBatchModifyApply(int count);

  /// Checkbox to replace raster/skin while keeping dimensions intact
  ///
  /// In en, this message translates to:
  /// **'Keep current dimensions (Skin only)'**
  String get architectSkinOnly;

  /// Description for skin only option
  ///
  /// In en, this message translates to:
  /// **'Applies new raster/skin without altering opening width, height, or sill'**
  String get architectSkinOnlyDesc;

  /// Label for selecting replacement raster or style
  ///
  /// In en, this message translates to:
  /// **'New raster / style'**
  String get architectTargetRasterStyle;

  /// Button to open fenestration editor for custom raster
  ///
  /// In en, this message translates to:
  /// **'Design custom raster...'**
  String get architectCreateCustomRaster;

  /// Section header for optional dimension changes
  ///
  /// In en, this message translates to:
  /// **'Change dimensions'**
  String get architectChangeDimensions;

  /// Checkbox for updating specification mark
  ///
  /// In en, this message translates to:
  /// **'Change specification mark'**
  String get architectChangeSpecId;

  /// Input field for new width
  ///
  /// In en, this message translates to:
  /// **'New width'**
  String get architectNewWidth;

  /// Input field for new height
  ///
  /// In en, this message translates to:
  /// **'New height'**
  String get architectNewHeight;

  /// Input field for new sill height
  ///
  /// In en, this message translates to:
  /// **'New sill height'**
  String get architectNewSillHeight;

  /// Input field for new spec ID mark
  ///
  /// In en, this message translates to:
  /// **'New mark (spec ID)'**
  String get architectNewSpecId;

  /// Button to select matching elements on active storey
  ///
  /// In en, this message translates to:
  /// **'Select on current storey'**
  String get architectSelectMatching;

  /// Button to switch storey and select matching items
  ///
  /// In en, this message translates to:
  /// **'Go to storey & select'**
  String get architectSwitchStoreyAndSelect;

  /// Filter operator for exact equality
  ///
  /// In en, this message translates to:
  /// **'Equal (=)'**
  String get architectOperatorExact;

  /// Filter operator for greater than
  ///
  /// In en, this message translates to:
  /// **'Greater (>)'**
  String get architectOperatorGreater;

  /// Filter operator for less than
  ///
  /// In en, this message translates to:
  /// **'Less (<)'**
  String get architectOperatorLess;

  /// Filter operator for any value
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get architectOperatorAny;

  /// Option to match any fenestration style
  ///
  /// In en, this message translates to:
  /// **'Any raster / style'**
  String get architectFilterAnyStyle;

  /// Snackbar notification after batch modification
  ///
  /// In en, this message translates to:
  /// **'Successfully modified {count} elements across {storeys, plural, one{1 storey} other{{storeys} storeys}}'**
  String architectBatchModifySuccess(int count, int storeys);

  /// Tooltip explaining dimension preservation on style change
  ///
  /// In en, this message translates to:
  /// **'Keep existing dimensions when changing style'**
  String get architectPreserveDimensionsTooltip;

  /// Menu action to copy elements across building storeys
  ///
  /// In en, this message translates to:
  /// **'Copy Elements by Storeys...'**
  String get architectCopyElementsByStorey;

  /// Selection action button to copy selected elements to other storeys
  ///
  /// In en, this message translates to:
  /// **'Copy to Storeys...'**
  String get architectCopyToStoreys;

  /// Tooltip for copying selected elements to other storeys
  ///
  /// In en, this message translates to:
  /// **'Copy selected elements to other building storeys'**
  String get architectCopyToStoreysTooltip;

  /// Menu action to open full storey manager
  ///
  /// In en, this message translates to:
  /// **'Storey Manager...'**
  String get architectManageStoreys;

  /// Title of the storeys management and copying screen
  ///
  /// In en, this message translates to:
  /// **'Building Storeys & Typical Floors'**
  String get architectStoreysScreenTitle;

  /// Header for source storey picker
  ///
  /// In en, this message translates to:
  /// **'Source Storey (Template)'**
  String get architectCopySourceStorey;

  /// Header for target storeys picker
  ///
  /// In en, this message translates to:
  /// **'Target Storeys'**
  String get architectCopyTargetStoreys;

  /// Option to copy all elements from source storey
  ///
  /// In en, this message translates to:
  /// **'Entire storey layout'**
  String get architectCopyAllStoreyElements;

  /// Option to copy only active selection
  ///
  /// In en, this message translates to:
  /// **'Selected elements only ({count})'**
  String architectCopySelectedOnly(int count);

  /// Title for copy mode selection
  ///
  /// In en, this message translates to:
  /// **'Transfer Mode'**
  String get architectCopyModeTitle;

  /// Mode to replace existing elements on target storeys
  ///
  /// In en, this message translates to:
  /// **'Replace existing'**
  String get architectCopyModeReplace;

  /// Explanation of replace mode
  ///
  /// In en, this message translates to:
  /// **'Clear existing elements of selected types on target storeys'**
  String get architectCopyModeReplaceHelp;

  /// Mode to append elements to target storeys
  ///
  /// In en, this message translates to:
  /// **'Append / Merge'**
  String get architectCopyModeMerge;

  /// Explanation of merge mode
  ///
  /// In en, this message translates to:
  /// **'Keep existing elements on target storeys and append new copies'**
  String get architectCopyModeMergeHelp;

  /// Checkbox to adapt wall heights based on target storey height
  ///
  /// In en, this message translates to:
  /// **'Adapt wall heights to target storey'**
  String get architectAdjustWallHeightsToStorey;

  /// Checkbox to shift elevation markers to target storey elevation
  ///
  /// In en, this message translates to:
  /// **'Recalculate elevation markers to target level'**
  String get architectAdjustElevationMarkers;

  /// Checkbox to maintain grouping on target storeys
  ///
  /// In en, this message translates to:
  /// **'Preserve element groups'**
  String get architectPreserveGroups;

  /// Quick select button for all storeys above active
  ///
  /// In en, this message translates to:
  /// **'All above current'**
  String get architectSelectAllAbove;

  /// Quick select button for all target storeys
  ///
  /// In en, this message translates to:
  /// **'All storeys'**
  String get architectSelectAllStoreys;

  /// Clear target storey selections
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get architectClearStoreySelection;

  /// Button to batch generate typical storeys
  ///
  /// In en, this message translates to:
  /// **'Generate Typical Storeys...'**
  String get architectBatchAddStoreys;

  /// Input for number of typical storeys to create
  ///
  /// In en, this message translates to:
  /// **'Number of storeys'**
  String get architectBatchAddCount;

  /// Input for storey floor-to-floor height
  ///
  /// In en, this message translates to:
  /// **'Storey height (m)'**
  String get architectBatchAddHeight;

  /// Input for storey name prefix
  ///
  /// In en, this message translates to:
  /// **'Name prefix'**
  String get architectBatchAddPrefix;

  /// Button to submit batch storey creation
  ///
  /// In en, this message translates to:
  /// **'Generate Storeys'**
  String get architectBatchAddButton;

  /// Primary button to trigger element copying
  ///
  /// In en, this message translates to:
  /// **'Copy Elements'**
  String get architectCopyElementsButton;

  /// Snackbar notification after copying elements
  ///
  /// In en, this message translates to:
  /// **'Successfully copied {count} elements across {storeys, plural, one{1 storey} other{{storeys} storeys}}'**
  String architectCopySuccess(int count, int storeys);

  /// Validation error when no target storey is selected
  ///
  /// In en, this message translates to:
  /// **'Please select at least one target storey'**
  String get architectNoTargetStoreysSelected;

  /// Validation error when no elements match criteria
  ///
  /// In en, this message translates to:
  /// **'No elements selected to copy'**
  String get architectNoElementsSelected;

  /// Category chip for walls, doors, and windows
  ///
  /// In en, this message translates to:
  /// **'Walls, Doors & Windows'**
  String get architectCategoryWalls;

  /// Category chip for columns
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get architectCategoryColumns;

  /// Category chip for beams
  ///
  /// In en, this message translates to:
  /// **'Beams'**
  String get architectCategoryBeams;

  /// Category chip for floor slabs
  ///
  /// In en, this message translates to:
  /// **'Slabs'**
  String get architectCategorySlabs;

  /// Category chip for rooms and apartment zones
  ///
  /// In en, this message translates to:
  /// **'Zones & Rooms'**
  String get architectCategoryZones;

  /// Category chip for stairs and floor slab openings
  ///
  /// In en, this message translates to:
  /// **'Stairs & Voids'**
  String get architectCategoryStairsOpenings;

  /// Category chip for dimension chains and elevation markers
  ///
  /// In en, this message translates to:
  /// **'Dimensions & Levels'**
  String get architectCategoryDimensions;

  /// Category chip for lines, hatches, and text annotations
  ///
  /// In en, this message translates to:
  /// **'2D CAD & Annotations'**
  String get architectCategoryDrafting2D;

  /// Category chip for component instances and floor drains
  ///
  /// In en, this message translates to:
  /// **'Components & Fixtures'**
  String get architectCategoryComponents;

  /// Category chip for roof planes
  ///
  /// In en, this message translates to:
  /// **'Roofs'**
  String get architectCategoryRoofs;

  /// Label for storey elevation
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get architectStoreyElevationLabel;

  /// Label for storey height
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get architectStoreyHeightLabel;

  /// Storey total element count
  ///
  /// In en, this message translates to:
  /// **'{count} elements'**
  String architectStoreyElementsCount(int count);

  /// Button to append a single storey above
  ///
  /// In en, this message translates to:
  /// **'Add storey above'**
  String get architectAddStoreyAbove;

  /// Confirmation message when deleting a storey
  ///
  /// In en, this message translates to:
  /// **'Delete storey {name}? All elements on it will be removed.'**
  String architectDeleteStoreyConfirm(String name);

  /// Badge indicating typical storey repetition
  ///
  /// In en, this message translates to:
  /// **'Typical Floor'**
  String get architectTypicalFloorBadge;

  /// Title for floor plan preview panel
  ///
  /// In en, this message translates to:
  /// **'Floor Plan Preview'**
  String get architectPlanPreviewTitle;

  /// Tab label for storey stack view
  ///
  /// In en, this message translates to:
  /// **'Storey Stack'**
  String get architectStoreyStackTab;

  /// Tab label for element copy view
  ///
  /// In en, this message translates to:
  /// **'Copy Elements'**
  String get architectCopyStoreyTab;

  /// Header for categories to transfer across storeys
  ///
  /// In en, this message translates to:
  /// **'Transfer Categories'**
  String get architectCopyCategoriesTitle;

  /// Placeholder shown in storey mini-map preview when storey has no elements
  ///
  /// In en, this message translates to:
  /// **'No elements drawn on this storey'**
  String get architectNoDrawnElements;

  /// Command icon label for CAD Underlay
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay (DXF/DWG)'**
  String get commandIconCadUnderlay;

  /// Command icon label for Raster Underlay
  ///
  /// In en, this message translates to:
  /// **'Raster Underlay (2-Point Calibration)'**
  String get commandIconRasterUnderlay;

  /// Tool category label for CAD and Raster underlays
  ///
  /// In en, this message translates to:
  /// **'Underlays'**
  String get architectToolCategoryUnderlays;

  /// Tool label for CAD DXF/DWG underlay
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay'**
  String get architectToolCadUnderlay;

  /// Tooltip for CAD Underlay tool
  ///
  /// In en, this message translates to:
  /// **'Import or link external DWG/DXF underlay with live auto-reload and geodetic contour detection'**
  String get architectToolCadUnderlayTooltip;

  /// Tool label for Raster Image/PDF underlay
  ///
  /// In en, this message translates to:
  /// **'Raster Underlay'**
  String get architectToolRasterUnderlay;

  /// Tooltip for Raster Underlay tool
  ///
  /// In en, this message translates to:
  /// **'Insert scanned image or PDF with opacity and 2-point scale calibration'**
  String get architectToolRasterUnderlayTooltip;

  /// Standard layer name for CAD Xref underlays
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay'**
  String get architectLayerCadUnderlay;

  /// Standard layer name for Raster underlays
  ///
  /// In en, this message translates to:
  /// **'Raster Underlay'**
  String get architectLayerRasterUnderlay;

  /// Standard layer name for Geodetic contours and elevations
  ///
  /// In en, this message translates to:
  /// **'Geodesy & Contours'**
  String get architectLayerGeodesyContours;

  /// Button to load CAD underlay
  ///
  /// In en, this message translates to:
  /// **'Load DWG/DXF'**
  String get architectCadUnderlayImport;

  /// Button to update or replace CAD underlay with another file
  ///
  /// In en, this message translates to:
  /// **'Update / Replace'**
  String get architectCadUnderlayReplace;

  /// Tooltip for replacing CAD underlay without shifting coordinates
  ///
  /// In en, this message translates to:
  /// **'Replace or update with another DWG/DXF file while preserving coordinate alignment'**
  String get architectCadUnderlayReplaceTooltip;

  /// Toggle for automatic reload when external file changes
  ///
  /// In en, this message translates to:
  /// **'Auto-reload'**
  String get architectCadUnderlayAutoReload;

  /// Tooltip for auto-reload toggle
  ///
  /// In en, this message translates to:
  /// **'Automatically reload underlay when the external file is modified'**
  String get architectCadUnderlayAutoReloadTooltip;

  /// Toggle to keep reference coordinate origin locked
  ///
  /// In en, this message translates to:
  /// **'Origin Locked'**
  String get architectCadUnderlayOriginLocked;

  /// Tooltip for origin lock toggle
  ///
  /// In en, this message translates to:
  /// **'Keep reference origin fixed when updating or replacing underlay so geometry never shifts'**
  String get architectCadUnderlayOriginLockedTooltip;

  /// Button to manually reload external CAD file
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get architectCadUnderlayReloadNow;

  /// Button to open DXF layers filter sheet
  ///
  /// In en, this message translates to:
  /// **'DXF Layers'**
  String get architectCadUnderlayLayersFilter;

  /// Button to run geodetic contour detection
  ///
  /// In en, this message translates to:
  /// **'Extract Contours'**
  String get architectCadUnderlayDetectGeodesy;

  /// Button to remove underlay from current storey
  ///
  /// In en, this message translates to:
  /// **'Remove Underlay'**
  String get architectCadUnderlayRemove;

  /// Snackbar notice when external CAD file changes and reloads
  ///
  /// In en, this message translates to:
  /// **'External CAD underlay updated automatically: {fileName}'**
  String architectCadUnderlayReloadedNotice(String fileName);

  /// Snackbar notice when CAD underlay is imported
  ///
  /// In en, this message translates to:
  /// **'CAD underlay loaded ({fileName})'**
  String architectCadUnderlayLoadedSuccess(String fileName);

  /// Snackbar notice when geodetic contours and points are extracted
  ///
  /// In en, this message translates to:
  /// **'Detected {crs}: extracted {contours} contours and {points} elevation points to layer G-TOPO'**
  String architectGeodesyDetectedNotice(String crs, int contours, int points);

  /// Snackbar notice when no contours are found
  ///
  /// In en, this message translates to:
  /// **'No geodetic contours or spot elevations detected in this file'**
  String get architectGeodesyNoContoursFound;

  /// Badge showing count of detected contours
  ///
  /// In en, this message translates to:
  /// **'G-TOPO: {contours} contours'**
  String architectGeodesyBadge(int contours);

  /// Button to push extracted geodetic elevations to 3D terrain
  ///
  /// In en, this message translates to:
  /// **'To 3D Terrain'**
  String get architectGeodesyApplyToTerrain;

  /// Snackbar notice after transferring points to 3D terrain
  ///
  /// In en, this message translates to:
  /// **'Transferred {count} elevation points to 3D Terrain'**
  String architectGeodesyAppliedToTerrainNotice(int count);

  /// Hint text when no CAD underlay is loaded on current storey
  ///
  /// In en, this message translates to:
  /// **'Load an external DWG/DXF as a read-only background underlay for this storey'**
  String get architectCadUnderlayEmptyHint;

  /// Button to import raster image or PDF underlay
  ///
  /// In en, this message translates to:
  /// **'Insert Image / PDF'**
  String get architectRasterUnderlayImport;

  /// Hint text when no raster underlay is on current storey
  ///
  /// In en, this message translates to:
  /// **'Insert a scanned survey, sketch, JPG/PNG or PDF and calibrate by 2 points'**
  String get architectRasterUnderlayEmptyHint;

  /// Button to start 2-point scale calibration
  ///
  /// In en, this message translates to:
  /// **'2-Point Calibrate'**
  String get architectRasterCalibrate2Pt;

  /// Instruction for first calibration point
  ///
  /// In en, this message translates to:
  /// **'Click Point 1 on the raster underlay'**
  String get architectRasterCalibrateStep1;

  /// Instruction for second calibration point
  ///
  /// In en, this message translates to:
  /// **'Click Point 2 on the raster underlay'**
  String get architectRasterCalibrateStep2;

  /// Button to cancel 2-point calibration
  ///
  /// In en, this message translates to:
  /// **'Cancel calibration'**
  String get architectRasterCalibrateCancel;

  /// Title of 2-point calibration dialog
  ///
  /// In en, this message translates to:
  /// **'2-Point Scale & Alignment Calibration'**
  String get architectRasterCalibrateDialogTitle;

  /// Input label for real distance in meters
  ///
  /// In en, this message translates to:
  /// **'Real distance between Point 1 and Point 2 (m)'**
  String get architectRasterCalibrateRealDistanceLabel;

  /// Info text showing measured distance before calibration
  ///
  /// In en, this message translates to:
  /// **'Current uncalibrated length: {distance} m'**
  String architectRasterCalibrateCurrentDistance(String distance);

  /// Label for orientation alignment option during calibration
  ///
  /// In en, this message translates to:
  /// **'Orientation / Deskew (Point 1 → Point 2)'**
  String get architectRasterAlignModeLabel;

  /// Option to keep existing image rotation
  ///
  /// In en, this message translates to:
  /// **'Keep current angle (scale only)'**
  String get architectRasterAlignKeepAngle;

  /// Option to rotate image so P1-P2 is horizontal
  ///
  /// In en, this message translates to:
  /// **'Align horizontally (0°)'**
  String get architectRasterAlignHorizontal;

  /// Option to rotate image so P1-P2 is vertical
  ///
  /// In en, this message translates to:
  /// **'Align vertically (90°)'**
  String get architectRasterAlignVertical;

  /// Button to apply 2-point calibration
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get architectRasterCalibrateApply;

  /// Snackbar notice after calibrating raster underlay
  ///
  /// In en, this message translates to:
  /// **'Raster underlay calibrated ({mmPerPixel} mm/px)'**
  String architectRasterCalibratedSuccess(String mmPerPixel);

  /// Label for underlay opacity slider
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get architectRasterOpacityLabel;

  /// Lock raster underlay position
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get architectRasterLockPosition;

  /// Unlock raster underlay position
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get architectRasterUnlockPosition;

  /// Reset raster underlay scale and rotation
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get architectRasterResetTransform;

  /// Dialog title for choosing PDF page
  ///
  /// In en, this message translates to:
  /// **'Select PDF Page for Underlay'**
  String get architectRasterSelectPdfPageTitle;

  /// Page indicator in PDF page selector
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String architectRasterPdfPageLabel(int page, int total);

  /// Button to confirm PDF page import
  ///
  /// In en, this message translates to:
  /// **'Import Page'**
  String get architectRasterImportPdfButton;

  /// Tooltip or header for underlay context options
  ///
  /// In en, this message translates to:
  /// **'Underlay Options'**
  String get architectUnderlayContextMenu;

  /// Action to edit underlay properties
  ///
  /// In en, this message translates to:
  /// **'Edit Properties'**
  String get architectUnderlayEdit;

  /// Action to adjust underlay scale or units
  ///
  /// In en, this message translates to:
  /// **'Scale & Units'**
  String get architectUnderlayScale;

  /// Action to configure underlay clipping mask
  ///
  /// In en, this message translates to:
  /// **'Mask / Crop'**
  String get architectUnderlayMask;

  /// Action to draw a rectangular mask
  ///
  /// In en, this message translates to:
  /// **'Rectangular Mask'**
  String get architectUnderlayMaskRect;

  /// Action to draw a polygonal mask
  ///
  /// In en, this message translates to:
  /// **'Polygonal Mask'**
  String get architectUnderlayMaskPolygon;

  /// Action to remove clipping mask
  ///
  /// In en, this message translates to:
  /// **'Clear Mask'**
  String get architectUnderlayMaskClear;

  /// Action to toggle clipping mask on or off
  ///
  /// In en, this message translates to:
  /// **'Toggle Mask'**
  String get architectUnderlayMaskToggle;

  /// Prompt for rectangular mask drafting
  ///
  /// In en, this message translates to:
  /// **'Drag across the underlay to define the rectangular crop area'**
  String get architectUnderlayMaskRectPrompt;

  /// Prompt for polygon mask drafting
  ///
  /// In en, this message translates to:
  /// **'Click points to define crop boundary polygon. Tap Finish to close.'**
  String get architectUnderlayMaskPolyPrompt;

  /// Button to commit drafted underlay mask
  ///
  /// In en, this message translates to:
  /// **'Finish Mask'**
  String get architectUnderlayMaskFinish;

  /// Button to abort underlay mask drafting
  ///
  /// In en, this message translates to:
  /// **'Cancel Mask'**
  String get architectUnderlayMaskCancel;

  /// Title of CAD underlay scale dialog
  ///
  /// In en, this message translates to:
  /// **'CAD Underlay Scale & Units'**
  String get architectUnderlayCadScaleTitle;

  /// Label for drawing units dropdown
  ///
  /// In en, this message translates to:
  /// **'Drawing units per meter'**
  String get architectUnderlayCadScaleUnitsLabel;

  /// Scale option for meters
  ///
  /// In en, this message translates to:
  /// **'Meters (1 unit = 1 m)'**
  String get architectUnderlayCadScaleMeters;

  /// Scale option for millimeters
  ///
  /// In en, this message translates to:
  /// **'Millimeters (1000 units = 1 m)'**
  String get architectUnderlayCadScaleMm;

  /// Scale option for centimeters
  ///
  /// In en, this message translates to:
  /// **'Centimeters (100 units = 1 m)'**
  String get architectUnderlayCadScaleCm;

  /// Scale option for inches
  ///
  /// In en, this message translates to:
  /// **'Inches (39.37 units = 1 m)'**
  String get architectUnderlayCadScaleInches;

  /// Option for custom scale ratio
  ///
  /// In en, this message translates to:
  /// **'Custom Scale Ratio'**
  String get architectUnderlayCadScaleCustom;

  /// Button to calibrate CAD scale by two points
  ///
  /// In en, this message translates to:
  /// **'2-Point CAD Calibrate'**
  String get architectUnderlayCadScale2Pt;

  /// Title for underlay properties dialog
  ///
  /// In en, this message translates to:
  /// **'Underlay Settings'**
  String get architectUnderlayEditDialogTitle;

  /// Error message when underlay loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load underlay: {error}'**
  String architectUnderlayLoadError(String error);

  /// Action to reposition CAD underlay
  ///
  /// In en, this message translates to:
  /// **'Reposition'**
  String get architectUnderlayReposition;

  /// Tooltip for repositioning CAD underlay
  ///
  /// In en, this message translates to:
  /// **'Reposition CAD underlay by picking a new control point'**
  String get architectUnderlayRepositionTooltip;

  /// Title of CAD control point picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select CAD Control Point'**
  String get architectUnderlayPickPointTitle;

  /// Instruction for selecting a CAD control point
  ///
  /// In en, this message translates to:
  /// **'Pan, zoom, and select an axis intersection, corner, or reference point'**
  String get architectUnderlayPickPointInstruction;

  /// Button to confirm selected CAD control point
  ///
  /// In en, this message translates to:
  /// **'Confirm Control Point'**
  String get architectUnderlayPickPointConfirm;

  /// Snap type label for intersection
  ///
  /// In en, this message translates to:
  /// **'Intersection'**
  String get architectUnderlaySnapIntersection;

  /// Snap type label for endpoint
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get architectUnderlaySnapEndpoint;

  /// Snap type label for midpoint
  ///
  /// In en, this message translates to:
  /// **'Midpoint'**
  String get architectUnderlaySnapMidpoint;

  /// Snap type label for center
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get architectUnderlaySnapCenter;

  /// Snap type label for point on entity
  ///
  /// In en, this message translates to:
  /// **'On Entity'**
  String get architectUnderlaySnapNearest;

  /// Preset button to select CAD origin 0,0
  ///
  /// In en, this message translates to:
  /// **'Origin (0,0)'**
  String get architectUnderlayPresetOrigin;

  /// Preset button to select CAD drawing center
  ///
  /// In en, this message translates to:
  /// **'Drawing Center'**
  String get architectUnderlayPresetCenter;

  /// HUD instruction prompt for placing CAD underlay on canvas
  ///
  /// In en, this message translates to:
  /// **'Click on drawing to place the CAD underlay'**
  String get architectUnderlayInsertionPrompt;

  /// Tooltip or label for placing CAD underlay
  ///
  /// In en, this message translates to:
  /// **'Place Underlay'**
  String get architectUnderlayInsertionConfirm;

  /// Tooltip or label for cancelling CAD underlay placement
  ///
  /// In en, this message translates to:
  /// **'Cancel Placement'**
  String get architectUnderlayInsertionCancel;

  /// Snackbar message when CAD underlay is positioned
  ///
  /// In en, this message translates to:
  /// **'CAD underlay positioned successfully'**
  String get architectUnderlayPlacedSuccess;

  /// Action to drag and move underlay with snapping
  ///
  /// In en, this message translates to:
  /// **'Move with Snap'**
  String get architectUnderlayDrag;

  /// Tooltip for underlay snap drag action
  ///
  /// In en, this message translates to:
  /// **'Move underlay by picking a base point and snapping to drawing'**
  String get architectUnderlayDragTooltip;

  /// Prompt to select base point on underlay
  ///
  /// In en, this message translates to:
  /// **'Select base reference point on underlay'**
  String get architectUnderlayPickBasePoint;

  /// Prompt to snap underlay to target position
  ///
  /// In en, this message translates to:
  /// **'Snap to drawing location to position underlay'**
  String get architectUnderlayPickTargetPoint;

  /// Snackbar message when underlay snap drag succeeds
  ///
  /// In en, this message translates to:
  /// **'Underlay repositioned successfully'**
  String get architectUnderlayDragSuccess;

  /// Candidate picker label for underlays
  ///
  /// In en, this message translates to:
  /// **'Underlay: {fileName}'**
  String architectUnderlayCandidate(String fileName);

  /// Label for underlay base reference point
  ///
  /// In en, this message translates to:
  /// **'Base Point'**
  String get architectUnderlayBasePoint;

  /// HUD status text when underlay is selected
  ///
  /// In en, this message translates to:
  /// **'Underlay selected'**
  String get architectUnderlaySelected;

  /// Action to position underlay on workspace
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get architectUnderlayPositionAction;

  /// Tooltip for positioning underlay
  ///
  /// In en, this message translates to:
  /// **'Position underlay by selecting a reference point and moving to location'**
  String get architectUnderlayPositionTooltip;

  /// Action to hide underlay from workspace
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get architectUnderlayHide;

  /// Tooltip for hiding underlay
  ///
  /// In en, this message translates to:
  /// **'Hide this underlay from workspace'**
  String get architectUnderlayHideTooltip;

  /// Snackbar notice when underlay is hidden
  ///
  /// In en, this message translates to:
  /// **'Underlay hidden'**
  String get architectUnderlayHiddenNotice;

  /// Loading message while underlay is converting
  ///
  /// In en, this message translates to:
  /// **'Converting & loading underlay...'**
  String get architectUnderlayConverting;

  /// No description provided for @commandIconPathway.
  ///
  /// In en, this message translates to:
  /// **'Pathway with curb'**
  String get commandIconPathway;

  /// No description provided for @commandIconVegetation.
  ///
  /// In en, this message translates to:
  /// **'Vegetation & planting'**
  String get commandIconVegetation;

  /// No description provided for @architectCategoryLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get architectCategoryLandscape;

  /// No description provided for @architectToolTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get architectToolTerrain;

  /// No description provided for @architectToolPathway.
  ///
  /// In en, this message translates to:
  /// **'Pathway'**
  String get architectToolPathway;

  /// No description provided for @architectToolVegetation.
  ///
  /// In en, this message translates to:
  /// **'Planting'**
  String get architectToolVegetation;

  /// No description provided for @architectToolSiteFence.
  ///
  /// In en, this message translates to:
  /// **'Site fence'**
  String get architectToolSiteFence;

  /// No description provided for @architectTerrainStateExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get architectTerrainStateExisting;

  /// No description provided for @architectTerrainStateProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get architectTerrainStateProposed;

  /// No description provided for @architectTerrainStateExistingFull.
  ///
  /// In en, this message translates to:
  /// **'Existing terrain'**
  String get architectTerrainStateExistingFull;

  /// No description provided for @architectTerrainStateProposedFull.
  ///
  /// In en, this message translates to:
  /// **'Proposed terrain'**
  String get architectTerrainStateProposedFull;

  /// No description provided for @architectTerrainModeBoundary.
  ///
  /// In en, this message translates to:
  /// **'Boundary'**
  String get architectTerrainModeBoundary;

  /// No description provided for @architectTerrainModeContour.
  ///
  /// In en, this message translates to:
  /// **'Contour'**
  String get architectTerrainModeContour;

  /// No description provided for @architectTerrainModeSpot.
  ///
  /// In en, this message translates to:
  /// **'Spot Z'**
  String get architectTerrainModeSpot;

  /// No description provided for @architectTerrainModePad.
  ///
  /// In en, this message translates to:
  /// **'Flat pad'**
  String get architectTerrainModePad;

  /// No description provided for @architectTerrainFromGeodesy.
  ///
  /// In en, this message translates to:
  /// **'From G-TOPO'**
  String get architectTerrainFromGeodesy;

  /// No description provided for @architectTerrainElevationLabel.
  ///
  /// In en, this message translates to:
  /// **'Z='**
  String get architectTerrainElevationLabel;

  /// No description provided for @architectTerrainSyncedFromGeodesy.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} geodetic contours & points to Existing Terrain'**
  String architectTerrainSyncedFromGeodesy(int count);

  /// No description provided for @architectPathwayWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get architectPathwayWidth;

  /// No description provided for @architectPathwayCurb.
  ///
  /// In en, this message translates to:
  /// **'Curb'**
  String get architectPathwayCurb;

  /// No description provided for @architectPathwayCurbWidth.
  ///
  /// In en, this message translates to:
  /// **'Curb W'**
  String get architectPathwayCurbWidth;

  /// No description provided for @architectPathwayCurbBoth.
  ///
  /// In en, this message translates to:
  /// **'Both curbs'**
  String get architectPathwayCurbBoth;

  /// No description provided for @architectPathwayCurbLeft.
  ///
  /// In en, this message translates to:
  /// **'Left curb'**
  String get architectPathwayCurbLeft;

  /// No description provided for @architectPathwayCurbRight.
  ///
  /// In en, this message translates to:
  /// **'Right curb'**
  String get architectPathwayCurbRight;

  /// No description provided for @architectPathwayCurbNone.
  ///
  /// In en, this message translates to:
  /// **'No curb'**
  String get architectPathwayCurbNone;

  /// No description provided for @architectPathwayMatStoneSlabs.
  ///
  /// In en, this message translates to:
  /// **'Stone slabs'**
  String get architectPathwayMatStoneSlabs;

  /// No description provided for @architectPathwayMatCobblePavers.
  ///
  /// In en, this message translates to:
  /// **'Cobble pavers'**
  String get architectPathwayMatCobblePavers;

  /// No description provided for @architectPathwayMatTimberDecking.
  ///
  /// In en, this message translates to:
  /// **'Timber decking'**
  String get architectPathwayMatTimberDecking;

  /// No description provided for @architectPathwayMatGravel.
  ///
  /// In en, this message translates to:
  /// **'Crushed gravel'**
  String get architectPathwayMatGravel;

  /// No description provided for @architectPathwayMatAsphalt.
  ///
  /// In en, this message translates to:
  /// **'Asphalt'**
  String get architectPathwayMatAsphalt;

  /// No description provided for @architectPathwayMatGrassGrid.
  ///
  /// In en, this message translates to:
  /// **'Grass pavers'**
  String get architectPathwayMatGrassGrid;

  /// No description provided for @architectPathwayClosedPad.
  ///
  /// In en, this message translates to:
  /// **'Plaza'**
  String get architectPathwayClosedPad;

  /// No description provided for @architectPlantDeciduousCanopy.
  ///
  /// In en, this message translates to:
  /// **'Deciduous tree (branched)'**
  String get architectPlantDeciduousCanopy;

  /// No description provided for @architectPlantDeciduousMinimal.
  ///
  /// In en, this message translates to:
  /// **'Deciduous tree (minimal)'**
  String get architectPlantDeciduousMinimal;

  /// No description provided for @architectPlantConiferPine.
  ///
  /// In en, this message translates to:
  /// **'Conifer / Pine / Spruce'**
  String get architectPlantConiferPine;

  /// No description provided for @architectPlantColumnarCypress.
  ///
  /// In en, this message translates to:
  /// **'Columnar Thuja / Cypress'**
  String get architectPlantColumnarCypress;

  /// No description provided for @architectPlantOrnamentalPalm.
  ///
  /// In en, this message translates to:
  /// **'Ornamental / Palm'**
  String get architectPlantOrnamentalPalm;

  /// No description provided for @architectPlantShrubCluster.
  ///
  /// In en, this message translates to:
  /// **'Shrub cluster'**
  String get architectPlantShrubCluster;

  /// No description provided for @architectPlantTrimmedHedge.
  ///
  /// In en, this message translates to:
  /// **'Trimmed hedge'**
  String get architectPlantTrimmedHedge;

  /// No description provided for @architectVegetationModeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get architectVegetationModeSingle;

  /// No description provided for @architectVegetationModeRow.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get architectVegetationModeRow;

  /// No description provided for @architectVegetationModeHedge.
  ///
  /// In en, this message translates to:
  /// **'Hedge'**
  String get architectVegetationModeHedge;

  /// No description provided for @architectVegetationCrownDiameter.
  ///
  /// In en, this message translates to:
  /// **'D='**
  String get architectVegetationCrownDiameter;

  /// No description provided for @architectVegetationHeight.
  ///
  /// In en, this message translates to:
  /// **'H='**
  String get architectVegetationHeight;

  /// No description provided for @architectVegetationRowSpacing.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get architectVegetationRowSpacing;

  /// No description provided for @architectFencePresetPiersAndSlats.
  ///
  /// In en, this message translates to:
  /// **'Piers + horizontal boards'**
  String get architectFencePresetPiersAndSlats;

  /// No description provided for @architectFencePresetGabionFence.
  ///
  /// In en, this message translates to:
  /// **'Gabion fence'**
  String get architectFencePresetGabionFence;

  /// No description provided for @architectFencePresetGabionRetaining.
  ///
  /// In en, this message translates to:
  /// **'Gabion retaining wall'**
  String get architectFencePresetGabionRetaining;

  /// No description provided for @architectFencePresetModernLouvers.
  ///
  /// In en, this message translates to:
  /// **'Modern louver fence'**
  String get architectFencePresetModernLouvers;

  /// No description provided for @architectFencePresetClassicIron.
  ///
  /// In en, this message translates to:
  /// **'Classic wrought iron + piers'**
  String get architectFencePresetClassicIron;

  /// No description provided for @architectFencePresetRcRetaining.
  ///
  /// In en, this message translates to:
  /// **'RC retaining wall'**
  String get architectFencePresetRcRetaining;

  /// No description provided for @architectFenceHeight.
  ///
  /// In en, this message translates to:
  /// **'H='**
  String get architectFenceHeight;

  /// No description provided for @architectFenceThickness.
  ///
  /// In en, this message translates to:
  /// **'B='**
  String get architectFenceThickness;

  /// No description provided for @architectFencePierSpacing.
  ///
  /// In en, this message translates to:
  /// **'Span'**
  String get architectFencePierSpacing;

  /// No description provided for @architectLayerTerrainExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing Terrain'**
  String get architectLayerTerrainExisting;

  /// No description provided for @architectLayerTerrainProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed Terrain'**
  String get architectLayerTerrainProposed;

  /// No description provided for @architectLayerPathways.
  ///
  /// In en, this message translates to:
  /// **'Pathways & Curbs'**
  String get architectLayerPathways;

  /// No description provided for @architectLayerVegetation.
  ///
  /// In en, this message translates to:
  /// **'Vegetation & Site'**
  String get architectLayerVegetation;

  /// No description provided for @architectToolContour.
  ///
  /// In en, this message translates to:
  /// **'Contours'**
  String get architectToolContour;

  /// No description provided for @architectTerrainModeHole.
  ///
  /// In en, this message translates to:
  /// **'Hole'**
  String get architectTerrainModeHole;

  /// No description provided for @architectTerrainDatum.
  ///
  /// In en, this message translates to:
  /// **'Datum ±0.00'**
  String get architectTerrainDatum;

  /// No description provided for @architectTerrainDatumDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Geodetic Datum for ±0.00 Level'**
  String get architectTerrainDatumDialogTitle;

  /// No description provided for @architectTerrainAbsoluteElevation.
  ///
  /// In en, this message translates to:
  /// **'Absolute elevation'**
  String get architectTerrainAbsoluteElevation;

  /// No description provided for @architectTerrainRelativeElevation.
  ///
  /// In en, this message translates to:
  /// **'Relative elevation'**
  String get architectTerrainRelativeElevation;

  /// No description provided for @architectPlantArtisticLowPoly.
  ///
  /// In en, this message translates to:
  /// **'Artistic Low-Poly tree'**
  String get architectPlantArtisticLowPoly;

  /// No description provided for @architectTerrainContourMajor.
  ///
  /// In en, this message translates to:
  /// **'Major contour'**
  String get architectTerrainContourMajor;

  /// No description provided for @architectTerrainContourClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed loop'**
  String get architectTerrainContourClosed;

  /// No description provided for @architectToolStreet.
  ///
  /// In en, this message translates to:
  /// **'Street / Road'**
  String get architectToolStreet;

  /// No description provided for @architectStreetRoadWidth.
  ///
  /// In en, this message translates to:
  /// **'Carriageway'**
  String get architectStreetRoadWidth;

  /// No description provided for @architectStreetSidewalkLeft.
  ///
  /// In en, this message translates to:
  /// **'Left sidewalk'**
  String get architectStreetSidewalkLeft;

  /// No description provided for @architectStreetSidewalkRight.
  ///
  /// In en, this message translates to:
  /// **'Right sidewalk'**
  String get architectStreetSidewalkRight;

  /// No description provided for @architectStreetMarkings.
  ///
  /// In en, this message translates to:
  /// **'Markings'**
  String get architectStreetMarkings;

  /// No description provided for @architectStreetMarkingDashed.
  ///
  /// In en, this message translates to:
  /// **'Dashed'**
  String get architectStreetMarkingDashed;

  /// No description provided for @architectStreetMarkingSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get architectStreetMarkingSolid;

  /// No description provided for @architectStreetMarkingDoubleSolid.
  ///
  /// In en, this message translates to:
  /// **'Double solid'**
  String get architectStreetMarkingDoubleSolid;

  /// No description provided for @architectStreetMarkingNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get architectStreetMarkingNone;

  /// No description provided for @architectStreetCurb.
  ///
  /// In en, this message translates to:
  /// **'Curb'**
  String get architectStreetCurb;

  /// No description provided for @architectLayerStreets.
  ///
  /// In en, this message translates to:
  /// **'Streets & Sidewalks'**
  String get architectLayerStreets;

  /// Tab title for All-in-One file viewer
  ///
  /// In en, this message translates to:
  /// **'AIO Viewer'**
  String get moduleAioViewer;

  /// Tab title for Architect Studio module
  ///
  /// In en, this message translates to:
  /// **'Architect Studio'**
  String get moduleArchitectStudio;

  /// Tab title for Structural / Construction BIM module
  ///
  /// In en, this message translates to:
  /// **'Construction BIM'**
  String get moduleStructuralBim;

  /// Button to open blank architectural workspace
  ///
  /// In en, this message translates to:
  /// **'Blank Canvas'**
  String get architectBlankWorkspace;

  /// Button to create new structural project
  ///
  /// In en, this message translates to:
  /// **'New Structural Project'**
  String get structuralNewProject;

  /// Title for architectural projects list
  ///
  /// In en, this message translates to:
  /// **'Architectural Projects'**
  String get architectProjectsTitle;

  /// Title for structural projects list
  ///
  /// In en, this message translates to:
  /// **'Structural Projects'**
  String get structuralProjectsTitle;

  /// Button in architect wizard to attach an underlay/overlay
  ///
  /// In en, this message translates to:
  /// **'Add CAD Overlay'**
  String get architectWizardAddOverlay;

  /// Button in architect wizard to replace an underlay/overlay
  ///
  /// In en, this message translates to:
  /// **'Change Overlay'**
  String get architectWizardChangeOverlay;

  /// Button in architect wizard to remove an underlay/overlay
  ///
  /// In en, this message translates to:
  /// **'Remove Overlay'**
  String get architectWizardRemoveOverlay;

  /// Label for storey CAD overlay
  ///
  /// In en, this message translates to:
  /// **'CAD Overlay'**
  String get architectWizardStoreyOverlay;

  /// Empty state description for architectural studio
  ///
  /// In en, this message translates to:
  /// **'No architectural projects yet. Create a new project or start with a blank drawing.'**
  String get architectNoProjects;

  /// Empty state description for structural studio
  ///
  /// In en, this message translates to:
  /// **'No structural projects yet. Create a new project to start structural and seismic modeling.'**
  String get structuralNoProjects;

  /// Action to continue line/polyline/spline drafting from the last point
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get architectLineContinue;

  /// Tooltip for continue drafting action
  ///
  /// In en, this message translates to:
  /// **'Continue drafting from the end point'**
  String get architectLineContinueTooltip;

  /// Action to curve a straight wall into an arc
  ///
  /// In en, this message translates to:
  /// **'Curve Wall'**
  String get architectWallCurve;

  /// Tooltip for curving wall
  ///
  /// In en, this message translates to:
  /// **'Convert straight wall into an arc wall'**
  String get architectWallCurveTooltip;

  /// Action to curve a straight CAD line into an arc
  ///
  /// In en, this message translates to:
  /// **'Curve Line'**
  String get architectLineCurve;

  /// Action to curve a polyline segment into an arc
  ///
  /// In en, this message translates to:
  /// **'Curve Segment'**
  String get architectPolylineCurveSegment;

  /// Action to close a spline curve
  ///
  /// In en, this message translates to:
  /// **'Close Spline'**
  String get architectSplineClose;

  /// Action to open a closed spline curve
  ///
  /// In en, this message translates to:
  /// **'Open Spline'**
  String get architectSplineOpen;

  /// Prompt to select second wall or line for chamfer/fillet
  ///
  /// In en, this message translates to:
  /// **'Select second element for fillet / chamfer'**
  String get architectChamferFilletSelectSecond;
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
