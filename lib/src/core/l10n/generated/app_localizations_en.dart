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
  String get recentlyOpenedSubtitle => 'Recently opened files';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get categoryMedical => 'Medical (DICOM)';

  @override
  String get categoryImages => 'Images';

  @override
  String get categoryVideo => 'Video';

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
  String get comicAutoplay => 'Autoplay';

  @override
  String get comicAutoplayStart => 'Start Autoplay';

  @override
  String get comicAutoplayPause => 'Pause Autoplay';

  @override
  String get comicAutoplayResume => 'Resume Autoplay';

  @override
  String get comicAutoplayStop => 'Stop Autoplay';

  @override
  String get comicAutoplaySettings => 'Autoplay Settings';

  @override
  String get comicAutoplayPageDuration => 'Page Duration';

  @override
  String get comicAutoplayScrollSpeed => 'Webtoon Scroll Speed';

  @override
  String comicAutoplaySeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String comicAutoplaySpeedPx(int speed) {
    return '$speed px/s';
  }

  @override
  String get comicAutoplayLoop => 'Loop from Beginning';

  @override
  String get comicAutoplayPauseOnZoom => 'Pause when Zoomed';

  @override
  String get comicAutoplayEndReached => 'Reached the end of the comic.';

  @override
  String get comicAutoplayPausedForZoom => 'Paused (Zoomed)';

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
  String get flyMode => 'Walk / Fly';

  @override
  String get flyModeTooltip => 'Free fly & walkthrough mode (ArchiCAD / BIMx)';

  @override
  String get flyModeActive => 'Walk / Fly Mode (BIMx)';

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
  String get dicomReferenceLines => 'Cross-Reference Lines';

  @override
  String get dicomLayout => 'Layout';

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

  @override
  String get videoViewerTitle => 'Video Player';

  @override
  String get videoLoopOn => 'Loop enabled';

  @override
  String get videoLoopOff => 'Loop disabled';

  @override
  String get presentationMode => 'Start Presentation';

  @override
  String get nextProjectItem => 'Next File';

  @override
  String get prevProjectItem => 'Previous File';

  @override
  String get projectOverview => 'Project Assets';

  @override
  String get uploadViaWifi => 'Upload via Wi-Fi';

  @override
  String get receiveFiles => 'Receive Files';

  @override
  String get receiveFilesSubtitle =>
      'Upload files from browser over local network';

  @override
  String get receivedFiles => 'Received Files';

  @override
  String get openFile => 'Open';

  @override
  String get hideFromPresentation => 'Hide from presentation';

  @override
  String get includeInPresentation => 'Include in presentation';

  @override
  String get hiddenInPresentation => 'Hidden';

  @override
  String fileHiddenNotification(String name) {
    return '\"$name\" hidden from presentation';
  }

  @override
  String fileIncludedNotification(String name) {
    return '\"$name\" included in presentation';
  }

  @override
  String get unhideAllFiles => 'Include all files';

  @override
  String get allFilesIncludedNotification =>
      'All files are now included in the presentation';

  @override
  String hiddenFilesFilter(int count) {
    return 'Hidden ($count)';
  }

  @override
  String get allFilesHiddenWarning =>
      'All files are hidden from the presentation. Please include at least one file.';

  @override
  String get fileSkippedInPresentation => 'Skipped in presentation';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkingForUpdates => 'Checking for updates...';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String get updateAvailableMessage =>
      'A new version of KoToViewer is available on Google Play.';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateDownloadedSnackbar =>
      'A new version has been downloaded. Restart the app to apply it.';

  @override
  String get restartToUpdate => 'Restart';

  @override
  String get appUpToDate => 'You are using the latest version of KoToViewer.';

  @override
  String get updateCheckFailed =>
      'Could not check for updates via Google Play.';

  @override
  String get openPlayStore => 'Open Google Play';

  @override
  String get debugTestingNote =>
      'In debug / local build, Google Play In-App Updates require installation via Play Store (Internal Testing track or Internal App Sharing).';

  @override
  String get simulateUpdate => 'Simulate Update (Debug)';

  @override
  String get localAppFolder => 'Uploaded Files';

  @override
  String get localAppFolderSubtitle => 'App local storage';

  @override
  String get deleteFileTitle => 'Delete File';

  @override
  String deleteFileConfirm(String name) {
    return 'Are you sure you want to permanently delete \"$name\" from app storage?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get fileDeleted => 'File deleted';

  @override
  String get removeFromRecent => 'Remove from recent';

  @override
  String get pdfFormFilling => 'Fill PDF Form';

  @override
  String pdfFormFieldsCount(int count) {
    return '$count fields';
  }

  @override
  String get pdfNoFormFields =>
      'This document contains no interactive form fields.';

  @override
  String get pdfFormSaved => 'Form saved successfully!';

  @override
  String get pdfFormFlatten => 'Flatten form after saving (Lock fields)';

  @override
  String get pdfFormFlattenTooltip =>
      'Values will become static text and fields cannot be edited further.';

  @override
  String get pdfFormSaveAsCopy => 'Save as new file...';

  @override
  String get pdfFormSaveOverwrite => 'Save';

  @override
  String get pdfDigitalCertificates => 'Digital Certificates & Signatures';

  @override
  String get pdfNoDigitalCertificates =>
      'This document does not contain a digital certificate or embedded electronic signature.';

  @override
  String get pdfSignedBy => 'Signed by:';

  @override
  String get pdfIssuer => 'Issuer (CA):';

  @override
  String get pdfSignDate => 'Signing Date:';

  @override
  String get pdfValidFrom => 'Valid from:';

  @override
  String get pdfValidTo => 'Valid to:';

  @override
  String get pdfSignatureValid => 'Valid Certificate';

  @override
  String get pdfSignatureExpired => 'Expired Certificate';

  @override
  String get pdfCheckExternalCert => 'Check external certificate file';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit Fullscreen';

  @override
  String get lockRotation => 'Lock Rotation';

  @override
  String get unlockRotation => 'Unlock Rotation';

  @override
  String get rotationLocked => 'Screen rotation locked';

  @override
  String get rotationUnlocked => 'Auto-rotation restored';

  @override
  String get dwgMemoryLimitError =>
      'This DWG drawing requires more memory than available on this device. Please convert it to DXF on a PC or clean it with the PURGE command in CAD software.';

  @override
  String dwgConversionFailed(String error) {
    return 'Could not convert DWG file: $error';
  }

  @override
  String get structuralDesignerBim => 'Structural Model (BIM)';

  @override
  String get structuralDesigner => 'Structural Model';

  @override
  String get structural3dView => '3D Structure';

  @override
  String get snapEnabledTooltip => 'Snap: Enabled';

  @override
  String get snapDisabledTooltip => 'Snap: Disabled';

  @override
  String get undoAction => 'Undo last action';

  @override
  String traceReferenceLayer(String storey) {
    return 'Trace Reference: $storey';
  }

  @override
  String get toolNavigation => 'Navigation';

  @override
  String get toolColumn => 'Column';

  @override
  String get toolShearWall => 'Shear Wall';

  @override
  String get toolSlab => 'Slab';

  @override
  String get toolOpening => 'Opening';

  @override
  String get toolCantilevers => 'Cantilevers';

  @override
  String circularColumnPreset(int diameter) {
    return 'Ø$diameter circular';
  }

  @override
  String get rotate90 => 'Rotate 90°';

  @override
  String get wallThicknessLabel => 'Wall thickness: ';

  @override
  String get undoPoint => 'Undo point';

  @override
  String closeSlab(int count) {
    return 'Close ($count)';
  }

  @override
  String get storeyManagerTitle => 'Storey Manager (Levels & Layers)';

  @override
  String get traceReferenceTitle => 'Trace Reference (Ghost Underlay)';

  @override
  String get traceRefNone => 'Off';

  @override
  String get traceRefBelow => 'Storey Below';

  @override
  String get traceRefAbove => 'Storey Above';

  @override
  String storeyElevationSub(
    String elevation,
    String height,
    int columns,
    int walls,
  ) {
    return 'Z: +$elevation m • H: $height m • $columns cols, $walls walls';
  }

  @override
  String get changeHeightH => 'Change height H';

  @override
  String get deleteStorey => 'Delete storey';

  @override
  String get newStorey => 'New Storey';

  @override
  String get duplicateTypical => 'Duplicate Typical';

  @override
  String get storeyClearHeight => 'Storey clear height (m)';

  @override
  String get cantileverAnalysisTitle =>
      'Cantilever Analysis (Overhangs & Deflection)';

  @override
  String get totalCantilevers => 'Total cantilevers';

  @override
  String get cornerCantilevers => 'Corner 2-way';

  @override
  String get criticalZones => 'Critical zones';

  @override
  String get maxDeflection => 'Max. deflection';

  @override
  String get eurocodeStandardInfo =>
      'EN 1992-1-1 (EC2): Deflection limit flim = Lcant / 250. Concrete creep φ = 2.5 and facade load included.';

  @override
  String get noCantileversFound =>
      'No cantilever overhangs detected.\nAll slabs are fully supported by columns/walls.';

  @override
  String get propLengthL => 'Length L';

  @override
  String get propSlabH => 'Slab h';

  @override
  String deflectionFtot(String value) {
    return 'Deflection ftot: $value mm';
  }

  @override
  String deflectionLimitFlim(String value) {
    return 'Limit flim: $value mm';
  }

  @override
  String get structural3dTitle => '3D Structural Model';

  @override
  String get shadingModeTitle => 'Shading Mode';

  @override
  String get centerView => 'Center View';

  @override
  String get allStoreys => 'All Storeys';

  @override
  String get shadingWireframe => 'Wireframe';

  @override
  String get shadingSolid => 'Solid White';

  @override
  String get shadingShadedEdges => 'Shaded with Edges';

  @override
  String get shadingNormals => 'Surface Normals';

  @override
  String get snapEndpoint => 'Endpoint';

  @override
  String get snapMidpoint => 'Midpoint';

  @override
  String get snapCenter => 'Center';

  @override
  String get snapNearest => 'Nearest';

  @override
  String get snapPerpendicular => 'Perpendicular';

  @override
  String get snapPoint => 'Point';

  @override
  String previewColumnTag(int width, int height) {
    return 'Column $width x $height cm';
  }

  @override
  String previewCircularColumnTag(int diameter) {
    return 'Column Ø$diameter cm';
  }

  @override
  String get previewWallStartTag => 'Shear Wall: start point';

  @override
  String get previewWallEndTag => 'Shear Wall: end point';

  @override
  String previewSlabVertexTag(int index) {
    return 'Slab: vertex $index';
  }

  @override
  String get cantileverTypeLinear => 'Linear cantilever (1-way)';

  @override
  String get cantileverTypeCorner => 'Double corner cantilever (2-way)';

  @override
  String get cantileverTypeTransfer =>
      'Transfer cantilever (column on overhang)';

  @override
  String get riskLevelSafe => 'Safe (Compliant)';

  @override
  String get riskLevelWarning => 'Warning (High deflection)';

  @override
  String get riskLevelCritical => 'Critical (Excessive deflection)';

  @override
  String storeyLevelName(int number, String elevation) {
    return 'Storey $number (Elev. +$elevation)';
  }

  @override
  String storeyTypicalName(int number, String source) {
    return 'Storey $number (Typical from $source)';
  }

  @override
  String get hardwareAcceleration => 'Hardware GPU Acceleration';

  @override
  String get gpuAccelerationActive => 'Hardware GPU Acceleration (Active)';

  @override
  String get gpuAccelerationInactive => 'Hardware GPU Acceleration (Off)';

  @override
  String get structuralFilterActive => 'Underlay Filter: Walls & Axes only';

  @override
  String get structuralFilterInactive => 'Underlay Filter: All Layers (Off)';

  @override
  String get structuralFilterNoWallsFound =>
      'No specific wall or axis layers identified; showing full drawing';

  @override
  String get previewSlabCorner1Tag => 'Slab: pick 1st corner';

  @override
  String get previewSlabCorner2Tag => 'Slab: pick opposite corner';

  @override
  String cantileverExtrudeDepth(String depth) {
    return 'Cantilever: $depth m';
  }

  @override
  String get slabEdgeExtrudeTooltip => 'Drag midpoint to extrude cantilever';

  @override
  String slabParallelAligned(String distance) {
    return 'Aligned to line: $distance m';
  }

  @override
  String get slabPointByPointPrompt =>
      'Tap or hold with snap to place slab points';

  @override
  String get cancelSlab => 'Cancel slab';

  @override
  String slabRectDimensions(String width, String height) {
    return 'Slab: $width x $height m';
  }

  @override
  String get moveElement => 'Move';

  @override
  String get rotateElement => 'Rotate 90°';

  @override
  String get mirrorElement => 'Mirror';

  @override
  String get columnDeleted => 'Column deleted';

  @override
  String selectedColumnTitle(String dimensions) {
    return 'Selected Column $dimensions';
  }

  @override
  String get dragToMoveTooltip => 'Hold and drag to move';

  @override
  String get slabCorrectionTitle => 'Slab Correction';

  @override
  String get slabOffsetLabel => 'Offset';

  @override
  String get slabRotateLabel => 'Rotation';

  @override
  String get slabPointsMerged => 'Points merged';

  @override
  String slabPointDeleted(int number) {
    return 'Point $number deleted';
  }

  @override
  String get slabVertexInserted => 'New vertex inserted at midpoint';

  @override
  String get slabMinPointsWarning => 'Slab must have at least 3 points';

  @override
  String get deleteSlab => 'Delete slab';

  @override
  String get slabDeleted => 'Slab deleted';

  @override
  String get editSlabAction => 'Edit Slab';

  @override
  String get selectedSlabTitle => 'Selected Slab';

  @override
  String get duplicateElement => 'Duplicate';

  @override
  String get flipSide => 'Flip Side';

  @override
  String selectedWallTitle(String dimensions) {
    return 'Selected Shear Wall $dimensions';
  }

  @override
  String get columnShapeLShape => 'L-Shape 50x50/25';

  @override
  String get toolBeam => 'Beam';

  @override
  String selectedBeamTitle(String dimensions) {
    return 'Selected Beam $dimensions';
  }

  @override
  String selectedOpeningTitle(String dimensions) {
    return 'Selected Opening $dimensions';
  }

  @override
  String get deleteVertex => 'Delete Vertex';

  @override
  String get beamPreset25x50 => '25x50';

  @override
  String get beamPreset25x60 => '25x60';

  @override
  String get beamPreset25x40 => '25x40';

  @override
  String get openingPresetShaft => 'Shaft 0.40x0.60';

  @override
  String get openingPresetStairs => 'Stairwell 2.40x4.50';

  @override
  String get openingPresetElevator => 'Elevator 1.80x2.00';

  @override
  String get openingPresetCustom => 'Custom Opening';

  @override
  String get deleteOpening => 'Delete Opening';

  @override
  String get toolGridAxis => 'Grid Axis';

  @override
  String selectedGridAxisTitle(String name) {
    return 'Grid Axis $name';
  }

  @override
  String get deleteGridAxis => 'Delete Axis';

  @override
  String get renameGridAxis => 'Rename';

  @override
  String get firstWallSidePrompt => 'Select first wall side';

  @override
  String get secondWallSidePrompt => 'Select opposite wall side';

  @override
  String get snapIntersection => 'Intersection';

  @override
  String get verticalCapacityTitle => 'Vertical Capacity (EC2)';

  @override
  String get verticalCapacitySubtitle =>
      'Column crushing, punching shear and slab deflection';

  @override
  String get columnCrushingTitle => 'Column Crushing';

  @override
  String get punchingShearTitle => 'Punching Shear';

  @override
  String get slabDeflectionTitle => 'Recommended Slab Thickness';

  @override
  String get foundationPressureTitle => 'Foundation Load';

  @override
  String get totalBaseLoad => 'Total Vertical Load';

  @override
  String get criticalColumns => 'Critical Columns';

  @override
  String get punchingRisks => 'Punching Risks';

  @override
  String get maxSpanLabel => 'Max Span';

  @override
  String get recommendedThicknessLabel => 'Recommended Thickness';

  @override
  String get axialUtilizationLabel => 'Axial Compression (EC2)';

  @override
  String get punchingStressLabel => 'Punching Shear Stress';

  @override
  String get statusSafe => 'Safe';

  @override
  String get statusWarning => 'Warning';

  @override
  String get statusCritical => 'Critical Overload';

  @override
  String get ec2FeasibilityButton => 'EC2 Capacity';

  @override
  String columnRequiredSection(String section) {
    return 'Requires min $section';
  }

  @override
  String storeyColumnLoad(String storey, String ned, String nrd, String ratio) {
    return '$storey: Ned = $ned kN / Nrd = $nrd kN ($ratio%)';
  }

  @override
  String get seismicAnalysisTitle => 'Seismic Analysis (EC8)';

  @override
  String get seismicAnalysisSubtitle =>
      'Eccentricity, shear walls, transfer columns & beams';

  @override
  String get centerOfMass => 'Center of Mass (CM)';

  @override
  String get centerOfRigidity => 'Center of Rigidity (CR)';

  @override
  String get seismicEccentricity => 'Seismic Eccentricity';

  @override
  String get torsionalSensitivity => 'Torsional Sensitivity';

  @override
  String get shearWallRatio => 'Shear Wall Ratio';

  @override
  String get floatingColumnsTitle => 'Transfer / Floating Columns';

  @override
  String get floatingColumnBadge => 'FLOATING';

  @override
  String get discontinuousWallsTitle => 'Discontinuous Shear Walls';

  @override
  String get softStoreyTitle => 'Soft Storey';

  @override
  String get beamSizingTitle => 'Beam Sizing';

  @override
  String get openingsProximityTitle => 'Slab Openings Proximity';

  @override
  String get ec8SeismicButton => 'EC8 Seismic';

  @override
  String beamDepthWarning(int depth) {
    return 'Recommended depth: min $depth cm';
  }

  @override
  String floatingColumnWarning(String name, String storey) {
    return 'Column $name on $storey is floating on the slab (no lower support)!';
  }

  @override
  String get applyAction => 'Apply';

  @override
  String get offsetAction => 'Offset';

  @override
  String get renameColumnTitle => 'Rename Column';

  @override
  String get renameBeamTitle => 'Rename Beam';

  @override
  String get designationLabel => 'Designation (e.g. C1, C2, W1)';

  @override
  String get keepBoth => 'Keep Both';

  @override
  String get deletePrevious => 'Delete Previous';

  @override
  String get offsetCreatedTitle => 'Offset Created';

  @override
  String deletePreviousAxisPrompt(String name) {
    return 'Do you want to delete the previous axis \"$name\"?';
  }

  @override
  String deletePreviousColumnPrompt(String name) {
    return 'Do you want to delete the previous column \"$name\"?';
  }

  @override
  String offsetWithDuplication(String item) {
    return 'Offset with duplication: $item';
  }

  @override
  String get distanceMeters => 'Distance (meters)';

  @override
  String get duplicationDirection => 'Duplication Direction:';

  @override
  String get directionLeft => 'Left';

  @override
  String get directionRight => 'Right';

  @override
  String get directionUp => 'Up';

  @override
  String get directionDown => 'Down';

  @override
  String get specifyDirectionByDrag =>
      'Specify direction by dragging on canvas';

  @override
  String dragForDirectionReleaseToOffset(String distance) {
    return 'Drag for direction • Release to offset ($distance m)';
  }

  @override
  String get columnDimensionsTitle => 'Column Dimensions';

  @override
  String get widthCm => 'Width (cm)';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get shapeRectangular => 'Rectangular';

  @override
  String get shapeCircular => 'Circular';

  @override
  String get shapeLShape => 'L-shaped';

  @override
  String get shearWallThicknessTitle => 'Shear Wall Thickness';

  @override
  String get thicknessCm => 'Thickness (cm)';

  @override
  String get beamDimensionsTitle => 'Beam Dimensions';

  @override
  String get widthBCm => 'Width b (cm)';

  @override
  String get depthHCm => 'Depth h (cm)';

  @override
  String get slabThicknessTitle => 'Slab Thickness';

  @override
  String get slabThicknessHCm => 'Thickness h (cm)';

  @override
  String get axisNameTitle => 'Grid Axis Name';

  @override
  String get axisNameLabel => 'Axis Name / Number (e.g. 1, A, 1-1)';

  @override
  String get shearWallTitle => 'Shear Wall';

  @override
  String get beamTitle => 'Beam';

  @override
  String get slabOpeningTitle => 'Slab Opening';

  @override
  String gridAxisTitle(String name) {
    return 'Axis \"$name\"';
  }

  @override
  String get structuralElevationLabel => 'S.L.';

  @override
  String get layersTooltip => 'CAD Underlay Layers';

  @override
  String get dimensionsEllipsis => 'Dimensions...';

  @override
  String get otherEllipsis => 'Other...';

  @override
  String get hiddenBeamLabel => 'hidden';

  @override
  String get shaftOpeningLabel => 'Shaft (40×60)';

  @override
  String get elevatorOpeningLabel => 'Elevator (1.8×2.0)';

  @override
  String get stairsOpeningLabel => 'Stairs (2.4×4.5)';

  @override
  String get nameEllipsis => 'Name...';

  @override
  String get pointsAbbr => 'pts';

  @override
  String get previewOpeningCorner2Tag => 'Opening: pick opposite corner';

  @override
  String get cancelOpening => 'Cancel opening';

  @override
  String get seismicStatMaxEccentricity => 'Max. Ecc.';

  @override
  String get seismicStatTorsion => 'Torsion';

  @override
  String get seismicStatusHigh => 'HIGH';

  @override
  String get seismicStatusNormal => 'Normal';

  @override
  String get seismicStatFloatingColumns => 'Floating Cols';

  @override
  String get seismicStatShearWallsEc8 => 'Shear Walls (EC8)';

  @override
  String get seismicStatusDeficit => 'DEFICIT';

  @override
  String get seismicStatusOkCoverage => 'OK >=1%';

  @override
  String get seismicTabBalance => 'Balance (CM/CR)';

  @override
  String get seismicTabWalls => 'Walls (%)';

  @override
  String get seismicTabRegularity => 'Regularity';

  @override
  String get seismicTabBeamsOpenings => 'Beams/Openings';

  @override
  String get seismicNoStoreys => 'No storeys defined in the project.';

  @override
  String get seismicEccentricityTitle => 'Seismic Eccentricity';

  @override
  String get seismicTorsionSensitive => 'Torsionally Sensitive';

  @override
  String get seismicBalanced => 'Balanced';

  @override
  String get seismicEccentricityXLabel => 'Eccentricity X (ex)';

  @override
  String get seismicEccentricityYLabel => 'Eccentricity Y (ey)';

  @override
  String get seismicLimitEc8Label => 'EC8 Limit';

  @override
  String get seismicTorsionStiffEccentric => 'Torsionally Stiff (e > 0.30·r)';

  @override
  String get seismicStatusEccentricShort => 'Eccentric';

  @override
  String get seismicTorsionalRadiiLabel => 'Torsional radii (rx, ry)';

  @override
  String get seismicMassRadiusLabel => 'Floor mass radius (ls)';

  @override
  String get seismicLimitEc8Formula => '≤ 0.30·r (EC8)';

  @override
  String get seismicShearWallCoverageTitle => 'Shear Wall Coverage';

  @override
  String get seismicOkMinCoverage => 'OK (≥ 1.0%)';

  @override
  String get seismicDeficitMinCoverage => 'DEFICIT (< 1.0%)';

  @override
  String get seismicWallCoverageXLabel => 'X Coverage (ρ_wx):';

  @override
  String get seismicWallCoverageYLabel => 'Y Coverage (ρ_wy):';

  @override
  String seismicWallRecommendationText(String area) {
    return 'Eurocode 8 recommendation: minimum 1.0% - 1.5% shear walls in each direction relative to floor area ($area m²).';
  }

  @override
  String get seismicFloatingColumnsTitle => 'Floating / Transfer Columns';

  @override
  String seismicCountFound(int count) {
    return '$count found';
  }

  @override
  String get seismicNoFloatingColumnsText =>
      'No floating columns detected. All columns transfer loads directly to lower supports.';

  @override
  String get seismicCriticalEc8FloatingText =>
      'CRITICAL FOR SEISMIC SAFETY (EC8 §4.2.3.3): Floating columns transfer high concentrated loads directly onto the slab!';

  @override
  String seismicFloatingColItem(String storey, String columns) {
    return '• $storey: Columns $columns are floating without lower column.';
  }

  @override
  String get seismicSoftStoreyTitle => 'Soft Storey Check';

  @override
  String get seismicDanger => 'DANGER';

  @override
  String get seismicNone => 'NONE';

  @override
  String get seismicSoftStoreyDangerText =>
      'Stiffness drop detected (> 30%) between adjacent storeys. This creates a risk of soft storey collapse mechanism during earthquakes.';

  @override
  String get seismicSoftStoreyOkText =>
      'Stiffness changes smoothly across storeys (no soft storeys detected).';

  @override
  String get seismicNoBeamsOrOpenings => 'No beams or slab openings defined.';

  @override
  String get seismicBeamSizingTitle =>
      'Preliminary beam sizing (h = L/10 - L/12):';

  @override
  String seismicSpanM(String span) {
    return 'Span L = $span m';
  }

  @override
  String get seismicOpeningsProximityTitle =>
      'Slab openings near supports (< 4d):';

  @override
  String seismicRecFloatingCols(String names) {
    return 'Columns $names are FLOATING on the slab (no column underneath). This is a serious seismic vulnerability! ';
  }

  @override
  String seismicRecHighTorsion(String ecc, int pct) {
    return 'High torsional sensitivity: eccentricity $ecc m ($pct%). ';
  }

  @override
  String get seismicRecAddWallEast =>
      'Recommendation: add a shear wall in the eastern (right) part. ';

  @override
  String get seismicRecAddWallWest =>
      'Recommendation: add a shear wall in the western (left) part. ';

  @override
  String get seismicRecAddWallNorth =>
      'Recommendation: add a shear wall in the northern part. ';

  @override
  String get seismicRecAddWallSouth =>
      'Recommendation: add a shear wall in the southern part. ';

  @override
  String seismicRecDeficitBoth(String rx, String ry) {
    return 'Shear wall deficit in both directions (X: $rx%, Y: $ry% < 1.0%). Additional shear walls recommended. ';
  }

  @override
  String seismicRecDeficitX(String rx) {
    return 'Shear wall deficit in X ($rx% < 1.0%). Additional X-direction shear wall recommended. ';
  }

  @override
  String seismicRecDeficitY(String ry) {
    return 'Shear wall deficit in Y ($ry% < 1.0%). Additional Y-direction shear wall recommended. ';
  }

  @override
  String get seismicRecBalanced =>
      'Seismic balance and shear wall percentage coverage are excellent. ';

  @override
  String seismicRecTorsionStiffEccentric(
    String rx,
    String ry,
    String ls,
    String ecc,
  ) {
    return 'Torsionally stiff layout (rx=$rx m, ry=$ry m ≥ ls=$ls m), but structural eccentricity ($ecc m) exceeds 0.30·r. Requires 3D spatial dynamic modal response spectrum analysis per Eurocode 8. ';
  }

  @override
  String seismicRecTorsionRegular(String rx, String ry, String ls) {
    return 'Regular in plan per EC8 §4.2.3.2 (rx=$rx m, ry=$ry m ≥ ls=$ls m, e ≤ 0.30·r). Excellent torsional balance. ';
  }

  @override
  String seismicRecTorsionFlexible(String rx, String ry, String ls) {
    return 'Torsionally flexible system per EC8 §4.2.3.2 (rx=$rx m, ry=$ry m < ls=$ls m). Insufficient perimeter torsional stiffness! Additional perimeter shear walls/columns recommended. ';
  }

  @override
  String get seismicRecSoftStoreyPrefix =>
      'WARNING: SOFT STOREY! Lateral stiffness of this storey is > 30% lower than the storey above. ';

  @override
  String seismicRecBeamDepthInsufficient(
    String span,
    int depth,
    int recW,
    int recH,
  ) {
    return 'For span L = $span m, depth $depth cm is insufficient. Recommended beam ${recW}x$recH cm.';
  }

  @override
  String seismicRecBeamWidthInsufficient(int width, int depth) {
    return 'Width $width cm is below seismic minimum (25 cm under EC8). Recommended 25x$depth cm.';
  }

  @override
  String seismicRecBeamSizingOk(int width, int depth, String span) {
    return 'Cross-section ${width}x$depth cm is adequately sized for span L = $span m.';
  }

  @override
  String seismicRecOpeningClose(String dist, String support) {
    return 'Opening is $dist m from $support (< 0.70 m), penetrating the punching cone and requiring special edge trimming!';
  }

  @override
  String seismicRecOpeningSafe(String dist, String support) {
    return 'Opening is at a safe distance ($dist m from $support).';
  }

  @override
  String get seismicNoSlabBadge => 'No Slab Diaphragm';

  @override
  String get seismicNoSlabEccentricity => 'N/A (Slab required)';

  @override
  String get seismicRecNoSlabDiaphragm =>
      'No floor slab defined on this storey. In accordance with Eurocode 8 and structural dynamics, a floor slab over vertical elements is required to form a horizontal seismic diaphragm and compute Center of Mass (CM), Center of Rigidity (CR), and eccentricity.';

  @override
  String seismicRecDisconnectedWalls(String names) {
    return 'Shear wall(s) $names are located outside the slab boundary and do not connect to the horizontal diaphragm. They are excluded from CR and stiffness calculation.';
  }

  @override
  String seismicRecDisconnectedCols(String names) {
    return 'Column(s) $names are located outside the slab boundary and do not connect to the horizontal diaphragm.';
  }

  @override
  String seismicWallsOutsideSlabWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count walls outside slab (excluded from diaphragm)',
      one: '1 wall outside slab (excluded from diaphragm)',
    );
    return '$_temp0';
  }

  @override
  String get seismicNoSlabWallCoverage =>
      'Shear wall ratio cannot be computed without a floor slab diaphragm.';

  @override
  String get verticalBasePressure => 'Base Pressure';

  @override
  String get verticalNoColumns => 'No columns defined in the project.';

  @override
  String get verticalPunchingCheckLabel => 'Punching Shear (EC2 §6.4):';

  @override
  String verticalRecSlabInsufficient(String span, int cur, int req) {
    return 'For span L = $span m, slab thickness $cur cm is insufficient. Minimum $req cm recommended.';
  }

  @override
  String verticalRecSlabBeamlessDeflection(String span, int cur, int req) {
    return 'For clear span L = $span m without beams, slab $cur cm will deflect excessively. Minimum $req cm or main beams 25x50 cm recommended.';
  }

  @override
  String verticalRecSlabSafe(int cur, String span) {
    return 'Slab thickness ($cur cm) is adequate for clear span L = $span m.';
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
    return 'Column $name in $storey cannot be ${curW}x$curH cm; must be at least $minSec to support $storeys storeys (Ned = $ned kN, capacity Nrd = $nrd kN).';
  }

  @override
  String verticalRecColWarning(
    String name,
    String storey,
    int util,
    String minSec,
  ) {
    return 'Column $name in $storey is near capacity ($util%). Upgrading to $minSec is recommended.';
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
    return 'Column $name (${curW}x$curH cm) in $storey safely carries $storeys storeys ($util%).';
  }

  @override
  String verticalRecPunchingRisk(
    String name,
    String ved,
    String vrdc,
    int slabH,
  ) {
    return 'Risk of slab punching at $name (v_Ed = $ved MPa > v_Rd,c = $vrdc MPa). Recommended: drop panel, slab $slabH cm or larger column.';
  }

  @override
  String verticalRecPunchingProtectedByBeams(String name) {
    return 'Column $name is protected from punching: slab loads are carried directly by framing beams.';
  }

  @override
  String verticalTabColumns(int count) {
    return 'Columns ($count)';
  }

  @override
  String verticalTabSlabs(int count) {
    return 'Slabs ($count)';
  }

  @override
  String get verticalTabFoundations => 'Foundations';

  @override
  String verticalStoreysCarried(
    String storey,
    int storeys,
    String storeysLabel,
    String area,
  ) {
    return '$storey • Carries $storeys $storeysLabel • Atrib = $area m²';
  }

  @override
  String get verticalStoreySingle => 'storey';

  @override
  String get verticalStoreyPlural => 'storeys';

  @override
  String get verticalAxialCompressionLabel => 'Axial Compression (EC2 §5.8):';

  @override
  String get verticalNoSlabs => 'No slabs defined in the project.';

  @override
  String verticalSlabStoreyTitle(String storey) {
    return 'Slab - $storey';
  }

  @override
  String get verticalSlabStatusOk => 'Normal';

  @override
  String get verticalSlabStatusEnlarge => 'Enlargement recommended';

  @override
  String get verticalClearSpanLmax => 'Clear span (Lmax)';

  @override
  String get verticalCurrentThicknessH => 'Current thickness (h)';

  @override
  String get verticalRequiredThicknessEc2 => 'Required (EC2 §7.4)';

  @override
  String get verticalFoundationsEvaluation => 'Foundation Load Assessment';

  @override
  String get verticalTotalBaseLoadNed =>
      'Total vertical load at foundation (Ned,base):';

  @override
  String get verticalFootprintArea => 'Footprint area (foundation):';

  @override
  String get verticalMeanBasePressure => 'Average soil base pressure (σ_base):';

  @override
  String verticalBasePressureSafeText(String pressure) {
    return 'Base pressure ($pressure kPa) is within standard limits for mat/strip foundations in moderate to good soils (R0 >= 200 kPa).';
  }

  @override
  String verticalBasePressureHighText(String pressure) {
    return 'Base pressure ($pressure kPa) is high. A full mat foundation or piling is recommended following a geotechnical report.';
  }

  @override
  String get toolMeasure => 'Measure';

  @override
  String get distanceCentimeters => 'Distance (cm)';

  @override
  String get loadStructuralModule => 'Load Structural Module';

  @override
  String get updatingLayers => 'Updating layers...';

  @override
  String get isolateStructuralLayers => 'Isolate Structural Layers';

  @override
  String get showAllLayers => 'Show All Layers';

  @override
  String get layersPreparationTitle => 'Prepare CAD Layers for BIM';

  @override
  String get layersPreparationSubtitle =>
      'Hide architectural clutter, text, and furniture for better clarity and performance.';

  @override
  String get exportBimModel => 'Export BiM Model';

  @override
  String get exportBimJson => 'BiM Project (JSON)';

  @override
  String get exportStructuralDxf => 'Structural AutoCAD (DXF)';

  @override
  String get exportSuccess => 'Model exported successfully';

  @override
  String exportFailed(String error) {
    return 'Failed to export model: $error';
  }

  @override
  String slabOverStorey(String storey) {
    return 'Slab over $storey';
  }

  @override
  String get shearWallSizePreset => '25×150 cm';

  @override
  String get shearWallSizePresetAlt => '25×120 cm';

  @override
  String get customWallDimensions => 'Custom Wall...';

  @override
  String measuredDistance(String meters, String cm) {
    return 'Distance: $meters m ($cm cm)';
  }

  @override
  String measuredDelta(String dx, String dy) {
    return 'ΔX = $dx m, ΔY = $dy m';
  }

  @override
  String get clearMeasurement => 'Clear';

  @override
  String get columnNamePrefix => 'C';

  @override
  String get shearWallNamePrefix => 'W';

  @override
  String slabSectionElevationMarker(String elevation) {
    return 'T.O.C. $elevation';
  }

  @override
  String slabThicknessLabel(String thickness) {
    return 'd = $thickness cm';
  }

  @override
  String get autoDetectWallsAndAxes => 'Auto-Detect Walls & Axes';

  @override
  String autoDetectWallsPrompt(String thickness, String unit, String layer) {
    return 'Detected walls ($thickness $unit) in \"$layer\". Isolate walls and generate centerline axes?';
  }

  @override
  String get isolateWallsAndGenerateAxes => 'Isolate Walls & Generate Axes';

  @override
  String wallsAndAxesGeneratedSuccess(
    int axesCount,
    int wallsCount,
    String unit,
  ) {
    return 'Generated $axesCount axes and isolated $wallsCount wall contours ($unit)';
  }

  @override
  String get noWallsDetected => 'No 25 cm wall pairs detected in drawing';

  @override
  String wallCandidatesFound(int pairCount, String length) {
    return 'Found $pairCount wall pairs ($length m)';
  }

  @override
  String get autoDetectWallsSubtitle =>
      'Find 25 cm masonry walls, isolate contours into WALLS_250 and draw dashed AXIS centerlines.';
}
