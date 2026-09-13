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

  /// Documents category
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get categoryDocuments;

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
