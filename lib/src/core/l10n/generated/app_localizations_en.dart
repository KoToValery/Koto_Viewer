// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KoToViewer';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get search => 'Search';

  @override
  String get share => 'Share';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get clear => 'Clear';

  @override
  String get error => 'Error';

  @override
  String get toggleTheme => 'Toggle Theme';

  @override
  String get about => 'About';

  @override
  String get supportDeveloper => 'Support Developer';

  @override
  String get coordinateSettings => 'Coordinate System Settings';

  @override
  String get homeBannerTitle => 'Open Drawings, Models & Documents';

  @override
  String get browseFiles => 'Browse Files';

  @override
  String get recentFiles => 'Recent Files';

  @override
  String get customFolder => 'Custom Folder';

  @override
  String get addFolder => 'Add Folder';

  @override
  String get noFilesFound => 'No files found';

  @override
  String get searchFilesHint => 'Search files...';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortByDate => 'Date Modified';

  @override
  String get sortByName => 'File Name';

  @override
  String get categories => 'Categories';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryCad2d => '2D CAD';

  @override
  String get categoryCad3d => '3D Models';

  @override
  String get categoryPcb => 'PCB & Hardware';

  @override
  String get categoryRoutes => 'Routes & Maps';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get loadingFile => 'Loading file...';

  @override
  String get loadingPdf => 'Loading PDF document...';

  @override
  String get loadingPresentation => 'Loading presentation...';

  @override
  String get loadingCad => 'Loading CAD drawing...';

  @override
  String get convertingDwg => 'Converting & loading DWG...';

  @override
  String get loadingWordDoc => 'Loading Word document...';

  @override
  String get loadingSpreadsheet => 'Loading spreadsheet...';

  @override
  String get loading3dModel => 'Loading 3D model...';

  @override
  String get loadingEbook => 'Loading e-book...';

  @override
  String get loadingEbookFb2 => 'Loading book (FB2)...';

  @override
  String get loadingComic => 'Loading comic book...';

  @override
  String get loadingDicom => 'Loading DICOM study...';

  @override
  String get statusPreparingPages => 'Preparing and analyzing pages...';

  @override
  String get statusScanningSeries => 'Scanning series, slices & metadata...';

  @override
  String get statusTriangulatingMesh =>
      'Triangulating and building polygon mesh...';

  @override
  String get statusIndexingWorksheet =>
      'Indexing worksheets, cells, and formulas...';

  @override
  String get statusDecodingEbook => 'Decoding text, chapters, and content...';

  @override
  String get statusAnalyzingCad =>
      'Analyzing CAD layers, blocks, and geometry...';

  @override
  String get statusParsingWord => 'Parsing pages, formatting, and tables...';

  @override
  String get statusOpeningFile => 'Opening file...';

  @override
  String get statusExtractingStructure => 'Extracting archive structure...';

  @override
  String statusExtractingPage(int current, int total) {
    return 'Extracting page $current of $total...';
  }

  @override
  String get statusFinalizingPages => 'Finalizing pages...';

  @override
  String get statusIndexingPages => 'Indexing pages...';

  @override
  String statusReadingFile(String sizeMb) {
    return 'Reading file ($sizeMb MB)...';
  }

  @override
  String get fitWidth => 'Fit Width';

  @override
  String get fitPage => 'Fit Page';

  @override
  String get fitHeight => 'Fit Height';

  @override
  String get jumpToPage => 'Jump to Page';

  @override
  String get firstPage => 'First Page';

  @override
  String get lastPage => 'Last Page';

  @override
  String get previousPage => 'Previous Page';

  @override
  String get nextPage => 'Next Page';

  @override
  String pageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String enterPageNumber(int total) {
    return 'Enter page number (1 - $total)';
  }

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get resetZoom => 'Reset Zoom';

  @override
  String get rotate => 'Rotate';

  @override
  String get reflowMode => 'Reading Mode (Reflow)';

  @override
  String get outline => 'Outline';

  @override
  String get thumbnails => 'Thumbnails';

  @override
  String get layers => 'Layers';

  @override
  String get displaySettings => 'Display Settings';

  @override
  String get coordinateSystem => 'Coordinate System';

  @override
  String get exportDxf => 'Export DXF';

  @override
  String get measure => 'Measure';

  @override
  String get annotations => 'Annotations';

  @override
  String get wireframe => 'Wireframe';

  @override
  String get shaded => 'Shaded';

  @override
  String get resetView => 'Reset View';

  @override
  String get rasterPreview => 'Raster Preview (Embedded)';

  @override
  String get previewOnly => 'Preview-only';

  @override
  String get encoding => 'Encoding';

  @override
  String get wrapLines => 'Wrap Lines';

  @override
  String get fontSize => 'Font Size';

  @override
  String get lineSpacing => 'Line Spacing';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get theme => 'Theme';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String get sheet => 'Sheet';

  @override
  String get columns => 'Columns';

  @override
  String get rows => 'Rows';

  @override
  String get windowLevel => 'Window / Level';

  @override
  String get invert => 'Invert';

  @override
  String get panZoom => 'Pan / Zoom';

  @override
  String resumedAtPage(int page, int total) {
    return 'Resumed at Page $page of $total';
  }

  @override
  String get fileNotFoundOrInaccessible =>
      'File not found or cannot be accessed.';

  @override
  String get comicRar5NotSupported =>
      'This CBR file is compressed using RAR5, which is not supported by the built-in decompressor. Please convert to .cbz (ZIP) for full compatibility.';

  @override
  String get comicRarNotSupported =>
      'This CBR file uses RAR compression, which is not supported by the built-in decompressor. Please convert to .cbz (ZIP) format.';

  @override
  String get comicArchiveCorrupted =>
      'Comic book archive is corrupted or unreadable.';

  @override
  String unsupportedFileFormat(String name) {
    return 'Unsupported file format: $name';
  }

  @override
  String get convertingDwgTitle => 'Converting DWG...';

  @override
  String get convertingDwgMessage => 'Converting DWG to DXF for viewing';

  @override
  String get convertingPresentationTitle => 'Converting Presentation...';

  @override
  String get convertingPresentationMessage =>
      'Converting presentation to PDF for viewing';

  @override
  String errorLoadingSpreadsheet(String error) {
    return 'Error loading Excel file: $error';
  }

  @override
  String errorLoadingMarkdown(String error) {
    return 'Error loading markdown: $error';
  }

  @override
  String errorReadingWordDocument(String error) {
    return 'Error reading Word document: $error';
  }

  @override
  String errorReadingTextFile(String error) {
    return 'Error reading text file: $error';
  }

  @override
  String get resumedReadingPosition => 'Resumed reading position';

  @override
  String get woffNotSupported =>
      'WOFF/WOFF2 preview is not supported. Please convert to TTF or OTF first.';

  @override
  String errorLoading3dModel(String error) {
    return 'Error loading 3D model: $error';
  }

  @override
  String get failedToParse3dMesh => 'Failed to parse 3D mesh.';

  @override
  String get retry => 'Retry';

  @override
  String get bimStoreysAndCategories => 'BIM Storeys & Categories';

  @override
  String get properties3d => '3D Properties';

  @override
  String get dragMode => 'Drag / Pan';

  @override
  String get orbitMode => 'Rotate / Orbit';

  @override
  String get dragModelTooltip => 'Drag to move model';

  @override
  String get rotateModelTooltip => 'Drag to rotate model';

  @override
  String get dragModeActive => 'Drag Mode Active';

  @override
  String errorLoadingDxf(String error) {
    return 'Error opening DXF file: $error';
  }

  @override
  String failedToSaveDxf(String error) {
    return 'Failed to save DXF: $error';
  }

  @override
  String savedDxf(String name) {
    return 'Saved DXF: $name';
  }

  @override
  String errorImportingDxf(String error) {
    return 'Error importing DXF: $error';
  }

  @override
  String importedDxfSuccess(int count, String name) {
    return 'Successfully imported $count entities from $name';
  }

  @override
  String get fitScreen => 'Fit Screen';

  @override
  String printPreviewUnavailable(String error) {
    return 'Print preview unavailable: $error';
  }

  @override
  String errorReadingHpgl(String error) {
    return 'Error reading HPGL plotter file: $error';
  }

  @override
  String errorReadingPcb(String error) {
    return 'Error reading PCB project: $error';
  }

  @override
  String errorReadingCdr(String error) {
    return 'Error reading CorelDRAW file: $error';
  }

  @override
  String couldNotExportPng(String error) {
    return 'Could not export PNG: $error';
  }

  @override
  String printError(String error) {
    return 'Print error: $error';
  }

  @override
  String errorReadingEps(String error) {
    return 'Error reading EPS file: $error';
  }

  @override
  String errorLoadingSvg(String error) {
    return 'Error loading SVG: $error';
  }

  @override
  String errorLoadingRoute(String error) {
    return 'Could not load route file: $error';
  }

  @override
  String centeredOnWaypoint(String name) {
    return 'Centered on: $name';
  }

  @override
  String dicomParseError(String error) {
    return 'DICOM Parse Error: $error';
  }

  @override
  String errorLoadingDicom(String error) {
    return 'Error loading DICOM study: $error';
  }

  @override
  String errorLoadingEbook(String error) {
    return 'Error loading e-book: $error';
  }

  @override
  String get couldNotDecodePsd => 'Could not decode PSD composite image.';

  @override
  String errorPickingFolder(String error) {
    return 'Error picking folder: $error';
  }

  @override
  String get pleaseSelectSupportedFile =>
      'Please select a supported CAD, PCB, 3D, Vector, or Document file.';

  @override
  String couldNotOpenFilePicker(String error) {
    return 'Could not open file picker: $error';
  }

  @override
  String errorSharingFile(String error) {
    return 'Error sharing file: $error';
  }

  @override
  String get singlePageModeTooltip => 'Single Page Mode (Tap for Continuous)';

  @override
  String get continuousModeTooltip => 'Continuous Mode (Tap for Single Page)';

  @override
  String get singlePageLabel => 'Single Page';

  @override
  String get continuousLabel => 'Continuous';

  @override
  String get viewMode => 'View Mode:';

  @override
  String get singlePageSwipe => 'Single Page (Swipe)';

  @override
  String get continuousScroll => 'Continuous Scroll';

  @override
  String archiveFilesCount(int count) {
    return 'Archive Files ($count)';
  }

  @override
  String get openArchiveFile => 'Open';

  @override
  String get unsupportedArchiveFormat =>
      'Direct preview is not supported for this file format.';

  @override
  String extractingFile(String name) {
    return 'Opening $name...';
  }
}
