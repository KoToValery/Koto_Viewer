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
  String get back => 'Back';

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
  String get showBimOverlay => 'Show Structural BIM Elements';

  @override
  String get hideBimOverlay => 'Hide Structural BIM Elements';

  @override
  String get structuralDesigner => 'Structural Model';

  @override
  String get structural3dView => '3D Structure';

  @override
  String get snapEnabledTooltip => 'Snap: Enabled';

  @override
  String get snapDisabledTooltip => 'Snap: Disabled';

  @override
  String get undoAction => 'Undo';

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
  String closeOpening(int count) {
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
  String get snapOpeningEdge => 'Opening edge';

  @override
  String get snapOpeningCenter => 'Opening center';

  @override
  String get snapModuleStep => 'Module step';

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
  String get structuralFilterActive => 'Underlay Filter (On)';

  @override
  String get structuralFilterInactive => 'Underlay Filter (Off)';

  @override
  String get structuralFilterNoWallsFound =>
      'No specific wall or axis layers identified; showing full drawing';

  @override
  String get floatingColumnBadge => 'FLOATING';

  @override
  String alignedOffsetFlush(String offset) {
    return '$offset m (Flush)';
  }

  @override
  String get layersTabTitle => 'Layers';

  @override
  String get layersTabHint =>
      'Hold any drawing element to hide or isolate its layer';

  @override
  String get underlayFilterTitle => 'Underlay Filter';

  @override
  String get underlayFilterSubtitle =>
      'Customize which CAD layers are visible in underlay filter mode';

  @override
  String get underlayFilterAutoReset => 'Auto (Walls & Axes)';

  @override
  String get underlayFilterSelectAll => 'Select All';

  @override
  String get underlayFilterClearAll => 'Clear All';

  @override
  String get syncColumnsAcrossStoreys => 'Sync Column Numbers Across Storeys';

  @override
  String syncColumnsSuccess(int count) {
    return '$count columns synchronized across storeys';
  }

  @override
  String layerHiddenNotice(String layer) {
    return 'Layer \"$layer\" is now hidden';
  }

  @override
  String get filteringUnderlay => 'Applying underlay filter...';

  @override
  String get searchLayers => 'Search layers...';

  @override
  String get manageUnderlayFilter => 'Configure Filter';

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
  String get openingPointByPointPrompt => 'Tap point by point to draw opening';

  @override
  String get staircase2PointPrompt =>
      'Tap 1st corner, then drag or tap 2nd corner for staircase';

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
  String get seismicAnalysisTitle => 'Preliminary seismic layout';

  @override
  String get seismicAnalysisSubtitle =>
      'Layout indicators — not EC8 compliance';

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
  String get openingShaftTitle => 'Shaft';

  @override
  String get openingStaircaseTitle => 'Staircase Opening';

  @override
  String get openingElevatorTitle => 'Elevator Shaft';

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
  String get shaftOpeningLabel => 'Shaft';

  @override
  String get elevatorOpeningLabel => 'Elevator';

  @override
  String get stairsOpeningLabel => 'Stairs';

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
  String get seismicStatShearWallsEc8 => 'Wall ratio*';

  @override
  String get seismicStatusDeficit => 'DEFICIT';

  @override
  String get seismicStatusOkCoverage => '≥1%*';

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
  String get seismicLimitEc8Label => 'Eccentricity reference';

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
  String get seismicShearWallCoverageTitle => 'Wall area ratio — heuristic';

  @override
  String get seismicOkMinCoverage => '≥1% reference';

  @override
  String get seismicDeficitMinCoverage => '<1% reference';

  @override
  String get seismicWallCoverageXLabel => 'X Coverage (ρ_wx):';

  @override
  String get seismicWallCoverageYLabel => 'Y Coverage (ρ_wy):';

  @override
  String seismicWallRecommendationText(String area) {
    return 'Application screening reference: 1.0% connected wall area in each direction relative to net floor area ($area m²). This is not a universal Eurocode 8 minimum or proof of seismic capacity.';
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
      'Opening proximity — 0.70 m screening reference';

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
      'No warning from the preliminary layout indicators. EC8 compliance has not been established. ';

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
    return 'Clear distance between opening and $support: $dist m — below the 0.70 m screening reference. Punching shear and edge reinforcement require separate checks.';
  }

  @override
  String seismicRecOpeningSafe(String dist, String support) {
    return 'Clear distance between opening and $support: $dist m. Outside the 0.70 m screening band; punching shear has not been verified.';
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
  String get seismicPreliminaryBalanced => 'No layout warning';

  @override
  String get seismicRigidityUnavailable =>
      'Lateral layout cannot be evaluated: no usable connected supports, an unsupported section, or an ill-conditioned model. CR and eccentricity are unavailable.';

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
    return 'Ceiling slab above $storey';
  }

  @override
  String get verticalSlabStatusOk => 'Normal';

  @override
  String get verticalSlabStatusEnlarge => 'Enlargement recommended';

  @override
  String get verticalSlabStatusUnknown => 'Undetermined';

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
  String get bimMeasureGestureHint =>
      'Drag to pan · Tap for a point · Hold for precision · Pinch to zoom';

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
  String get noWallsDetected =>
      'No standard wall pairs (20-30 cm) detected in drawing';

  @override
  String wallCandidatesFound(int pairCount, String length) {
    return 'Found $pairCount wall pairs ($length m)';
  }

  @override
  String get autoDetectWallsSubtitle =>
      'Find 20-30 cm walls, isolate contours into WALLS_250 and draw grid axes.';

  @override
  String get stripFootingFoundation => 'Strip Foundations (±0.00)';

  @override
  String get matFoundation => 'Mat Foundation (±0.00)';

  @override
  String foundationFootingLabel(int width) {
    return 'Foundation • b = $width cm';
  }

  @override
  String overheadSlabLabel(String elev) {
    return 'Overhead Slab (+$elev m)';
  }

  @override
  String get bimProjects => 'BiM Projects';

  @override
  String get bimProjectsSubtitle => 'Structural models & multi-storey drawings';

  @override
  String get bimProjectLibraryTitle => 'BiM Projects Library';

  @override
  String get bimProjectNew => 'New BiM Project';

  @override
  String get bimProjectName => 'Project Name';

  @override
  String get bimProjectNameHint => 'e.g. Residential Building Flora';

  @override
  String get bimProjectLocation => 'Location / City';

  @override
  String get bimProjectLocationHint => 'e.g. Sofia, Bulgaria';

  @override
  String get bimProjectStoreysSection => 'Storeys & Underlays';

  @override
  String get bimProjectAddUnderlay => 'Add Underlay';

  @override
  String get bimProjectReplaceUnderlay => 'Replace Underlay';

  @override
  String get bimProjectNoUnderlay => 'No underlay attached';

  @override
  String get bimProjectUnderlayFormatError =>
      'Please select a valid .dxf, .dwg or .kcad CAD drawing file.';

  @override
  String get bimProjectElevation => 'Elevation (m)';

  @override
  String get bimProjectHeight => 'Height (m)';

  @override
  String get bimProjectStoreyName => 'Storey Name';

  @override
  String get bimProjectQuickSetup => 'Quick Storey Setup';

  @override
  String get bimProjectBasementCount => 'Basements';

  @override
  String get bimProjectAboveGroundCount => 'Above ground';

  @override
  String get bimProjectFloorHeight => 'Storey height (m)';

  @override
  String get bimProjectGenerateStoreys => 'Generate Storeys';

  @override
  String get bimProjectAddStorey => 'Add Storey';

  @override
  String get bimProjectDeleteStorey => 'Delete Storey';

  @override
  String get bimProjectCreateButton => 'Create Project';

  @override
  String get bimProjectStatusAlignment => 'Awaiting Alignment';

  @override
  String get bimProjectStatusReady => 'Aligned • BiM Ready';

  @override
  String bimProjectStoreysCount(int count) {
    return '$count storeys';
  }

  @override
  String get bimProjectOpen => 'Open Model';

  @override
  String get bimProjectAlignStoreys => 'Align Drawings';

  @override
  String get bimProjectDeleteConfirmTitle => 'Delete Project?';

  @override
  String bimProjectDeleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? All structural elements and drawings will be deleted.';
  }

  @override
  String get bimProjectRename => 'Rename';

  @override
  String get bimAlignmentTitle => 'Drawing Alignment';

  @override
  String get bimAlignmentInstructions =>
      'Tap and hold to place a common control point (e.g. intersection of axes 1 and A) on each storey underlay.';

  @override
  String bimAlignmentControlPointSet(String x, String y) {
    return 'Control point set at ($x, $y)';
  }

  @override
  String get bimAlignmentControlPointMissing => 'Control point required';

  @override
  String get bimAlignmentOnionSkin => 'Ghost lower storey';

  @override
  String get bimAlignmentReadyButton => 'Ready • Start BiM';

  @override
  String get bimAlignmentConfirmTitle => 'Confirm Alignment & Start BiM';

  @override
  String get bimAlignmentConfirmMessage =>
      'All control points are placed. The BiM module will now align the storeys, detect walls and generate grid axes. Proceed?';

  @override
  String get bimProjectExportStoreyDxf => 'Export Storey Drawing (DXF)';

  @override
  String get bimProjectExportStoreyDxfSubtitle =>
      'Original coordinates with visible & structural layers';

  @override
  String get bimProjectExportAllZip => 'Export Project Package (ZIP)';

  @override
  String get bimProjectExportAllZipSubtitle =>
      'All storey drawings + structural BiM model';

  @override
  String bimProjectExportSuccess(String filename) {
    return 'Exported successfully: $filename';
  }

  @override
  String get bimProjectNoProjects =>
      'No BiM projects yet. Tap \'+\' to create your first structural project.';

  @override
  String get bimProjectManageStoreys => 'Manage Storeys & Underlays';

  @override
  String bimProjectBasement(int num) {
    return 'Basement $num';
  }

  @override
  String get bimProjectGroundFloor => 'Ground Floor';

  @override
  String bimProjectFloor(int num) {
    return 'Floor $num';
  }

  @override
  String get bimProjectSaving => 'Saving BiM project...';

  @override
  String get bimProjectUnderlayAttached => 'Underlay attached';

  @override
  String get bimProjectAlignFirstPrompt =>
      'Please align all storeys before entering the BiM designer.';

  @override
  String get bimProjectLoading => 'Loading BiM project and underlays...';

  @override
  String get cadThemeDarkCad => 'CAD Dark';

  @override
  String get cadThemePaperWhite => 'Paper White';

  @override
  String get noSlabLayerDetectedOrEmpty =>
      'No slab layer found or layer is empty';

  @override
  String slabLayerAddedToFilter(String layer) {
    return 'Slab layer \"$layer\" added to structural filter';
  }

  @override
  String get deleteOpeningPoint => 'Delete Point';

  @override
  String get openingPointsMerged => 'Opening points merged';

  @override
  String get finePositionTitle => 'Position & Nudge';

  @override
  String nudgeStepLabel(String step) {
    return 'Step: $step';
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
    return 'Clear: $distance m';
  }

  @override
  String axialDistanceDimension(String distance) {
    return 'Axis: $distance m';
  }

  @override
  String get flushFaceAligned => 'Flush Face';

  @override
  String get refLineCenter => 'Ref: Center';

  @override
  String get refLineLeft => 'Ref: Left Face';

  @override
  String get refLineRight => 'Ref: Right Face';

  @override
  String get refLineTitle => 'Reference Line';

  @override
  String get snapToNearest => 'Snap to nearest';

  @override
  String get alignLeftFace => 'Flush Left';

  @override
  String get alignRightFace => 'Flush Right';

  @override
  String get alignTopFace => 'Flush Top';

  @override
  String get alignBottomFace => 'Flush Bottom';

  @override
  String shearWallRefLineChanged(String line) {
    return 'Reference line: $line';
  }

  @override
  String get axisLockAuto => 'Auto';

  @override
  String get axisLockX => '↔ Lock X';

  @override
  String get axisLockY => '↕ Lock Y';

  @override
  String get axisLockTitle => 'Axis Constraint';

  @override
  String get equalSpacing => 'Equal Spacing';

  @override
  String equalSpacingDimension(String distance) {
    return '$distance = $distance m';
  }

  @override
  String get clearDistanceToNeighbors => 'Clear Distance to Neighbors';

  @override
  String clearDistanceLeft(String name, String dist) {
    return 'To $name (Left): $dist m';
  }

  @override
  String clearDistanceRight(String name, String dist) {
    return 'To $name (Right): $dist m';
  }

  @override
  String clearDistanceTop(String name, String dist) {
    return 'To $name (Top): $dist m';
  }

  @override
  String clearDistanceBottom(String name, String dist) {
    return 'To $name (Bottom): $dist m';
  }

  @override
  String get setClearDistanceAction => 'Clear Distance';

  @override
  String get targetClearDistanceLabel => 'Desired clear distance (m)';

  @override
  String get applyClearDistance => 'Apply';

  @override
  String get noNeighborsFound => 'No adjacent elements along axes';

  @override
  String get precisionMoveActive => 'Positioning active';

  @override
  String get confirmMove => 'Confirm';

  @override
  String get cancelMove => 'Cancel';

  @override
  String get bimProjectEditElevation => 'Edit elevation';

  @override
  String get bimProjectSortStoreys => 'Sort by elevation';

  @override
  String get bimProjectElevationHelper => 'e.g. +2.85, 0.00, -3.20';

  @override
  String get bimProjectInvalidElevation => 'Enter a valid elevation in metres.';

  @override
  String get bimProjectDuplicateElevation =>
      'A storey already has this elevation.';

  @override
  String get bimProjectConvertingUnderlay => 'Converting underlay…';

  @override
  String get bimProjectDetectingWallsAndSlabs => 'Detecting walls and slabs…';

  @override
  String get bimProjectKcadReady => 'KCAD ready';

  @override
  String get bimProjectConversionFailed => 'Underlay conversion failed';

  @override
  String get bimProjectReprocessUnderlay => 'Reprocess underlay';

  @override
  String bimSlabLoggiaCount(int count) {
    return 'Of these, loggia proposals: $count.';
  }

  @override
  String bimSlabProjectionCount(int count) {
    return 'External areas for review (cyan): $count. Type and level are not confirmed.';
  }

  @override
  String get bimSlabPreviewTitle => 'Slab contour proposals';

  @override
  String get bimSlabPreviewMissing =>
      'No contour analysis is saved. Use Reprocess underlay to run it.';

  @override
  String bimSlabPreviewCount(int count) {
    return 'Proposed contours: $count';
  }

  @override
  String get bimSlabPreviewExplanation =>
      'Orange contours are approximate proposals. Red connections are assumed openings requiring review; they may appear even when no contour was obtained. Enable the structural filter to see them. A proposal may cover only part of the building. Courtyards, shafts and stair openings are not classified. Check the level and concrete edge. No structural slab has been created.';

  @override
  String bimSlabPreviewRegions(int regions, int unresolved, int gaps) {
    return 'Analysed regions: $regions; without contours: $unresolved; assumed connections: $gaps.';
  }

  @override
  String bimSlabPreviewSkipped(int count) {
    return 'Regions not processed due to the work limit: $count.';
  }

  @override
  String get bimSlabPreviewEmpty =>
      'No reliable closed contour was obtained. Possible causes include open wall gaps, missing walls, ambiguous connections, very small enclosed areas or drawing extents too large for the current resolution.';

  @override
  String get cadLayersTitle => 'CAD Layers';

  @override
  String cadLayersVisibleCount(int visible, int total) {
    return '$visible of $total layers visible';
  }

  @override
  String get cadLayersShowAll => 'Show All';

  @override
  String get cadLayersHideAll => 'Hide All';

  @override
  String get cadLayersLineweightForAll => 'Lineweight for all:';

  @override
  String get cadLayersSelectForAll => 'Select for all...';

  @override
  String get cadLayersUnnamed => 'Unnamed Layer';

  @override
  String cadLayersObjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objects',
      one: '1 object',
    );
    return '$_temp0';
  }

  @override
  String get cadLayersFrozen => 'Frozen';

  @override
  String get cadLayersLineweight => 'Lineweight:';

  @override
  String get cadLayersOriginal => 'Original';

  @override
  String cadLayersOriginalWithMm(String mm) {
    return 'Original ($mm mm)';
  }

  @override
  String cadLayersMm(String mm) {
    return '$mm mm';
  }

  @override
  String get bimGenerateSlabs => 'Generate initial slabs';

  @override
  String get bimSlabsAlreadyGenerated =>
      'This storey already has generated slabs. Edit them directly; generation will not overwrite your changes.';

  @override
  String get bimSlabSeedsEmpty =>
      'No valid slab contours are available. Process the underlay first.';

  @override
  String bimSlabSeedsReview(int count, int skipped, String thickness) {
    return 'Create $count editable slabs on this storey; skipped: $skipped. Thickness: $thickness cm, from the current slab setting.\n\nEdges snap only at distances below 2 cm. These are initial proposals: review the contour, openings, levels and thickness before using them in the structural scheme.';
  }

  @override
  String get seismicNotEvaluated => 'Not evaluated';

  @override
  String get seismicModelAssumptions =>
      'Preliminary layout only: rigid diaphragm, common material/restraint factors and simplified weights. Cracking, core coupling, accidental torsion and 3D response are not verified.';

  @override
  String get seismicOpeningNotEvaluated =>
      'No support or valid opening geometry is available; proximity is not evaluated.';

  @override
  String seismicConnectionReview(String names) {
    return 'Unverified slab connection: $names. Partial contact or invalid/overly complex geometry requires review; stiffness and eccentricity are not evaluated.';
  }

  @override
  String get seismicInvalidSlabGeometry =>
      'Not evaluated: invalid slab or opening contour. Check self-intersections, openings outside the slab and touching/overlapping openings.';

  @override
  String get seismicOverlappingSlabs =>
      'Not evaluated: slabs overlap. Resolve geometry and loads to avoid counting mass twice.';

  @override
  String seismicSeparateRegions(int count) {
    return 'Detected $count disconnected slab regions. A shared centre of rigidity and eccentricity are not evaluated; separate diaphragms or a connection model are required.';
  }

  @override
  String get seismicSlabGeometryLimit =>
      'Not evaluated: slab geometry exceeds the preliminary check\'s capacity. A separate geometry review is required.';

  @override
  String seismicRegionTitle(int index, int columns, int walls) {
    return 'Region $index · columns: $columns, walls: $walls';
  }

  @override
  String seismicRegionSharedSupport(String names) {
    return 'Not evaluated: shared or uncertain support assignment: $names. A coupling model is required.';
  }

  @override
  String get seismicRegionScope =>
      'Isolated preliminary region models with existing slab weights and project surface loads. Coupling, beams between regions and vertical continuity are not evaluated.';

  @override
  String get seismicLoadsTitle => 'Seismic mass loads';

  @override
  String get seismicLoadsScope =>
      'Preliminary seismic model only. Self-weight 25 × h is added separately; exclude it from the permanent load. When disabled: project G/Q and participation 0.3. Participation is specified by the engineer, not selected automatically from Eurocodes. Vertical and cantilever checks retain their own loads.';

  @override
  String get seismicLoadPermanent => 'Additional permanent load G';

  @override
  String get seismicLoadVariable => 'Imposed load Q';

  @override
  String get seismicLoadParticipation => 'Q participation in mass (0–1)';

  @override
  String get seismicLoadOverride => 'Separate values for this slab';

  @override
  String seismicLoadSlab(int index) {
    return 'Slab $index';
  }

  @override
  String get seismicInvalidMassLoads =>
      'Not evaluated: check loads and thickness. G and Q must be finite nonnegative values, Q participation must be between 0 and 1, and thickness must be positive.';

  @override
  String get seismicWallContinuityTitle => 'Wall vertical continuity';

  @override
  String get seismicWallContinuityScope =>
      'Footprint overlap with parallel walls on the preceding project storey. Below 100% requires review for offsets, shortening or interruption. This is not a capacity check; transfer onto beams/columns and foundations are not evaluated.';

  @override
  String seismicWallContinuityItem(
    String storey,
    String wall,
    String coverage,
  ) {
    return '$storey · $wall: overlap $coverage';
  }

  @override
  String get seismicElevationAmbiguous =>
      'Vertical checks are not evaluated: duplicate or invalid elevations. Review storey levels.';

  @override
  String get seismicDirectionalScope =>
      'Preliminary stiffness ratio to the upper storey along X/Y. Below 0.70 flags review, not a code verdict. Only uniquely matched single regions are compared.';

  @override
  String get seismicRegionTrackingTitle => 'Regions across storeys';

  @override
  String get seismicLinkUnique => 'unique overlap';

  @override
  String get seismicLinkBranching => 'split/merge — review';

  @override
  String get seismicLinkAbsent => 'no overlap — review';

  @override
  String seismicRegionTrackingItem(
    String storey,
    int region,
    String lower,
    String matches,
    String coverage,
    String status,
  ) {
    return '$storey, region $region → $lower, regions $matches: $coverage; $status. Geometric link, not a verified load path.';
  }

  @override
  String get ceilingSlabTitle => 'Ceiling slab above the storey';

  @override
  String ceilingSlabContext(String level) {
    return 'Storey $level · ceiling slab above this storey';
  }

  @override
  String get ceilingExplicitLevel => 'Set concrete top elevation';

  @override
  String get ceilingConcreteTop => 'Top of concrete';

  @override
  String ceilingSlabLevels(String top, String bottom) {
    return 'Top $top m · soffit $bottom m';
  }

  @override
  String get ceilingSlabLevelHint =>
      'The slab and openings are above the active storey. Concrete top: next level minus finish; at the top storey: level plus height minus finish. An explicit elevation refers to concrete.';

  @override
  String get ceilingSlabInvalid =>
      'Enter a positive thickness and an elevation placing the slab above this storey and no higher than the next level.';

  @override
  String get overheadSlabTag => 'Overhead slab (ceiling)';

  @override
  String get slabEdgeOffset => 'Offset edge';

  @override
  String get slabEdgeNumber => 'Edge';

  @override
  String get slabEdgeDistance => 'Offset (cm)';

  @override
  String get slabEdgeHint =>
      'Positive: outward. Negative: inward. A shared edge also moves in the adjacent slab.';

  @override
  String get slabEdgeInvalid =>
      'This correction creates an invalid outline or affects a partially shared edge. Split the shared boundary into matching edges.';

  @override
  String get cleanSlabContour => 'Clean contour';

  @override
  String get cleanSlabContourTooltip =>
      'Remove redundant collinear points and repair artifacts';

  @override
  String slabContourCleaned(int count) {
    return 'Slab contour cleaned ($count redundant points removed)';
  }

  @override
  String get slabContourAlreadyClean =>
      'Slab contour is already clean and optimal';

  @override
  String get openingNoSlab => 'Create the ceiling slab first.';

  @override
  String get openingInvalidPlacement =>
      'The entire opening must lie inside one slab without touching its outline or another opening.';

  @override
  String get openingAmbiguousOwner =>
      'More than one slab contains this opening. Resolve the slab overlap.';

  @override
  String get openingMissing => 'The selected opening no longer exists.';

  @override
  String get schemeReadinessTitle => 'Check before generation';

  @override
  String get schemeGeometryReady =>
      'Slabs and staircase are geometrically ready.';

  @override
  String get schemeReadinessHint =>
      'This checks the input objects. It does not generate columns or shear walls and is not a structural assessment.';

  @override
  String get schemeEditing => 'Finish the current slab edit.';

  @override
  String get schemeMissingStairs =>
      'Place a Staircase opening in the ceiling slab. An elevator is optional.';

  @override
  String get schemeAmbiguousLevels =>
      'The storey or slab ownership is ambiguous. Check duplicate elevations and identifiers.';

  @override
  String get schemeInvalidLevel =>
      'Check the ceiling elevation and thickness: its soffit must be above the working storey base.';

  @override
  String get schemeInvalidGeometry =>
      'A slab or opening is invalid. Check self-intersections, boundaries and overlapping openings.';

  @override
  String get schemeOverlappingSlabs =>
      'Slabs overlap. Correct their outlines before generation.';

  @override
  String get schemeComputationLimit =>
      'These outlines exceed the check\'s complexity limit. Simplify them.';

  @override
  String get schemeCeilingLabel => 'Slab';

  @override
  String get schemeRegionsLabel => 'Separate regions';

  @override
  String get schemeGenerate => 'Suggest columns and shear walls';

  @override
  String get schemePreview => 'Initial structural layout';

  @override
  String get schemeVariantCore => 'Variant 1 · near the staircase';

  @override
  String get schemeVariantLong => 'Variant 2 · along long walls';

  @override
  String get schemeMinSpacing => 'Minimum column spacing (m)';

  @override
  String get schemeTargetSpacing => 'Target spacing (m)';

  @override
  String get schemeRebuild => 'Next variant';

  @override
  String get schemeConfirm =>
      'I confirm the displayed slab outlines and openings';

  @override
  String get schemeAccept => 'Accept proposal';

  @override
  String get schemeNoWalls =>
      'No solid wall runs detected. Grid axes alone do not authorize columns inside rooms.';

  @override
  String get schemeNoCandidates =>
      'No suitable free positions. Existing elements are preserved.';

  @override
  String get schemeLimits =>
      'The preliminary layout limit was reached. Review the remaining areas manually.';

  @override
  String get schemePreliminary =>
      'Automatic sizes use available wall space and preliminary axial/punching checks. Selected sections are starting sizes when adaptation is enabled. Confirm dimensions, load paths and reinforcement with a structural model.';

  @override
  String get schemeLegend =>
      'Grey: existing · Blue: slabs · Green: new columns · Orange: new walls · Red: openings';

  @override
  String get schemeUnresolved =>
      'Regions without walls in both principal directions';

  @override
  String get schemeRejected => 'Rejected candidates';

  @override
  String get schemeReport => 'Detailed assessment';

  @override
  String get schemeInvalidOptions =>
      'Enter positive sizes and spacing. Target spacing must be at least the minimum; maximum wall length must be at least the starting length.';

  @override
  String get schemeStale =>
      'The project changed. Open a new preview before accepting.';

  @override
  String get schemeComparison => 'Before → after';

  @override
  String get schemeFresh =>
      'Only new objects are accepted. Manual elements and accepted edits are preserved.';

  @override
  String get schemePairedWalls => 'Prefer distributed walls in both directions';

  @override
  String get schemeGenerousDensity => 'Additional support density (optional)';

  @override
  String get toggleGroundFoundations => 'Show foundations (±0.00)';

  @override
  String get schemeVariant => 'Variant';

  @override
  String get schemeNoAlternative =>
      'No distinct alternative found in this search. Change spacing or try again.';

  @override
  String get schemeCoverage =>
      'Red samples: distance exceeds half the target spacing / greatest support distance';

  @override
  String get schemeEurocodeScope =>
      'Preliminary geometric screening. Support distance is not a calculated span or deflection. EC2 verification requires a structural model, loads, materials and reinforcement; the EC8 report contains preliminary indicators only.';

  @override
  String get schemeSpanUnknown => 'Support span is undetermined';

  @override
  String get schemeSupportSpan => 'Critical support spacing (preliminary)';

  @override
  String get schemeOpeningFallback =>
      'Purple: fallback columns in door/window openings — review opening';

  @override
  String get schemeAdaptiveSizes =>
      'Adapt sections to walls and preliminary checks';

  @override
  String get schemeWallDensity =>
      'Connected wall area / net floor area (1% reference)';

  @override
  String get schemeWallDeficit =>
      'Remaining wall area deficit — placement constraints';

  @override
  String get schemeResizedColumns => 'Columns with adapted sections';

  @override
  String get schemeSizingReview =>
      'Column sections need review: load or punching check remains above the preliminary target';

  @override
  String get schemePlacementReasons => 'Rejected positions';

  @override
  String get schemeWallConstraint => 'wall fit';

  @override
  String get schemeSlabConstraint => 'slab / hole';

  @override
  String get schemeSpacingConstraint => 'spacing / collision';

  @override
  String get schemeMaxWallLength => 'Max new wall length (m)';

  @override
  String get schemeWallSections => 'Walls — thickness × length';

  @override
  String schemeContinueLower(String level) {
    return 'Continue the scheme from level $level, preserving positions and sections. Unresolved spans and wall deficits require revision of the lower scheme.';
  }

  @override
  String get schemeContinuityReview =>
      'Some manual supports do not match the lower scheme. Review vertical continuity.';

  @override
  String schemeBlockedContinuations(int count) {
    return 'Supports that cannot be continued: $count. Red points mark positions requiring review.';
  }

  @override
  String spanFeedbackCount(int count) {
    return 'Spacing problems: $count';
  }

  @override
  String get spanFeedbackScope => 'Preliminary · assigned slab thickness';

  @override
  String spanFeedbackUnknown(int count) {
    return 'Links without valid slab thickness: $count';
  }

  @override
  String get bimClearStructure => 'Clear structure — all storeys';

  @override
  String bimClearStructureConfirm(int count) {
    return 'Delete $count columns and shear walls across all storeys. Slabs, beams and axes remain. You can undo this action.';
  }

  @override
  String bimDeleteStoreyConfirm(String level) {
    return 'Delete storey $level and its structural elements?';
  }

  @override
  String bimUnderlayReviewNeeded(String levels) {
    return 'Underlay data changed at $levels. Review the preserved structural elements and openings.';
  }

  @override
  String bimFloorSlabReference(String level, String owner) {
    return 'Floor slab at $level — ceiling of storey $owner';
  }

  @override
  String get bimEditFloorSlab => 'Edit floor slab';

  @override
  String schemeSearchSummary(int layouts, int changes, int evaluations) {
    return 'Compared layouts: $layouts · accepted changes: $changes · evaluations: $evaluations';
  }

  @override
  String schemeFieldSummary(int count, int review) {
    return 'Closed fields: $count · for review: $review';
  }

  @override
  String get schemeUnresolvedFieldArea =>
      'Area with undetermined field support';

  @override
  String get schemeOpeningSupportReview =>
      'Support around openings: points for review';

  @override
  String get schemeBoundarySupportReview =>
      'Cantilever or undetermined edge support';

  @override
  String get schemeContinuityIssues => 'Vertical continuity issues';

  @override
  String get schemeConcreteVolume => 'Support concrete volume';

  @override
  String get schemeBalanceIndex =>
      'Preliminary torsion index (lower is better)';

  @override
  String get schemeNoWallConstraint => 'No suitable wall';

  @override
  String get schemeCollisionConstraint => 'Section collision';

  @override
  String get schemeColumnSpacingConstraint => 'Column spacing';

  @override
  String get schemeWallSpacingConstraint => 'Wall spacing';

  @override
  String get schemeBudgetConstraint => 'Placement budget';

  @override
  String get schemeLimitInput => 'Input size limit';

  @override
  String get schemeLimitSampling => 'Sampling limit';

  @override
  String get schemeLimitJunctions => 'Wall junction limit';

  @override
  String get schemeLimitElements => 'Support count limit';

  @override
  String get schemeLimitFields => 'Field topology limit';

  @override
  String get schemeLimitOptimization =>
      'Local search budget reached; optimality is not established';

  @override
  String get schemeStageCore => 'Core';

  @override
  String get schemeStageWalls => 'Distributed walls';

  @override
  String get schemeStageColumns => 'Column nodes';

  @override
  String get schemeStageCoverage => 'Coverage';

  @override
  String get schemeStageRepair => 'Span repair';

  @override
  String get schemeStageOpenings => 'Architectural opening review';

  @override
  String get schemePunchingGeometryReview =>
      'Punching support geometry or beam load transfer needs review';

  @override
  String get schemeInteriorColumn => 'Interior column';

  @override
  String get schemeEdgeColumn => 'Edge column';

  @override
  String get schemeCornerColumn => 'Corner column';

  @override
  String get schemeUnknownColumnPosition => 'Undetermined column position';

  @override
  String get schemeSearchNoImprovement =>
      'The search retained the best assessed seed';

  @override
  String get schemeMinWallSpacing => 'Minimum parallel wall spacing (m)';

  @override
  String get schemeUnavailableChecks => 'Undetermined checks';

  @override
  String get schemeSeedDensityConstraint => 'Skipped in the sparse seed';

  @override
  String get floorSlabTitle => 'Floor slab at this level';

  @override
  String floorSlabContext(String level) {
    return 'Floor of level $level · edit on its own plan';
  }

  @override
  String get floorSlabLevelHint =>
      'The slab belongs to this level and is shown as the ceiling on the immediately lower level.';

  @override
  String bimCeilingSlabReference(String owner) {
    return 'Ceiling slab · floor of level $owner';
  }

  @override
  String gridAxisSourceLevels(String levels) {
    return 'Levels: $levels';
  }

  @override
  String get staircaseSetupTitle => 'Staircases across levels';

  @override
  String get staircaseSetupHint =>
      'Set the start and final arrival level of each staircase. Outline circulation space on every level and the actual opening on arrival floors. The starting floor and the roof may remain solid.';

  @override
  String get staircaseNoStairs => 'This building has no staircases';

  @override
  String get staircaseAdd => 'Add staircase';

  @override
  String get staircaseStart => 'Start level';

  @override
  String get staircaseEnd => 'Final arrival level';

  @override
  String get staircaseZone => 'Circulation zone';

  @override
  String get staircaseZoneHint =>
      'Outline flights, landings and passage space. This polygon reserves space for stairs and does not cut the slab. Close the polygon to save.';

  @override
  String get staircaseDrawZone => 'Outline zone';

  @override
  String get staircaseDrawOpening => 'Outline floor opening';

  @override
  String get staircaseDetect => 'Find stair geometry';

  @override
  String get staircaseReviewMissing =>
      'Review staircase levels before generating supports.';

  @override
  String get staircaseScopeMissing =>
      'Check the start and final arrival levels.';

  @override
  String get staircaseZoneMissing => 'Missing or invalid circulation zone';

  @override
  String get staircaseOpeningMissing =>
      'Missing matching staircase opening in the arrival floor';

  @override
  String get staircaseOpeningReady => 'Floor opening found';

  @override
  String get staircaseZoneReady => 'Zone outlined';

  @override
  String get staircaseDetectionTitle => 'Stair geometry proposals';

  @override
  String get staircaseDetectionHint =>
      'Repeated strokes suggest flights, but do not establish the exact slab opening. Review the geometry and outline the opening on its arrival floor.';

  @override
  String get staircaseDetectionEmpty =>
      'No reliable repeated tread pattern found. Outline the zone manually or inspect the floor below.';

  @override
  String get staircaseUseZone => 'Use as circulation zone';

  @override
  String get staircaseDetectionPartial =>
      'Flight candidate; landing and passage space need review';

  @override
  String get staircaseLimit =>
      'Drawing is too large for a complete geometry search. Use manual outlining.';

  @override
  String get staircaseInvalidZone =>
      'The circulation polygon is invalid. Correct its points.';

  @override
  String get staircaseWinder => 'Winder flight';

  @override
  String staircaseEvidenceFromLevel(String level) {
    return 'Flight evidence from $level; review against this floor.';
  }

  @override
  String get staircaseSupportConflict =>
      'Existing supports overlap the staircase zone. Reposition them or correct the zone.';

  @override
  String staircaseCloseZone(int count) {
    return 'Save zone ($count points)';
  }

  @override
  String get staircaseUseOpening => 'Review opening contour';

  @override
  String staircaseArms(int count) {
    return '$count flights';
  }

  @override
  String get architectStudio => 'Architect Studio';

  @override
  String get architectStudioSubtitle =>
      '3D Conceptual design, walls, doors & storeys';

  @override
  String get architectNewProject => 'New Architectural Project';

  @override
  String get architectProjectName => 'Project Name';

  @override
  String get architectProjectNameHint => 'e.g. Modern Villa Alpha';

  @override
  String get architectUnits => 'Units';

  @override
  String get architectUnitMeters => 'Meters (m)';

  @override
  String get architectUnitCm => 'Centimeters (cm)';

  @override
  String get architectStoreys => 'Storeys';

  @override
  String get architectStoreyCount => 'Number of Storeys';

  @override
  String get architectStoreyHeight => 'Typical Floor Height (m)';

  @override
  String get architectGroundHeight => 'Ground Floor Height (m)';

  @override
  String get architectDynamicGridAxes => 'Dynamic Grid Axes';

  @override
  String get architectGridAxesX => 'Axes on X';

  @override
  String get architectGridAxesY => 'Axes on Y';

  @override
  String get architectGridSpacingX => 'Spacing X (m)';

  @override
  String get architectGridSpacingY => 'Spacing Y (m)';

  @override
  String get architectCategoryPlan => 'Plan';

  @override
  String get architectCategoryBuild => 'Build';

  @override
  String get architectCategoryDrawing => 'Draw';

  @override
  String get architectToolCategories => 'Categories';

  @override
  String get architectToolSelect => 'Select';

  @override
  String get architectToolWall => 'Wall';

  @override
  String get architectToolDoor => 'Door';

  @override
  String get architectToolMeasure => 'Measure';

  @override
  String get architectWallThickness => 'Thk.';

  @override
  String get architectWallSingle => 'Single';

  @override
  String get architectWallChained => 'Chain';

  @override
  String get architectFinishChained => 'End';

  @override
  String get architectDoorWidth => 'Width';

  @override
  String get architectDoorHeight => 'Height';

  @override
  String get architectDoorSill => 'Sill (hp)';

  @override
  String get architectDoorHingeLeft => 'Left';

  @override
  String get architectDoorHingeRight => 'Right';

  @override
  String get architectDoorSwingIn => 'Swing Inward';

  @override
  String get architectDoorSwingOut => 'Swing Outward';

  @override
  String get architectDoorSelectWallPrompt => 'Tap on a wall to place door';

  @override
  String get architectDoorSpecId => 'Mark (ID)';

  @override
  String get architectDoorHingeSide => 'Hinge';

  @override
  String get architectDoorSwingDirection => 'Opening';

  @override
  String get architectDoorFlipSwing => 'Flip swing (in/out)';

  @override
  String get architectDoorFlipHinge => 'Flip hinge (left/right)';

  @override
  String get architectWallDrawPrompt => 'Tap to start wall, tap again to place';

  @override
  String get architectView2D => '2D Plan';

  @override
  String get architectView3D => '3D Model';

  @override
  String get architectResetView => 'Reset View';

  @override
  String get architectCreateProject => 'Create Project';

  @override
  String get architectToolZone => 'Zones';

  @override
  String get architectZoneDragPrompt => 'Drag to draw room zone';

  @override
  String get architectZoneDrawPrompt => 'Points → close';

  @override
  String get architectZoneTapFirstPoint =>
      'Tap canvas to place start point (1)';

  @override
  String architectZoneNextPointPrompt(int count) {
    return 'Point $count: Tap for next point or select 1 to close';
  }

  @override
  String get architectZoneClose => 'Finish';

  @override
  String get architectZoneUndoPoint => 'Undo Point';

  @override
  String get architectZoneCancelDraft => 'Cancel';

  @override
  String get architectZonePointSnapStart => 'Close zone (1st point)';

  @override
  String get architectZoneSelfIntersectError =>
      'Self-intersecting polygon boundary is not allowed';

  @override
  String get architectZoneMinPointsError => 'A zone requires at least 3 points';

  @override
  String architectZoneExtrudeOffset(String dist) {
    return 'Extruded edge: $dist m';
  }

  @override
  String architectZoneCleaned(int count) {
    return 'Removed $count redundant/orphan vertices';
  }

  @override
  String architectZonePointsCount(int count) {
    return 'Points: $count';
  }

  @override
  String get architectZoneAlignH => 'Straightened 0°';

  @override
  String get architectZoneAlignV => 'Straightened 90°';

  @override
  String architectZoneCreated(String name, String area) {
    return 'Zone $name ($area m²) created';
  }

  @override
  String get architectZoneDeleted => 'Zone deleted';

  @override
  String get architectZoneMerged => 'Corners merged';

  @override
  String get architectZoneProperties => 'Zone Properties';

  @override
  String get architectZoneName => 'Room Name';

  @override
  String get architectZoneCategory => 'Category';

  @override
  String get architectZoneTargetArea => 'Target Area';

  @override
  String get architectZoneAreaLabel => 'Area';

  @override
  String get architectZonePerimeterLabel => 'Perimeter';

  @override
  String get architectDeleteZone => 'Delete Zone';

  @override
  String get architectZoneAutoAlign => 'Straighten Angles (90°)';

  @override
  String get architectZoneUndoAlign => 'Undo Straighten';

  @override
  String get architectZoneAutoAlignSuccess => 'Angles straightened to 90°';

  @override
  String get architectZoneRotate => 'Rotation';

  @override
  String get architectZoneMove => 'Move Zone';

  @override
  String get architectZoneOffset => 'Offset';

  @override
  String get architectZoneSave => 'Save';

  @override
  String get architectZoneCancel => 'Cancel';

  @override
  String get architectZoneEditMode => 'Zone Edit & Transform';

  @override
  String get architectZoneUndoAction => 'Undo';

  @override
  String get architectZoneRedoAction => 'Redo';

  @override
  String architectZoneMovedDistance(String dist) {
    return 'Moved: $dist m';
  }

  @override
  String get architectZoneQuickRect => 'Rectangle';

  @override
  String get architectZoneQuickPoly => 'Freeform';

  @override
  String get architectZoneNumber => 'Room No.';

  @override
  String get architectZoneNumberPrompt => 'No.';

  @override
  String get architectZoneFinishes => 'Room Finishes';

  @override
  String get architectZoneFloorFinish => 'Floor Finish';

  @override
  String get architectZoneWallFinish => 'Wall Finish';

  @override
  String get architectZoneCeilingFinish => 'Ceiling Finish';

  @override
  String get architectZoneClearHeight => 'Clear Height (m)';

  @override
  String get architectZoneBoundaryAuto => 'Auto Boundaries';

  @override
  String get architectZoneBoundaryAutoDesc =>
      'Dynamically conforms when walls change';

  @override
  String get architectZoneBoundaryManual => 'Manual Correction';

  @override
  String get architectZoneBoundaryManualDesc =>
      'Fixed boundaries without dynamic updates';

  @override
  String get architectZoneModeAuto => 'Auto';

  @override
  String get architectZoneModeManual => 'Manual';

  @override
  String get architectZoneAutoPrompt =>
      'Tap inside an enclosed room to auto-detect boundary';

  @override
  String get architectZoneAutoFailed => 'Room is not fully enclosed by walls';

  @override
  String get architectZoneMergeDialogTitle => 'Merge Rooms';

  @override
  String architectZoneMergeDialogMessage(String zoneA, String zoneB) {
    return 'The separating wall between \"$zoneA\" and \"$zoneB\" was removed. Would you like to merge them into a single room?';
  }

  @override
  String get architectZoneMergeConfirm => 'Merge Rooms';

  @override
  String get architectZoneMergeKeepSeparate => 'Keep Separate';

  @override
  String architectZoneMergedSuccess(String name) {
    return 'Rooms merged into $name';
  }

  @override
  String get architectZoneScheduleTitle => 'Room Schedule';

  @override
  String get architectZoneScheduleTotalArea => 'Total Net Area';

  @override
  String get architectZoneScheduleRoomCount => 'Rooms Count';

  @override
  String get architectZoneSchedulePlaceOnDrawing => 'Place on Drawing';

  @override
  String get architectZoneScheduleRemoveFromDrawing => 'Remove from Drawing';

  @override
  String get architectZoneScheduleTablePlaced =>
      'Schedule table placed on drawing';

  @override
  String get architectZoneScheduleCopy => 'Copy Schedule';

  @override
  String get architectZoneScheduleCopied => 'Room schedule copied to clipboard';

  @override
  String get architectZoneScheduleNoRooms =>
      'No zones created in active storey';

  @override
  String get architectZoneScheduleColNo => '№';

  @override
  String get architectZoneScheduleColName => 'Room';

  @override
  String get architectZoneScheduleColArea => 'Area (m²)';

  @override
  String get architectZoneScheduleColPerimeter => 'Perim. (m)';

  @override
  String get architectZoneScheduleColFloor => 'Floor';

  @override
  String get architectZoneScheduleColWalls => 'Walls';

  @override
  String get architectZoneScheduleColCeiling => 'Ceiling';

  @override
  String get architectZoneScheduleColHeight => 'H (m)';

  @override
  String get architectToolZoneTable => 'Zone Table';

  @override
  String get architectToolZoneTableTooltip =>
      'Place room schedule table on canvas';

  @override
  String get architectZoneTableBarTitle => 'Room Schedule Table';

  @override
  String get architectZoneTableBarHint =>
      'Click on the drawing to place the table';

  @override
  String get architectZoneTableBarMoveHint =>
      'Drag table on canvas to reposition';

  @override
  String get architectZoneTablePlaced => 'Table placed on drawing';

  @override
  String get architectZoneTableRemoved => 'Table removed from drawing';

  @override
  String get architectZoneTableRemove => 'Remove Table';

  @override
  String get architectZoneTableBackToZones => 'Back to Rooms';

  @override
  String get architectZoneTableActionPlace => 'Place Table';

  @override
  String get architectZoneFloorLaminate => 'Laminate';

  @override
  String get architectZoneFloorGranite => 'Porcelain tile';

  @override
  String get architectZoneFloorTerracotta => 'Terracotta';

  @override
  String get architectZoneFloorParquet => 'Parquet';

  @override
  String get architectZoneFloorCarpet => 'Carpet';

  @override
  String get architectZoneFloorConcrete => 'Polished Concrete';

  @override
  String get architectZoneWallLatex => 'Latex paint';

  @override
  String get architectZoneWallFaience => 'Faience';

  @override
  String get architectZoneWallPlaster => 'Dec. plaster';

  @override
  String get architectZoneWallWallpaper => 'Wallpaper';

  @override
  String get architectZoneWallExposedBrick => 'Exposed Brick';

  @override
  String get architectZoneCeilingLatex => 'Latex paint';

  @override
  String get architectZoneCeilingGypsum => 'Gypsum Board';

  @override
  String get architectZoneCeilingSuspended => 'Suspended Ceiling';

  @override
  String get architectZoneCeilingConcrete => 'Exposed Concrete';

  @override
  String get staircaseAutoGenerate => 'Generate stair openings';

  @override
  String staircaseAutoAdded(int count) {
    return 'Stair openings added: $count';
  }

  @override
  String get staircaseAutoExisting => 'The stair openings are already placed.';

  @override
  String get staircaseAutoNotFound =>
      'No opening was found. Draw it with the Staircase tool.';

  @override
  String staircaseAutoMissing(String levels) {
    return 'Missing stair opening at $levels.';
  }

  @override
  String get bimToolGroupUnderlay => 'Underlay';

  @override
  String get bimToolGroupStructure => 'Structure';

  @override
  String get bimToolGroupChecks => 'Checks';

  @override
  String get bimGenerateSupportsAction => 'Generate columns and walls';

  @override
  String get bimSupportSpacingAction => 'Spacing';

  @override
  String get architectToolAxis => 'Axes';

  @override
  String get architectAxisDrawPrompt =>
      'Tap start and end points to draw an axis';

  @override
  String get architectAxesResequenced => 'Axes resequenced successfully';

  @override
  String get architectAxesAligned => 'Axes extents aligned';

  @override
  String get architectAxisAligned => 'Axis aligned with parallel axes';

  @override
  String architectAxisRenamed(String name) {
    return 'Axis renamed to $name';
  }

  @override
  String get resequenceGridAxesAction => 'Resequence Axes';

  @override
  String get alignGridAxesAction => 'Align All Axes';

  @override
  String get alignGridAxisAction => 'Align Extents';

  @override
  String get architectAxisOrientationV => 'Vertical';

  @override
  String get architectAxisOrientationH => 'Horizontal';

  @override
  String get architectAxisDeleted => 'Axis deleted';

  @override
  String get architectAxisMoved => 'Axis moved';

  @override
  String get architectDebugLogs => 'Diagnostic Logs';

  @override
  String get architectClearLogs => 'Clear Logs';

  @override
  String get architectCopyLogs => 'Copy';

  @override
  String get architectNoLogs => 'No logs recorded yet';

  @override
  String architectDoorPlaced(String specId, int width, int height) {
    return 'Door $specId ($width/$height) placed';
  }

  @override
  String get bimProjectType => 'Project Type';

  @override
  String get bimProjectStructural => 'Structural BiM';

  @override
  String get bimProjectArchitectural => 'Architectural BiM';

  @override
  String get bimProjectStructuralDesc =>
      'Load-bearing elements, columns, beams, shear walls, slabs, seismic & load analysis';

  @override
  String get bimProjectArchitecturalDesc =>
      'Walls, doors, windows, spaces, finishes, stairs, full architectural drafting';

  @override
  String get bimProjectFilterAll => 'All';

  @override
  String get bimProjectFilterStructural => 'Structural';

  @override
  String get bimProjectFilterArchitectural => 'Architectural';

  @override
  String get architectToolWindow => 'Window';

  @override
  String get architectToolColumn => 'Column';

  @override
  String get architectToolBeam => 'Beam';

  @override
  String get architectToolSlab => 'Slab';

  @override
  String get architectToolOpening => 'Opening';

  @override
  String get architectToolStair => 'Stairs';

  @override
  String get architectToolDimension => 'Dimension';

  @override
  String get architectToolLevel => 'Level';

  @override
  String get architectToolText => 'Text';

  @override
  String get architectToolCadLine => 'Line';

  @override
  String get architectToolCadRect => 'Rectangle';

  @override
  String get architectToolCadCircle => 'Circle';

  @override
  String get architectWindowWidth => 'Width';

  @override
  String get architectWindowHeight => 'Window Height';

  @override
  String get architectWindowSill => 'Sill';

  @override
  String get architectWindowFlipSide => 'Flip exterior/interior side';

  @override
  String get architectColumnShape => 'Shape';

  @override
  String get architectColumnRect => 'Rect.';

  @override
  String get architectColumnCircle => 'Circular';

  @override
  String get architectColumnSize => 'Size';

  @override
  String get architectBeamSize => 'Size';

  @override
  String get architectStairWidth => 'Width';

  @override
  String get architectStairSteps => 'Steps';

  @override
  String get architectOpeningType => 'Type';

  @override
  String get architectOpeningShaft => 'Shaft';

  @override
  String get architectOpeningVoid => 'Slab';

  @override
  String get architectLevelElevation => 'Elevation';

  @override
  String get architectAnnotationText => 'Text';

  @override
  String get architectUnderlayToggle => 'CAD Underlay';

  @override
  String architectWindowPlaced(String specId, int width, int height) {
    return 'Window $specId ($width/$height) placed';
  }

  @override
  String architectColumnPlaced(String label) {
    return 'Column $label placed';
  }

  @override
  String get architectBeamPlaced => 'Beam placed';

  @override
  String get architectStairPlaced => 'Stairs placed';

  @override
  String get architectOpeningPlaced => 'Opening placed';

  @override
  String get architectDimensionPlaced => 'Dimension line placed';

  @override
  String get architectLevelPlaced => 'Level marker placed';

  @override
  String get architectAnnotationPlaced => 'Annotation placed';

  @override
  String get architectCadShapePlaced => 'CAD shape placed';

  @override
  String get architectCategoryStructure => 'Structure';

  @override
  String get architectCategorySpaces => 'Spaces';

  @override
  String get architectCategoryAnnotations => 'Notes';

  @override
  String get architectCategoryCad => 'Drafting';

  @override
  String selectedElement(String id) {
    return 'Selected: $id';
  }

  @override
  String get architectWizardTitle => 'New Architectural Project';

  @override
  String get architectWizardSubtitle => 'Quick parametric project setup';

  @override
  String get architectWizardSectionStoreys => 'Storeys & Heights';

  @override
  String get architectWizardSectionGrid => 'Structural Grid (Axes)';

  @override
  String get architectWizardSectionWalls => 'Wall Types & Balcony Parapet';

  @override
  String get architectWizardParapetTitle => 'Balcony Parapet (12 cm curb)';

  @override
  String architectWizardParapetHeightInfo(String height, String level) {
    return 'Code height: $height m ($level)';
  }

  @override
  String get architectWizardParapetUnder5 => 'up to 5th storey';

  @override
  String get architectWizardParapetOver5 => 'above 5th storey / >20m';

  @override
  String get architectWizardParapetFinishCap => 'With Coping Cap';

  @override
  String get architectWizardParapetFinishPipe =>
      'With Handrail Pipe on Posts (+15 cm)';

  @override
  String get architectWizardCreateAction => 'Create Project & Start';

  @override
  String get wallTypeExt25Eps12 => 'Exterior 25+12 EPS (37 cm)';

  @override
  String get wallTypeInt12Partition => 'Partition 12 cm';

  @override
  String get wallTypeExt25Brick => 'Brick 25 cm (no insulation)';

  @override
  String get wallTypeBearing25 => 'Concrete Shear Wall 25 cm';

  @override
  String get wallTypeParapet12 => 'Balcony Parapet 12 cm';

  @override
  String get architectDefaultProjectName => 'Architectural Project';

  @override
  String architectStoreyCountChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Storeys',
      one: '1 Storey',
    );
    return '$_temp0';
  }

  @override
  String get architectLaunchWizard => 'Start with Architectural Wizard';

  @override
  String get architectUnitMm => 'Millimeters (mm)';

  @override
  String get architectUnitFeet => 'Feet (ft)';

  @override
  String get architectUnitInches => 'Inches (in)';

  @override
  String get architectUnitSystem => 'Dimensions System';

  @override
  String get architectUnitSystemMetric => 'Metric (m, cm, mm)';

  @override
  String get architectUnitSystemImperial => 'Imperial (ft, in)';

  @override
  String get architectWizardStep1 => '1. Units';

  @override
  String get architectWizardStep2 => '2. Axes';

  @override
  String get architectWizardStep3 => '3. Storeys';

  @override
  String get architectWizardStep1Subtitle =>
      'Project name and dimensions system';

  @override
  String get architectWizardStep2Subtitle => 'Grid axes and spacing';

  @override
  String get architectWizardStep3Subtitle => 'Storey elevations and heights';

  @override
  String get architectWizardNext => 'Next';

  @override
  String get architectWizardBack => 'Back';

  @override
  String get architectWallCore => 'Core thickness';

  @override
  String get architectWallInsulation => 'EPS Insulation';

  @override
  String architectWallTotalThickness(String thickness) {
    return 'Total: $thickness';
  }

  @override
  String get architectParapetCurb => 'Curb thickness';

  @override
  String get architectParapetHeightLabel => 'Parapet height';

  @override
  String get architectWallLength => 'Length';

  @override
  String get architectWallDirection => 'Direction';

  @override
  String get architectWallEnd => 'End';

  @override
  String get architectWallContinue => 'Next';

  @override
  String get architectWallReferenceCenter => 'Axis';

  @override
  String get architectWallReferenceLeft => 'Left';

  @override
  String get architectWallReferenceRight => 'Right';

  @override
  String get architectWallInsertPoint => 'Point';

  @override
  String get architectWallParallelHelp =>
      'Tap to move across the wall without changing its angle. Hold to enter a signed offset.';

  @override
  String architectWallEndpointValue(int endpoint, String distance) {
    return '$endpoint · $distance';
  }

  @override
  String get architectWallEndpointClearance => 'End offset';

  @override
  String get architectMagnetHelp => 'Snap to walls, axes and drawing points.';

  @override
  String get architectWallParallel => 'Parallel';

  @override
  String get architectWallDraftHint => 'Hold → point · 2 fingers → zoom';

  @override
  String get architectColumnPlacementHint =>
      'Hold → place · Tap → select · X → cancel';

  @override
  String get architectEditHoldHint => 'Hold → edit · longer → menu';

  @override
  String get architectNavigationHint => 'Pan / zoom';

  @override
  String get architectWallEditRejected => 'Opening or wall too short.';

  @override
  String get architectSaveFailed => 'Save failed. Check storage.';

  @override
  String get architectWallExterior => 'Exterior';

  @override
  String get architectWallPartition => 'Partition';

  @override
  String get architectWallBrick => 'Brick';

  @override
  String get architectWallConcrete => 'Concrete';

  @override
  String get architectWallParapet => 'Parapet';

  @override
  String get architectWallReferenceInner => 'Inside';

  @override
  String get architectWallReferenceOuter => 'Outside';

  @override
  String get architectWallFlipSide => 'Flip exterior side';

  @override
  String get architectSelectionMulti => 'Multi';

  @override
  String get architectSelectionMove => 'Drag';

  @override
  String get architectSelectConnected => 'Connected';

  @override
  String get architectSelectSimilar => 'All of type';

  @override
  String get architectContextMenu => 'Menu';

  @override
  String architectSelectionCount(int count) {
    return '$count items';
  }

  @override
  String architectSelectionWallsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count walls',
      one: '1 wall',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionColumnsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columns',
      one: '1 column',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionBeamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beams',
      one: '1 beam',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionSlabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slabs',
      one: '1 slab',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionMixedSummary(int count, String details) {
    return '$count items: $details';
  }

  @override
  String get architectDeselect => 'Deselect';

  @override
  String get architectProperties => 'Properties';

  @override
  String get architectWallExtend => 'Extend';

  @override
  String get architectWallJoin => 'Join';

  @override
  String get architectOperationRejected => 'Cannot apply here.';

  @override
  String get architectPropertyHeight => 'Height';

  @override
  String get architectPropertyWidth => 'Width';

  @override
  String get architectPropertyDepth => 'Depth';

  @override
  String get architectPropertyThickness => 'Thk.';

  @override
  String get architectPropertyCore => 'Core';

  @override
  String get architectPropertyInsulation => 'Insul.';

  @override
  String get architectPropertyAngle => 'Angle';

  @override
  String get architectPropertySteps => 'Steps';

  @override
  String get architectPropertySill => 'Sill';

  @override
  String get architectPropertyOffset => 'Offset';

  @override
  String get architectPropertyBaseOffset => 'Base H';

  @override
  String get architectPropertyCutDisplay => 'Cut View';

  @override
  String get architectCutDisplayAuto => 'Auto';

  @override
  String get architectCutDisplayProjected => 'Projected';

  @override
  String get architectCutDisplayCut => 'Cut';

  @override
  String get architectCutDisplayOverhead => 'Overhead';

  @override
  String get architectStoreyCutPlane => 'Cut H';

  @override
  String get architectPropertySize => 'Size';

  @override
  String get architectPropertyName => 'Name';

  @override
  String get architectWallExtendHint => 'Pick target';

  @override
  String get architectWallCut => 'Cut';

  @override
  String get architectWallCutHint => 'Tap the part between crossings';

  @override
  String get architectWallDetach => 'Detach';

  @override
  String get architectWallAttach => 'Attach';

  @override
  String get architectWallMagnet => 'Magnet';

  @override
  String get architectWallAlign => 'Align';

  @override
  String get architectWallMirror => 'Flip';

  @override
  String get architectWallSplit => 'Split';

  @override
  String get architectWallSplitHint => 'Split: two points across walls';

  @override
  String get architectWallSplitSurfaceHint => 'Click to confirm surface';

  @override
  String get architectWallSplitDirectionHint => 'Click for cut direction';

  @override
  String get architectWallSplitPromptPickFirst => 'Specify first split point';

  @override
  String get architectWallSplitPromptPickSecond => 'Specify second split point';

  @override
  String get architectWallSplitPromptPickSide =>
      'Click the side to keep selected';

  @override
  String get architectWallSplitPerpendicular => 'Perpendicular';

  @override
  String get architectWallSplitSide1 => 'Side 1';

  @override
  String get architectWallSplitSide2 => 'Side 2';

  @override
  String get architectWallSplitBoth => 'Both';

  @override
  String get architectWallClearance => 'Clearance';

  @override
  String get architectGridNone => 'None';

  @override
  String get architectGridCustom => 'Custom';

  @override
  String architectGridBays(int x, int y) {
    return 'Bays $x × $y';
  }

  @override
  String get architectGridPickerHelp =>
      'Drag to choose bays. Each direction has one more axis than bays. Tap a dimension on the grid to edit it.';

  @override
  String get architectGridFewer => 'Fewer bays';

  @override
  String get architectGridMore => 'More bays';

  @override
  String get architectWizardUnitsShort => 'Units';

  @override
  String get architectWizardGridShort => 'Axes';

  @override
  String get architectWizardWallsShort => 'Walls';

  @override
  String get architectWizardTitleShort => 'New project';

  @override
  String architectGridSpanLabel(String axes, String value) {
    return 'Spacing $axes: $value';
  }

  @override
  String get architectGridParkingHelp => 'Parking grid';

  @override
  String get architectGridResidentialHelp => 'Residential grid';

  @override
  String get architectGridVillaHelp => 'House grid';

  @override
  String get architectGridModularHelp => 'Office grid';

  @override
  String get architectGridNoneHelp => 'Start without axes';

  @override
  String get architectRadius => 'Radius';

  @override
  String get architectShapeWidth => 'Width';

  @override
  String get architectShapeHeight => 'Height';

  @override
  String get architectFenestrationEditor => 'Window & Door Designer';

  @override
  String get architectFenestrationCreateNew => 'Create New';

  @override
  String get architectFenestrationEditStyle => 'Edit Model';

  @override
  String get architectFenestrationStyle => 'Opening Model';

  @override
  String get architectFenestrationSave => 'Save to Library';

  @override
  String get architectFenestrationSaveSuccess => 'Model saved to library';

  @override
  String get architectFenestrationLibrary => 'Openings Library';

  @override
  String get architectFenestrationCasing => 'Trim / Casing';

  @override
  String get architectFenestrationCasingWidth => 'Casing Width';

  @override
  String get architectFenestrationCasingProjection => 'Casing Projection';

  @override
  String get architectFenestrationCasingPlacement => 'Casing Position';

  @override
  String get architectFenestrationCasingExterior => 'Exterior';

  @override
  String get architectFenestrationCasingInterior => 'Interior';

  @override
  String get architectFenestrationCasingBoth => 'Both Sides';

  @override
  String get architectFenestrationFrame5Chamber => '5-Chamber Frame (70 mm)';

  @override
  String get architectFenestrationFrameFaceWidth => 'Frame Face';

  @override
  String get architectFenestrationGlazingDouble => 'Double Glazing (24 mm)';

  @override
  String get architectFenestrationGlazingThickness => 'Glazing Thickness';

  @override
  String get architectFenestrationSplitH => 'Split Horizontally';

  @override
  String get architectFenestrationSplitV => 'Split Vertically';

  @override
  String get architectFenestrationRemoveSplit => 'Remove Split';

  @override
  String get architectFenestrationPaneType => 'Pane Type';

  @override
  String get architectFenestrationPaneFixed => 'Fixed Glazing';

  @override
  String get architectFenestrationPaneTurnLeft => 'Casement Left';

  @override
  String get architectFenestrationPaneTurnRight => 'Casement Right';

  @override
  String get architectFenestrationPaneTiltTurn => 'Tilt & Turn';

  @override
  String get architectFenestrationPaneTopHopper => 'Top Hopper';

  @override
  String get architectFenestrationPaneDoorLeaf => 'Door Leaf';

  @override
  String get architectFenestrationPaneSolidPanel => 'Solid Panel';

  @override
  String get architectFenestrationDimensions => 'Dimensions';

  @override
  String get architectFenestrationProfile => 'Profile & Glass';

  @override
  String get architectFenestrationDivisions => 'Raster & Panes';

  @override
  String get architectFenestrationPresets => 'Presets';

  @override
  String get architectFenestrationViewElevation => 'Elevation';

  @override
  String get architectFenestrationView3D => '3D View';

  @override
  String get architectFenestrationViewPlan => 'Plan (2D)';

  @override
  String get architectFenestrationIncludeBottomCasing =>
      'Include Bottom Casing';

  @override
  String get architectFenestrationWallContextHelp =>
      'Casing sits on exterior face of wall & insulation without cutting wall';

  @override
  String get architectFenestrationApplyToProject => 'Apply to Project';

  @override
  String get architectFenestrationCustom => 'Custom';

  @override
  String get architectFenestrationPreset => 'Standard Preset';

  @override
  String get architectFenestrationSelectStyle => 'Select Opening Model';

  @override
  String get architectFenestrationStep1 => '1. Frame & Grid';

  @override
  String get architectFenestrationStep2 => '2. Operability';

  @override
  String get architectFenestrationStep3 => '3. Infill & Muntins';

  @override
  String get architectFenestrationNextStep => 'Next Step';

  @override
  String get architectFenestrationPrevStep => 'Previous Step';

  @override
  String get architectFenestrationMuntins => 'Muntins / Glazing Bars';

  @override
  String get architectFenestrationMuntinCols => 'Vertical Muntins';

  @override
  String get architectFenestrationMuntinRows => 'Horizontal Muntins';

  @override
  String get architectFenestrationMuntinWidth => 'Muntin Width';

  @override
  String get architectFenestrationMuntinNone => 'No Muntins';

  @override
  String get architectFenestrationMuntinClassic => 'Classic 2x2';

  @override
  String get architectFenestrationMuntinVictorian => 'Georgian 2x3';

  @override
  String get architectFenestrationMuntinGrid3x3 => 'Grid 3x3';

  @override
  String get architectFenestrationSashProfile => 'Inner Sash Frame';

  @override
  String get architectFenestrationExactDimension => 'Set Exact Dimension';

  @override
  String get architectFenestrationLeafWidth => 'Leaf Width';

  @override
  String get architectFenestrationLeafHeight => 'Leaf Height';

  @override
  String get architectFenestrationInfillGlazing => 'Glazing (Glass)';

  @override
  String get architectFenestrationInfillSolid => 'Solid Panel';

  @override
  String get architectFenestrationAddTransom => 'Add Transom (Horiz.)';

  @override
  String get architectFenestrationAddMullion => 'Add Mullion (Vert.)';

  @override
  String get architectFenestrationSelectedLeaf => 'Selected Pane';

  @override
  String get architectFenestrationCasingColor => 'Casing Color';

  @override
  String get architectFenestrationMountingPlane => 'Mounting Plane';

  @override
  String get architectFenestrationMountingPlaneHelp =>
      'Centered inside brick core with exterior casing trim';

  @override
  String get architectFenestrationWithCasing => 'With casing';

  @override
  String get architectRadialMove => 'Drag';

  @override
  String get snapAlignPoint1 => 'Alignment with Point 1';

  @override
  String get architectRadialEdit => 'Edit';

  @override
  String get architectRadialDelete => 'Delete';

  @override
  String get architectRadialDuplicate => 'Duplicate';

  @override
  String get architectRadialRename => 'Rename';

  @override
  String get architectRadialRotate => 'Rotate';

  @override
  String get architectRadialFlip => 'Flip';

  @override
  String get architectRadialProperties => 'Properties';

  @override
  String get architectRadialSplit => 'Split';

  @override
  String get architectRadialCut => 'Cut';

  @override
  String get architectRadialOffset => 'Offset';

  @override
  String get architectMirrorMove => 'Mirror';

  @override
  String get architectMirrorMoveTooltip => 'Mirror move';

  @override
  String get architectMirrorCopy => 'Mirror+';

  @override
  String get architectMirrorCopyTooltip => 'Mirror copy';

  @override
  String get architectMirrorPromptPickAnchor => 'Pick mirror anchor';

  @override
  String get architectMirrorPromptPickAxis => 'Pick second axis point';

  @override
  String get architectMirrorAxisVertical => 'Vertical';

  @override
  String get architectMirrorAxisHorizontal => 'Horizontal';

  @override
  String get architectEdgeDistance => 'Distance';

  @override
  String get architectEdgeSelectHint => 'Select an edge';

  @override
  String get architectEdgeDistanceHint =>
      'Set the distance by moving the selected edge.';

  @override
  String get architectEdgeMoveHint =>
      'Move the edge parallel to itself, with both endpoints.';

  @override
  String get architectEdgePullHint =>
      'Pull the edge and retain its original corners.';

  @override
  String get dragDuplicateAction => 'Drag+';

  @override
  String get dragDuplicateHint => 'Drag to place the copy';

  @override
  String get structuralBeamNamePrefix => 'B';

  @override
  String get bimUnderlayReviewCompleteAction => 'Reviewed';

  @override
  String get bimUnderlayReviewCompleteTooltip =>
      'Mark the preserved elements and openings as reviewed';

  @override
  String get bimNewPoint => 'New point';

  @override
  String get bimNewPointHint =>
      'Specify position along the edge for the new point';

  @override
  String get architectNewPointPrompt =>
      'Specify position along the edge for the new point';

  @override
  String get bimWallNewPointHelp =>
      'Adds connected wall segments. Split cuts and disconnects them.';

  @override
  String get architectCanvasLight => 'Light background';

  @override
  String get architectCanvasDark => 'Dark background';

  @override
  String get architectWallType => 'Wall type';

  @override
  String get architectWallFollowStorey => 'Follow storey';

  @override
  String get architectWallLeadingLine => 'Leading line';

  @override
  String get architectWallCoreThickness => 'Core thickness';

  @override
  String get architectPropertyTotal => 'Total';

  @override
  String get architectMaterialBrick => 'Brick';

  @override
  String get architectMaterialConcrete => 'Concrete';

  @override
  String get architectMaterialTimber => 'Timber';

  @override
  String get architectMaterialPanel => 'Thermal panel';

  @override
  String get architectInsulationXps => 'XPS';

  @override
  String get architectInsulationEps => 'EPS';

  @override
  String get architectInsulationStoneWool => 'Stone wool';

  @override
  String get architectSettings => 'Settings';

  @override
  String get architectGhostStoreys => 'Ghost storeys';

  @override
  String get architectUpperOverhangs => 'Upper floor erkers & balconies';

  @override
  String get architectUpperOverhangsHelp =>
      'Automatically display erkers and balconies from the floor above as dashed lines';

  @override
  String get architectOverhangErker => 'Erker';

  @override
  String get architectOverhangBalcony => 'Balcony';

  @override
  String get architectDrawingGrid => 'Grid';

  @override
  String get architectSnap => 'Snap';

  @override
  String get architectHandleOffsetLength => 'Handle leader line length';

  @override
  String get architectAxesWallThickness => 'Wall core for axes';

  @override
  String get architectAxesFromWallsHelp =>
      'Create axes through wall cores on this storey. Set the core thickness in Settings.';

  @override
  String get architectAxesNoMatchingWalls =>
      'No walls match the selected core thickness.';

  @override
  String architectAxesGenerated(int count) {
    return 'Added $count axes';
  }

  @override
  String get architectDimensionChain => 'Chain';

  @override
  String get architectDimensionScale => 'Dimension scale';

  @override
  String get architectDimensionSingle => 'Single';

  @override
  String get architectDimensionExterior => 'Exterior';

  @override
  String get architectDimensionExteriorHelp =>
      'Rows: openings, wall sections, overall core size with separate end insulation, axes. Row spacing follows drawing scale and text size. Facade openings and perpendicular axes are included automatically; picks on insulation reference the core.';

  @override
  String get architectDimensionInterior => 'Interior';

  @override
  String get architectDimensionInteriorHint =>
      'Select end walls and partitions, then position the line.';

  @override
  String get architectDimensionInteriorHelp =>
      'One row measures between the inner faces of parallel end walls, including both faces of intermediate partitions.';

  @override
  String get architectDimensionAddWalls => 'Add walls';

  @override
  String get architectDimensionEditPoints => 'Edit points';

  @override
  String get architectDimensionEditPointsHint =>
      'Tap a wall to add it, or a minus to remove it. The green check saves.';

  @override
  String get architectDimensionRemoveReference => 'Remove from dimension';

  @override
  String get architectDimensionKeepReferences =>
      'Add another reference before removing this one; a dimension needs two distinct endpoints.';

  @override
  String get architectDimensionConfirm => 'Save the displayed dimension';

  @override
  String get architectDimensionAddWallsHint =>
      'Select missing parallel walls, then confirm. The dimension line stays in place.';

  @override
  String get architectDimensionStartHint => 'Select the first measured point.';

  @override
  String get architectDimensionEndHint =>
      'Select the second measured point, then position the dimension line.';

  @override
  String get architectDimensionContinue => 'Continue';

  @override
  String get architectDimensionFinish => 'Finish';

  @override
  String get architectDimensionPlace => 'Place';

  @override
  String get architectDimensionChainHint =>
      'Select walls or points. Green check saves; minus removes a reference.';

  @override
  String get architectDimensionDirectionHint =>
      'Select a wall or line parallel to the dimension line.';

  @override
  String get architectDimensionPositionHint =>
      'Tap to position the dimension line, or enter an exact offset.';

  @override
  String get architectSelectionCycleHelp =>
      'Tap to add or remove; repeated taps cycle overlaps. Hold for actions.';

  @override
  String get architectDimensionOverall => 'Overall dimension';

  @override
  String get architectDimensionSnap30cm => '30 cm';

  @override
  String get architectDimensionSnap40cm => '40 cm';

  @override
  String get architectDimensionNewPoint => 'New point';

  @override
  String get architectStoreyGround => 'Ground Floor';

  @override
  String get architectStoreyFloor => 'Floor';

  @override
  String architectSelectionDoorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doors',
      one: '1 door',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionWindowsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionZonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones',
      one: '1 zone',
    );
    return '$_temp0';
  }

  @override
  String architectSelectionAxesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count axes',
      one: '1 axis',
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
  String get snapCorner => 'Corner';

  @override
  String get snapEdge => 'Edge';

  @override
  String get snapMerge => 'Merge';

  @override
  String get snapDoorJamb => 'Door jamb';

  @override
  String get snapWindowJamb => 'Window jamb';

  @override
  String get architectDoorSillNone => 'Sill: 0';

  @override
  String get architectDoorSillStep => 'Step: 15 cm';

  @override
  String get architectZoneCatLiving => 'Living Room';

  @override
  String get architectZoneCatBedroom => 'Bedroom';

  @override
  String get architectZoneCatKitchen => 'Kitchen';

  @override
  String get architectZoneCatCorridor => 'Corridor / Hall';

  @override
  String get architectZoneCatBathroom => 'Bathroom / WC';

  @override
  String get architectZoneCatTerrace => 'Terrace / Balcony';

  @override
  String get architectZoneCatStorage => 'Storage / Utility';

  @override
  String get architectZoneCatOffice => 'Home Office';

  @override
  String get architectZoneCatCustom => 'Custom Space';

  @override
  String get architectFenestrationPresetSingleCasement =>
      'Single casement 80/140 (5-chamber)';

  @override
  String get architectFenestrationPresetDoubleCasement =>
      'Double casement 140/140 (5-chamber)';

  @override
  String get architectFenestrationPresetDoubleWithCasing =>
      'Double casement 140/140 with casing';

  @override
  String get architectFenestrationPresetTripleCasement =>
      'Triple casement 210/140 (fixed + 2 sashes)';

  @override
  String get architectFenestrationPresetWithTransom =>
      'Window with transom 140/180';

  @override
  String get architectFenestrationPresetDoorInterior => 'Interior door 90/200';

  @override
  String get architectFenestrationPresetDoorEntranceCasing =>
      'Entrance door with casing 100/210';

  @override
  String get architectFenestrationPresetDoorBalconyGlass =>
      'Glazed balcony door 90/210';

  @override
  String architectWallParapetPipe(int thickness, String height) {
    return 'Parapet $thickness cm (pipe h=${height}m)';
  }

  @override
  String architectWallParapetCap(int thickness, String height) {
    return 'Parapet $thickness cm (cap h=${height}m)';
  }

  @override
  String get stairShape => 'Shape';

  @override
  String get stairStraight => 'Straight';

  @override
  String get stairQuarterTurn => 'L-shaped';

  @override
  String get stairHalfTurn => 'U-shaped';

  @override
  String get stairSpiral => 'Spiral';

  @override
  String get stairSpiralOverlap => 'Overlapping spiral';

  @override
  String get stairWinders => 'Winder treads';

  @override
  String get stairWindersHelp =>
      'Replace the landing with winding treads. Automatically select the count and clear inner radius, targeting at least 23 cm on the line 30 cm from the narrow end. Code applicability depends on use and evacuation. Winders do not replace a landing required by flight rise.';

  @override
  String get stairWinderCorner => 'At corner';

  @override
  String get stairWinderCornerTread => 'Tread';

  @override
  String get stairWinderCornerRiser => 'Riser';

  @override
  String get stairWinderCornerHelp =>
      'Tread: one tread spans the outer corner. Riser: the boundary between two treads follows the angle bisector. Both layouts have a clear inner radius; supports and reinforcement require separate design.';

  @override
  String get stairWinderCount => 'Treads per 90°';

  @override
  String get stairWinderCountAuto => 'Automatic winder count';

  @override
  String get stairWinderRadiusAuto => 'Automatic winder radius';

  @override
  String get stairOverlapHelp =>
      'More than one revolution. Head clearance between overlapping parts accounts for concrete and finish thickness.';

  @override
  String get stairTurnLeft => 'Turn left';

  @override
  String get stairTurnRight => 'Turn right';

  @override
  String get stairPlaceHelp =>
      'Place the first riser, then point the ascent direction. Length and steps are calculated from the floor levels.';

  @override
  String get stairCode => 'Regulations';

  @override
  String get stairCodeBulgaria => 'Bulgaria · BG-2025.1';

  @override
  String get stairCodeGeometry => 'Geometry only';

  @override
  String get stairUse => 'Use';

  @override
  String get stairUsePrivate => 'Within a dwelling';

  @override
  String get stairUseCommon => 'New multifamily';

  @override
  String get stairUsePublic => 'Public building';

  @override
  String get stairUseAssembly => 'Public, over 200 people';

  @override
  String get stairUseOutdoor => 'New urban route';

  @override
  String get stairEvacuation => 'Evacuation';

  @override
  String get stairUnspecified => 'Unspecified';

  @override
  String get stairNoEvacuation => 'Not an escape stair';

  @override
  String get stairUpTo15 => 'Up to 15 people';

  @override
  String get stair16To50 => '16–50 people';

  @override
  String get stairOver50 => 'Over 50 people';

  @override
  String get stairRise => 'Total rise';

  @override
  String get stairFollowStoreys => 'From floor levels';

  @override
  String get stairHeightMode => 'Height';

  @override
  String get stairHeightManual => 'Manual';

  @override
  String get stairHeightModeHelp =>
      'From floor levels: calculate the rise from the specified start to the upper floor. Manual: enter the total rise; it stays fixed when floor levels change.';

  @override
  String get stairStartOffset => 'Start offset';

  @override
  String get stairStartOffsetHelp =>
      'Starting height relative to the floor level. 0 starts on the floor, positive values above it and negative values below it. Total rise is measured from this start.';

  @override
  String get stairUpperStorey => 'Upper floor';

  @override
  String get stairFloorHeight => 'Floor height';

  @override
  String get stairClearWidth => 'Clear width';

  @override
  String get stairRisers => 'Risers';

  @override
  String get stairRiser => 'Riser height';

  @override
  String get stairGoing => 'Going';

  @override
  String get stairLanding => 'Landing depth';

  @override
  String get stairInnerRadius => 'Clear inner radius';

  @override
  String get stairSweep => 'Turn angle';

  @override
  String get stairAutomatic => 'Auto';

  @override
  String get stairFit => 'Recalculate';

  @override
  String get stairFitHelp =>
      'Choose risers, going, width and inner radius for the selected profile. The existing height and direction are retained.';

  @override
  String get stairAdvanced => 'Dimensions';

  @override
  String get stairChecks => 'Checks';

  @override
  String get stairCheckPass => 'Pass';

  @override
  String get stairCheckError => 'Violation';

  @override
  String get stairCheckAdvice => 'Comfort advice';

  @override
  String get stairCheckReview => 'Not verified';

  @override
  String get stairDraft => 'Save as draft';

  @override
  String get stairDraftHelp =>
      'Drafts may contain violations and are drawn in red.';

  @override
  String get stairIncomplete =>
      'Geometric checks only. Headroom, handrails, finishes and the complete escape route require a project review.';

  @override
  String get stairCheckSlope => 'Flight slope';

  @override
  String get stairCheckFlightRise => 'Rise per flight';

  @override
  String get stairCheckInner30 => 'Going at 30 cm';

  @override
  String get stairCheckInner => 'Going at inner edge';

  @override
  String get stairCheckDiameter => 'Clear inner diameter';

  @override
  String get stairCheckComfort => 'Comfort · 2h + b';

  @override
  String get stairCheckCapacity => 'Escape capacity and fire class';

  @override
  String get stairCheckHeadroom => 'Headroom and floor opening';

  @override
  String get stairCheckHandrails => 'Guards and handrails';

  @override
  String get stairCheckFinishes => 'Nosings, tactile strips and finishes';

  @override
  String get stairCheckAccessibility => 'Accessible use of spiral treads';

  @override
  String get stairCheckScope => 'Additional applicable requirements';

  @override
  String get stairCheckVersion => 'Unrecognised rules version';

  @override
  String get stairCheckUpperStorey =>
      'Check upper level: missing floor or rise outside 0–30 m';

  @override
  String get stairRulesSources => 'Regulatory sources';

  @override
  String get stairFireSource => 'Fire safety · Iз-1971, consolidated 2025';

  @override
  String get stairAccessSource =>
      'Accessibility · РД-02-20-2/2021, Articles 18 and 55';

  @override
  String get stairClearDimensionsHelp =>
      'Use finished clear widths between limiting handrail projections. For a spiral, the inner radius starts at the limiting inner edge or handrail projection.';

  @override
  String get stairUnsupported =>
      'Invalid stair dimensions. Check the entered values.';

  @override
  String get stairLegacy =>
      'Schematic stair. Recalculate to convert it to a parametric stair.';

  @override
  String get stairCheckGroupSteps => 'Risers per group';

  @override
  String architectWallOvershootDetected(int distance) {
    return 'Wall overshoot: $distance cm';
  }

  @override
  String get architectWallOvershootTrim => 'Trim';

  @override
  String get architectWallOvershootDismiss => 'Keep';

  @override
  String architectWallOvershootTrimmed(int distance) {
    return 'Wall corner trimmed ($distance cm)';
  }

  @override
  String get architectWallOvershootTooltip =>
      'Trim protruding wall stub to corner';

  @override
  String get architectRadialJoin => 'Join';

  @override
  String get architectWallJoinTooltip => 'Join walls';

  @override
  String get architectWallJoinSelectSecond => 'Select second wall to join';

  @override
  String get architectWallJoinSuccess => 'Walls joined';

  @override
  String get architectWallJoinIncompatible => 'Walls cannot be joined';

  @override
  String get architectWallStraighten => 'Straighten';

  @override
  String get architectWallStraightened => 'Wall straightened';

  @override
  String get architectWallAlreadyStraight => 'Wall is already straight';

  @override
  String get stairRailing => 'Railing';

  @override
  String get stairSmartRailingHelp =>
      'Guard on open sides, handrail beside a full-height wall. Doors, windows and low walls keep the guard.';

  @override
  String get stairLabel => 'Label';

  @override
  String stairPlanStepsLabel(int count, String going, String riser) {
    return '${count}R $going/$riser cm';
  }

  @override
  String stairPlanRiseLabel(String height) {
    return 'H=$height m';
  }

  @override
  String get stairDetails => 'Detail';

  @override
  String get stairGuardHeight => 'Guard height';

  @override
  String get stairHandrailHeight => 'Handrail height';

  @override
  String get stairConcreteThickness => 'Concrete waist';

  @override
  String get stairFinishThickness => 'Finish';

  @override
  String get stairNosing => 'Nosing';

  @override
  String get stairDetailsHelp =>
      'Waist thickness is vertical. Drawing dimensions only; verify structural thickness, handrail clear width and the applicable regulations.';

  @override
  String get stairSection => 'Section';

  @override
  String get stairSectionHint =>
      'Pick two points in the plan to move and turn the section.';

  @override
  String get stairSectionReset => 'Reset section';

  @override
  String get stairSectionEmpty =>
      'The section misses the stair. Pick two new points in the plan.';

  @override
  String get stairSectionPlan => 'Section in plan';

  @override
  String get stairSectionCutHeight => 'Plan cut height';

  @override
  String get slabLayers => 'Layers';

  @override
  String get slabAssembly => 'Assembly';

  @override
  String get slabAbove => 'Above concrete';

  @override
  String get slabBelow => 'Below concrete';

  @override
  String get slabCore => 'Concrete';

  @override
  String get slabCoreOffset => 'Concrete top offset';

  @override
  String get slabFinishedLevel => 'Finished level';

  @override
  String get slabBottomLevel => 'Bottom level';

  @override
  String get slabPreset => 'Load assembly';

  @override
  String get slabAllUsages => 'All uses';

  @override
  String get slabOnlyThis => 'Only this slab';

  @override
  String get slabShared => 'Edit shared type';

  @override
  String get slabSharedHelp =>
      'Saving updates every slab using this type. Choose Only this slab to detach a copy.';

  @override
  String get slabNewType => 'New assembly';

  @override
  String get slabLibrary => 'Personal library';

  @override
  String get slabLibrarySaved => 'Assembly saved to library.';

  @override
  String get slabSaveLibrary => 'Save to library';

  @override
  String get slabLibraryFailed => 'Could not save the library.';

  @override
  String get slabPresetHelp =>
      'Editable starting dimensions, not a calculation for this building. Foundation: waterproofing below concrete; ground floor: waterproofing above concrete. Cold attic: non-walkable insulation. Ceiling insulation: suspended lining. Roof and terrace presets include one slope field; junctions and drainage need separate detailing.';

  @override
  String get slabAddLayer => 'Add layer';

  @override
  String get slabEditLayer => 'Layer';

  @override
  String get slabMaterial => 'Material';

  @override
  String get slabRole => 'Function';

  @override
  String get slabThicknessMm => 'Thickness (mm)';

  @override
  String get slabSlope => 'Slope (%)';

  @override
  String get slabDirection => 'Fall direction';

  @override
  String get slabDirectionHelp =>
      'Tap two points in the plan preview, from high to low.';

  @override
  String get slabDirectionRequired => 'Set a fall direction in the preview.';

  @override
  String get slabInvalid =>
      'Check dimensions, names and slope. Only one upper layer may have a slope.';

  @override
  String get slabDuplicate => 'Duplicate layer';

  @override
  String get slabMoveUp => 'Move up';

  @override
  String get slabMoveDown => 'Move down';

  @override
  String get slabFinish => 'Finish';

  @override
  String get slabFinishTile => 'Tiles';

  @override
  String get slabFinishParquet => 'Parquet';

  @override
  String get slabFinishWet => 'Wet room';

  @override
  String get slabNaturalGround => 'Natural ground';

  @override
  String get buildingSections => 'Sections';

  @override
  String get buildingSection => 'Section';

  @override
  String get buildingSectionNew => 'New section';

  @override
  String get buildingSectionCut => 'Edit cut';

  @override
  String get buildingSectionHint =>
      'Set the cut line, then choose its viewing side.';

  @override
  String get buildingSectionEmpty => 'No elements intersect this cut.';

  @override
  String get slabDetail => 'Floor detail';

  @override
  String get slabDetailPick => 'Pick a slab, then place its labels.';

  @override
  String get slabDetailMove => 'Tap to place the labels.';

  @override
  String get slabDetailLost => 'Lost link';

  @override
  String get slabDetailReattach => 'Reattach';

  @override
  String get slabDetailHere => 'here';

  @override
  String get slabDetailSide => 'Flip labels';

  @override
  String get slabDetailRemove => 'Remove detail';

  @override
  String get slabSectionDelete => 'Delete section';

  @override
  String get slabMatConcrete => 'Reinforced concrete';

  @override
  String get slabMatTile => 'Tiles';

  @override
  String get slabMatTileAdhesive => 'Tile adhesive';

  @override
  String get slabMatParquet => 'Parquet';

  @override
  String get slabMatUnderlay => 'Parquet underlay';

  @override
  String get slabMatScreed => 'Cement screed';

  @override
  String get slabMatPeFoil => 'PE separating foil';

  @override
  String get slabMatXps => 'XPS';

  @override
  String get slabMatFloorInsulation => 'Rigid floor insulation';

  @override
  String get slabMatAcousticWool => 'Impact sound insulation';

  @override
  String get slabMatMineralWool => 'Mineral wool';

  @override
  String get slabMatRoofInsulation => 'Rigid roof insulation';

  @override
  String get slabMatWaterproofing => 'Waterproofing';

  @override
  String get slabMatVapourBarrier => 'Vapour control layer';

  @override
  String get slabMatBreathableMembrane => 'Breathable protection';

  @override
  String get slabMatGeotextile => 'Geotextile';

  @override
  String get slabMatGravel => 'Gravel ballast';

  @override
  String get slabMatBallast => 'Compacted aggregate';

  @override
  String get slabMatCompactedFill => 'Compacted fill';

  @override
  String get slabMatBlindingConcrete => 'Blinding concrete';

  @override
  String get slabMatPlaster => 'Ceiling plaster';

  @override
  String get slabMatProtectiveRender => 'Reinforced protective render';

  @override
  String get slabMatPlasterboard => 'Plasterboard lining';

  @override
  String get slabMatAdhesive => 'Insulation adhesive';

  @override
  String get slabMatCustom => 'Custom material';

  @override
  String get slabUseFoundation => 'Foundation slab';

  @override
  String get slabUseGround => 'Ground-bearing floor';

  @override
  String get slabUseBasement => 'Above basement';

  @override
  String get slabUseIntermediate => 'Intermediate floor';

  @override
  String get slabUseColdAttic => 'Below cold attic';

  @override
  String get slabUseInsulatedCeiling => 'Insulation below slab';

  @override
  String get slabUseWarmRoof => 'Warm flat roof';

  @override
  String get slabUseInvertedRoof => 'Inverted flat roof';

  @override
  String get slabUseTerrace => 'Terrace above heated space';

  @override
  String get slabRoleFinish => 'Finish';

  @override
  String get slabRoleAdhesive => 'Bonding';

  @override
  String get slabRoleScreed => 'Screed';

  @override
  String get slabRoleSeparation => 'Separation';

  @override
  String get slabRoleInsulation => 'Thermal insulation';

  @override
  String get slabRoleAcoustic => 'Sound insulation';

  @override
  String get slabRoleWaterproofing => 'Waterproofing';

  @override
  String get slabRoleVapourControl => 'Vapour control';

  @override
  String get slabRoleSlope => 'Slope';

  @override
  String get slabRoleCeiling => 'Ceiling finish';

  @override
  String get slabRoleBase => 'Base';

  @override
  String get slabRoleFill => 'Fill';

  @override
  String get slabRoleProtection => 'Protection';

  @override
  String get architectFacades => 'Elevations';

  @override
  String get architectFacade => 'Elevation';

  @override
  String get architectFacadeNew => 'New elevation';

  @override
  String get architectFacadeEdit => 'Edit marker';

  @override
  String get architectFacadeReverse => 'Reverse view';

  @override
  String get architectFacadePlan => 'Plan';

  @override
  String get architectFacadeStartHint =>
      'Choose the first marker point outside the building.';

  @override
  String get architectFacadeEndHint =>
      'Choose the second point, parallel to the facade.';

  @override
  String get architectFacadeSideHint =>
      'Tap on the building side to set the viewing direction.';

  @override
  String get architectFacadeEmpty =>
      'No building elements in this view. Check the marker span and direction.';

  @override
  String get architectNorth => 'North';

  @override
  String get architectNorthPlace => 'Place north';

  @override
  String get architectNorthHelp =>
      'Rotate the symbol to set north. Elevation names update automatically.';

  @override
  String get architectNorthAngle => 'Angle';

  @override
  String get architectNorthAngleHelp => 'Clockwise angle from plan-up (0°).';

  @override
  String get architectNorthInvalidAngle => 'Enter a valid angle.';

  @override
  String get architectNorthPositionHint => 'Choose the north symbol position.';

  @override
  String get architectNorthDirectionHint => 'Choose a point towards north.';

  @override
  String get architectNorthSymbolLetter => 'N';

  @override
  String get architectFacadeNorth => 'North';

  @override
  String get architectFacadeNorthEast => 'Northeast';

  @override
  String get architectFacadeEast => 'East';

  @override
  String get architectFacadeSouthEast => 'Southeast';

  @override
  String get architectFacadeSouth => 'South';

  @override
  String get architectFacadeSouthWest => 'Southwest';

  @override
  String get architectFacadeWest => 'West';

  @override
  String get architectFacadeNorthWest => 'Northwest';

  @override
  String get architectToolRoof => 'Roof';

  @override
  String get architectRoofs => 'Roofs';

  @override
  String get architectRoofPlane => 'Roof plane';

  @override
  String get architectRoofDrawRect => 'Rect';

  @override
  String get architectRoofDrawPoly => 'Poly';

  @override
  String get architectRoofAuto => 'Auto roof';

  @override
  String get architectRoofAutoGable => 'Gable';

  @override
  String get architectRoofAutoHip => 'Hip';

  @override
  String get architectRoofAutoShed => 'Shed';

  @override
  String get architectRoofAutoFlat => 'Flat';

  @override
  String architectRoofAutoCreated(int count) {
    return 'Generated $count roof planes';
  }

  @override
  String get architectRoofAutoNoWalls =>
      'Draw exterior walls first to generate an automatic roof.';

  @override
  String get architectRoofSlope => 'Slope';

  @override
  String get architectRoofOverhang => 'Eaves';

  @override
  String get architectRoofManualSupport => 'Manual support position';

  @override
  String get architectRoofSupportDistance => 'From eaves';

  @override
  String get architectRoofManualSupportHelp =>
      'Horizontal distance from the eaves edge to the centre of the ring beam and wall plate. Uncheck to follow the supporting wall automatically.';

  @override
  String get architectRoofSupportDistanceInvalid =>
      'Enter a distance within the roof plane.';

  @override
  String get architectRoofBaseElev => 'Eaves Z';

  @override
  String get architectRoofRidgeElev => 'Ridge Z';

  @override
  String get architectRoofSwitchEaves => 'Next eaves';

  @override
  String get architectRoofSwitchEavesTooltip =>
      'Switch which edge is the lower eaves edge (or tap an edge on canvas)';

  @override
  String get architectRoofLayers => 'Layers & Timber';

  @override
  String get architectRoofLayersShort => 'Structure';

  @override
  String get architectRoofPresetPitchedTiles => 'Timber roof with clay tiles';

  @override
  String get architectRoofPresetWarmPitched => 'Insulated warm pitched roof';

  @override
  String get architectRoofPresetStandingSeam => 'Standing seam metal roof';

  @override
  String get architectRoofPresetFlatWarm => 'Warm flat RC roof';

  @override
  String get architectRoofPresetCustom => 'Custom roof assembly';

  @override
  String get architectRoofRoleCovering => 'Covering';

  @override
  String get architectRoofRoleBattens => 'Battens';

  @override
  String get architectRoofRoleCounterBattens => 'Counter-battens';

  @override
  String get architectRoofRoleUnderlayment => 'Breathable membrane';

  @override
  String get architectRoofRoleBoarding => 'Boarding / sheathing';

  @override
  String get architectRoofRoleRafters => 'Rafters';

  @override
  String get architectRoofRoleInsulation => 'Thermal insulation';

  @override
  String get architectRoofRoleVapourBarrier => 'Vapour barrier';

  @override
  String get architectRoofRoleStructure => 'Structural deck';

  @override
  String get architectRoofRoleInterior => 'Ceiling lining';

  @override
  String get architectRoofMatClayTiles => 'Clay roof tiles';

  @override
  String get architectRoofMatConcreteTiles => 'Concrete tiles';

  @override
  String get architectRoofMatMetalSeam => 'Standing seam metal';

  @override
  String get architectRoofMatBitumenShingles => 'Bitumen shingles';

  @override
  String get architectRoofMatTimberBoarding => 'Timber boarding';

  @override
  String get architectRoofMatOsb => 'OSB sheathing';

  @override
  String get architectRoofMatBreathableMembrane => 'Breathable membrane';

  @override
  String get architectRoofMatVapourBarrier => 'Vapour barrier foil';

  @override
  String get architectRoofMatMineralWool => 'Mineral wool';

  @override
  String get architectRoofMatXps => 'XPS insulation';

  @override
  String get architectRoofMatWaterproofing => 'Waterproofing membrane';

  @override
  String get architectRoofMatSlopeScreed => 'Slope screed';

  @override
  String get architectRoofMatRcSlab => 'Reinforced concrete';

  @override
  String get architectRoofMatPlasterboard => 'Gypsum plasterboard';

  @override
  String get architectRoofTimberSection => 'Timber carpentry & framing';

  @override
  String get architectRoofBattensLabel => 'Battens';

  @override
  String get architectRoofCounterBattensLabel => 'Counter-battens';

  @override
  String get architectRoofRaftersLabel => 'Rafters';

  @override
  String get architectRoofWallPlateLabel => 'Wall plate (Mauerlat)';

  @override
  String get architectRoofRidgePurlinLabel => 'Ridge purlin';

  @override
  String get architectRoofFasciaLabel => 'Fascia board at eaves';

  @override
  String get architectRoofEavesCutLabel => 'Eaves cut style';

  @override
  String get architectRoofEavesCutPlumb => 'Vertical (plumb)';

  @override
  String get architectRoofEavesCutSquare => 'Square to slope';

  @override
  String get architectRoofEavesCutBox => 'Boxed soffit';

  @override
  String get architectRoofStepLabel => 'Step';

  @override
  String get architectRoofHintStart =>
      'Hold and drag to pick first roof corner, or use Auto roof.';

  @override
  String architectRoofHintNext(int count) {
    return 'Pick next corner ($count pts). Tap Finish to close.';
  }

  @override
  String get architectRoofSectionDetailTitle => 'Roof assembly';

  @override
  String get architectSectionStartHint => 'Choose the start of the cut.';

  @override
  String get architectViewEndHint => 'Set the end using the alignment guides.';

  @override
  String get architectViewDirectionHint =>
      'Choose the viewing side and click the far boundary.';

  @override
  String architectSectionNumber(int number) {
    return 'Section $number';
  }

  @override
  String get architectManageViews => 'Manage views';

  @override
  String get architectViewDrawingEmpty =>
      'Choose or create a view from the menu.';

  @override
  String get architectOpeningClearance => 'Opening clearance';

  @override
  String architectOpeningModularSnap(int step) {
    return 'Modular step ($step cm)';
  }

  @override
  String get architectRoofSetEavesHere => 'Eaves here';

  @override
  String get architectRoofSetEavesHereTooltip =>
      'Set the selected roof edge as the lower eaves edge (slope rises from here)';

  @override
  String get architectRoofFlipSlope => 'Flip 180°';

  @override
  String get architectRoofFlipSlopeTooltip =>
      'Reverse the roof slope direction by 180°';

  @override
  String get architectRoofRotateSlope => 'Slope dir';

  @override
  String get architectRoofAttachToWalls => 'Attach to wall top';

  @override
  String get architectRoofAttachToWallsSubtitle =>
      'Auto-align roof structure to highest supporting walls with constructive eaves detail';

  @override
  String get architectRoofRingBeamLabel => '10 cm concrete ring beam';

  @override
  String get architectRoofMetalFlashingLabel => 'Metal flashing (drip edge)';

  @override
  String get architectRoofMoveVerticalAction => 'Move up / down';

  @override
  String get architectRoofSnapToWallsAction => 'Snap to walls';

  @override
  String get architectRoofPropertiesAction => 'Properties';

  @override
  String get architectRoofPlan => 'Roof Lines';

  @override
  String get architectAddRoofPlan => 'Add Roof Lines';

  @override
  String get architectRoofPlanUnderlay => 'Perimeter wall underlay';

  @override
  String get architectRoofPlanSubtitle =>
      'Top-level roof plan with dashed perimeter wall lines';

  @override
  String architectRoofLowerLevelBadge(String level) {
    return 'Level $level';
  }

  @override
  String get architectRoofDrawMultiPitch => 'Multi-pitch';

  @override
  String get architectRoofDrawMansard => 'Mansard';

  @override
  String get architectRoofIsMansard => 'Mansard (Gambrel)';

  @override
  String get architectRoofMakeMansard => 'Make Mansard';

  @override
  String get architectRoofUpperSlope => 'Upper slope';

  @override
  String get architectRoofBreakDistance => 'Knuckle';

  @override
  String get architectRoofMansardKnuckleTooltip =>
      'Drag to adjust the Mansard knuckle line';

  @override
  String get architectRoofKnucklePurlin => 'Mansard purlin';

  @override
  String get architectRoofSnap45Degrees => '45° Hip / Ridge';

  @override
  String get architectRoofLinkedSlopes => 'Linked slopes';

  @override
  String get architectRoofLinkedSlopesTooltip =>
      'All roof planes in this group share the same slope and eaves height';

  @override
  String get architectRoofIndependentSlope => 'Independent slope';

  @override
  String get architectRoofIndependentSlopeTooltip =>
      'This roof plane has an independent slope (unlocked from group)';

  @override
  String get architectRoofToggleSlopeLockTooltip =>
      'Toggle linked group slope vs independent slope';

  @override
  String get architectRoofMatchRidge => 'Match ridge';

  @override
  String get architectRoofMatchRidgeTooltip =>
      'Adjust slope to match the ridge height of adjacent roofs';

  @override
  String architectRoofRidgeHeightMatched(String degrees, String height) {
    return 'Slope adjusted to $degrees° to match ridge height ${height}m';
  }

  @override
  String architectRoofSnapHipAngle(String angle) {
    return '$angle° Hip / Valley';
  }

  @override
  String get architectRoofSnapHipIntersection => 'Hip intersection (45°)';

  @override
  String get architectRoofSnapCornerHipIntersection =>
      'Corner hip intersection (45°)';

  @override
  String get architectRoofSnapPerpToCorner => 'Perpendicular to inner corner';

  @override
  String get architectRoofSnapRidgeAlignment => 'Ridge / edge alignment';

  @override
  String get cad3dOrbit => 'Orbit';

  @override
  String get cad3dPan => 'Pan';

  @override
  String get cad3dWalk => 'Walk';

  @override
  String get cad3dNativeDepthOn => 'Accelerated 3D';

  @override
  String get cad3dNativeDepthOff => 'Compatibility mode';

  @override
  String get cad3dShadingSmooth => 'Shaded';

  @override
  String get cad3dShadingFlat => 'Flat';

  @override
  String get cad3dShadingXray => 'Transparent';

  @override
  String get cad3dCamera => 'View';

  @override
  String get cad3dInvertY => 'Invert vertical look';

  @override
  String get cad3dViewIsometric => 'Isometric';

  @override
  String get cad3dViewTop => 'Top';

  @override
  String get cad3dViewFront => 'Front';

  @override
  String get cad3dViewRight => 'Right';

  @override
  String get cad3dViewBottom => 'Bottom';

  @override
  String get cad3dViewBack => 'Back';

  @override
  String get cad3dThemeBlueprint => 'Blueprint';

  @override
  String get cad3dThemeStudio => 'Studio';

  @override
  String get cad3dThemeBlack => 'Black';

  @override
  String get cad3dThemeWhite => 'White';

  @override
  String get architectProjectionInvalid =>
      'The element does not fit. Check the opening, host and clearances.';

  @override
  String get architectProjectionLeft => 'Left';

  @override
  String get architectProjectionRight => 'Right';

  @override
  String get architectProjectionHead => 'To slab';

  @override
  String get architectProjectionHorizontal => 'Move sideways';

  @override
  String get architectProjectionAlignSill => 'Align sills';

  @override
  String get architectProjectionAlignHead => 'Align heads';

  @override
  String get architectProjectionNoSlab => 'No upper slab';

  @override
  String get architectProjectionAlignLeft => 'Align left edges';

  @override
  String get architectProjectionAlignRight => 'Align right edges';

  @override
  String get architectDistancePrecision => 'Decimal places';

  @override
  String get architectWizardExample => 'Example:';

  @override
  String get architectWizardStoreysShort => 'Storeys';

  @override
  String get architectWizardElevation => 'Elevation';

  @override
  String get architectWizardHeight => 'H=';

  @override
  String get architectWizardStoreyHeightHelp =>
      'Height to the next storey, measured from finished floor to finished floor. Changing height moves the storeys above. Floor finishes and ceilings affect clear height separately.';

  @override
  String get architectWizardElevationHelp =>
      'Finished floor elevation relative to project zero. Editing an elevation keeps the other levels in place and adjusts the adjacent heights.';

  @override
  String get architectWizardInvalidLevel => 'Check the levels and heights.';

  @override
  String get architectWizardCreateShort => 'Create';

  @override
  String get architectWizardHeightReference =>
      'finished floor → finished floor';

  @override
  String architectWallConcreteCode(String thickness) {
    return 'RC $thickness';
  }

  @override
  String architectWallParapetCode(String thickness) {
    return 'P $thickness';
  }

  @override
  String architectWallTypeThicknessHint(String name, String thickness) {
    return '$name · $thickness cm';
  }

  @override
  String get architectWallQuickCore => 'Core';

  @override
  String get architectWallQuickInsulation => 'Insulation';

  @override
  String get architectWallInvalidThickness => 'Enter a valid thickness.';

  @override
  String get architectWallQuickThickness => 'Thickness';

  @override
  String get wallTypesTitle => 'Wall types';

  @override
  String get wallNewType => 'New type';

  @override
  String get wallCompositionName => 'Name';

  @override
  String get wallLocation => 'Use';

  @override
  String get wallExterior => 'Exterior';

  @override
  String get wallInterior => 'Interior';

  @override
  String get wallBearing => 'Load-bearing';

  @override
  String get wallLayerCore => 'Core';

  @override
  String get wallLayerInsulation => 'Insulation';

  @override
  String get wallLayerFinish => 'Finish';

  @override
  String get wallLayerRole => 'Layer role';

  @override
  String get wallLayerAdd => 'Add layer';

  @override
  String get wallLayerUp => 'Move up';

  @override
  String get wallLayerDown => 'Move down';

  @override
  String get wallLayerOutsideInside => 'Outside → inside';

  @override
  String get wallLayerSides => 'A → B';

  @override
  String get wallLayerInvalid =>
      'Use positive thicknesses and a continuous core.';

  @override
  String get wallSelectedScope => 'Selected walls only';

  @override
  String wallTypeApply(int count) {
    return 'Apply to type ($count)';
  }

  @override
  String get wallTypeReplacement => 'Replace with';

  @override
  String get wallTypeInUse =>
      'Select a replacement for the walls using this type.';

  @override
  String get wallCompositionAction => 'Layers';

  @override
  String get wallManageTypes => 'Manage types';

  @override
  String get wallMaterialPlaster => 'Plaster';

  @override
  String get wallMaterialRender => 'Facade render';

  @override
  String get wallMaterialBoard => 'Plasterboard';

  @override
  String get wallMaterialStone => 'Stone';

  @override
  String get wallPlinth => 'Plinth';

  @override
  String get wallPlinthFinish => 'Finish';

  @override
  String get wallPlinthBase => 'Base elevation (m)';

  @override
  String get wallPlinthBaseHelp =>
      'Project elevation of the bottom edge; H is measured upwards.';

  @override
  String get wallAdvanced => 'More';

  @override
  String get wallTypeCopy => 'Copy type';

  @override
  String get wallMixedValue => 'Mixed';

  @override
  String get wallArc => 'Arc wall';

  @override
  String get wallArcPickEnd => 'Pick the end of the arc';

  @override
  String get wallArcPickThrough => 'Pick a point on the arc';

  @override
  String get wallArcInvalidRadius => 'Radius is too small for this wall.';

  @override
  String get wallArcPickStart => 'Pick the start of the arc';

  @override
  String get wallPlinthEnabled => 'Enabled';

  @override
  String get wallArcMode => 'Arc';

  @override
  String get architectZonePresets => 'Zone presets';

  @override
  String get architectZoneManualHelp =>
      'Manual: edit points and edges. Clear to detect the room from its walls again.';

  @override
  String get architectZoneBoundaryOpen =>
      'No enclosed room found. Check the walls for gaps.';

  @override
  String get architectZoneCrossingRepairHint =>
      'Crossings will be corrected when the zone is closed.';

  @override
  String get architectZoneBoundaryRepaired => 'Boundary crossings corrected.';

  @override
  String get architectSheets => 'Sheets';

  @override
  String get architectModel => 'Model';

  @override
  String get architectSheetName => 'Sheet';

  @override
  String get architectSheetPlan => 'Plan';

  @override
  String get architectSheetAdd => 'Add sheet';

  @override
  String get architectSheetProperties => 'Sheet properties';

  @override
  String get architectSheetPlace => 'Place view';

  @override
  String get architectSheetEdit => 'Properties';

  @override
  String get architectSheetDuplicate => 'Duplicate';

  @override
  String get architectSheetDelete => 'Delete';

  @override
  String get architectSheetLock => 'Lock';

  @override
  String get architectSheetUnlock => 'Unlock';

  @override
  String get architectSheetTemplate => 'Title block';

  @override
  String get architectSheetExport => 'Export PDF';

  @override
  String get architectSheetPrint => 'Print';

  @override
  String get architectSheetMissingSource =>
      'Missing source. Relink or remove this drawing before export.';

  @override
  String get architectSheetMixedScales => 'Various';

  @override
  String get architectSheetFormat => 'Format';

  @override
  String get architectSheetCustom => 'Custom';

  @override
  String get architectSheetWidth => 'Width (mm)';

  @override
  String get architectSheetHeight => 'Height (mm)';

  @override
  String get architectSheetMargin => 'Margin (mm)';

  @override
  String get architectSheetNumber => 'Number';

  @override
  String get architectSheetAuthor => 'Author';

  @override
  String get architectSheetDate => 'Date';

  @override
  String get architectSheetNameField => 'Name';

  @override
  String get architectSheetSave => 'Save';

  @override
  String get architectSheetCancel => 'Cancel';

  @override
  String get architectSheetScale => 'Scale';

  @override
  String get architectSheetX => 'X (mm)';

  @override
  String get architectSheetY => 'Y (mm)';

  @override
  String get architectSheetAnchorX => 'Source X';

  @override
  String get architectSheetAnchorY => 'Source Y';

  @override
  String get architectSheetRotation => 'Rotation (°)';

  @override
  String get architectSheetTitle => 'Show title';

  @override
  String get architectSheetSource => 'Source';

  @override
  String get architectSheetAlign => 'Align';

  @override
  String get architectSheetLeft => 'Left';

  @override
  String get architectSheetRight => 'Right';

  @override
  String get architectSheetTop => 'Top';

  @override
  String get architectSheetBottom => 'Bottom';

  @override
  String get architectSheetSelect => 'Select sheets in export order';

  @override
  String get architectSheetInvalid =>
      'Enter valid positive sizes and keep the margin inside the sheet.';

  @override
  String get architectSheetExportFailed => 'PDF export failed.';

  @override
  String get architectSheetNoViews => 'No views available.';

  @override
  String get architectSheetAddCell => 'Add cell';

  @override
  String get architectSheetField => 'Field';

  @override
  String get architectSheetBorder => 'Border';

  @override
  String get architectSheetText => 'Text';

  @override
  String get architectSheetProject => 'Project';

  @override
  String get architectSheetDrawing => 'Drawing';

  @override
  String get architectPrintPreview => 'Print preview';

  @override
  String get architectAnnotationSettings => 'Annotations';

  @override
  String get architectAnnotationSize => 'Size on paper (mm)';

  @override
  String get architectAnnotationReset => 'Use profile';

  @override
  String get architectAnnotationProfile => 'Profile';

  @override
  String get architectAnnotationElement => 'Individual annotation';

  @override
  String get architectAnnotationOrdinary => 'Labels';

  @override
  String get architectAnnotationDimension => 'Dimensions';

  @override
  String get architectAnnotationArea => 'Areas';

  @override
  String get architectAnnotationRoomName => 'Room names';

  @override
  String get architectAnnotationTitle => 'Titles';

  @override
  String get architectAnnotationTable => 'Tables';

  @override
  String get architectAnnotationSymbol => 'Symbols';

  @override
  String get architectSheetVisibility => 'Visibility';

  @override
  String get architectSheetAxes => 'Axes';

  @override
  String get architectSheetZones => 'Zones';

  @override
  String get architectSheetDimensions => 'Dimensions';

  @override
  String get architectSheetAnnotations => 'Text';

  @override
  String get architectSheetMarkers => 'Markers';

  @override
  String get architectSheetEmpty =>
      'Create a sheet, then place a plan, section or elevation.';

  @override
  String get architectSheetSaveView => 'Save view';

  @override
  String get architectSheetTemplateName => 'Template name';

  @override
  String architectAreaWithUnit(String unit) {
    return 'Area ($unit²)';
  }

  @override
  String get architectSheetTemplateOverflow =>
      'Title block text exceeds its cell. Enlarge the cell before export.';

  @override
  String get snapMidpointAlignment => 'Align to midpoint';

  @override
  String get architectComponentLibraryTitle => 'Library';

  @override
  String get architectComponentStudioTitle => 'Component Studio';

  @override
  String get architectComponentStudioBtn => 'Code';

  @override
  String get architectCategorySanitary => 'Sanitary';

  @override
  String get architectCategoryFurniture => 'Furniture';

  @override
  String get architectCategoryKitchen => 'Kitchen';

  @override
  String get architectCategoryStorage => 'Storage';

  @override
  String get architectCategoryOffice => 'Office';

  @override
  String get architectCategoryEquipment => 'Equipment';

  @override
  String get architectCategoryLighting => 'Lighting';

  @override
  String get architectCategoryOutdoor => 'Outdoor';

  @override
  String get architectComponentRotateBtn => 'Rotate 90° (R)';

  @override
  String get architectComponentSavedMsg => 'Component saved to custom library!';

  @override
  String get architectComponentCompileBtn => 'Preview';

  @override
  String get architectComponentSaveBtn => 'Save';

  @override
  String get architectComponentTemplateHint => 'Select template...';

  @override
  String get architectComponentExportDartTooltip =>
      'Export Dart class to clipboard';

  @override
  String get architectComponentExportDartMsg =>
      'Dart code copied to clipboard!';

  @override
  String get architect2dPlanSymbol => '2D Plan Symbol';

  @override
  String get architect3dSolidMesh => '3D Solid Mesh';

  @override
  String get architectPlacementModeWall => 'Wall Attached';

  @override
  String get architectPlacementModeFree => 'Free Standing';

  @override
  String get architectLayerFurniture => 'Furniture Layer';

  @override
  String get architectComponentNoItems => 'No items found';

  @override
  String get architectFurnishing => 'Furnishing';

  @override
  String get architectLibrary => 'Library';

  @override
  String get architectLibraryAll => 'All';

  @override
  String get architectLibrarySourceAll => 'All sources';

  @override
  String get architectLibraryBuiltIn => 'Built-in';

  @override
  String get architectLibraryCustom => 'My objects';

  @override
  String get architectLibraryImport => 'Import JSON';

  @override
  String get architectLibraryImportHelp =>
      'Import a parametric object (.json) with dimensions in metres. Preview and save it in the studio.';

  @override
  String get architectLibraryImportError => 'The object could not be imported.';

  @override
  String get architectComponentInvalid =>
      'Check the object code, dimensions and supported shapes.';

  @override
  String get architectComponentCustomName => 'Custom object';

  @override
  String get architectComponentCode => 'Code';

  @override
  String get architectComponentPreview => 'Preview';

  @override
  String get architectComponentLockRatio => 'Lock X:Y:Z';

  @override
  String get architectComponentLockRatioHelp =>
      'Changing one dimension scales all three by the same factor.';

  @override
  String get architectComponentDimensionError =>
      'Enter a size from 0.1 to 10000 cm.';

  @override
  String get architectComponentDefaults => 'Default size';

  @override
  String get architectTemplateDesk => 'Desk';

  @override
  String get architectTemplateBasin => 'Basin';

  @override
  String get architectComponentToiletWall => 'Wall-hung toilet';

  @override
  String get architectComponentToiletFloor => 'Floor-standing toilet';

  @override
  String get architectComponentVanity => 'Washbasin cabinet';

  @override
  String get architectComponentBathtub => 'Bathtub';

  @override
  String get architectComponentShower => 'Shower';

  @override
  String get architectComponentBedDouble => 'Double bed';

  @override
  String get architectComponentBedSingle => 'Single bed';

  @override
  String get architectComponentWardrobe => 'Wardrobe';

  @override
  String get architectComponentDining => 'Table and chairs';

  @override
  String get architectComponentSofa => 'Sofa';

  @override
  String get architectComponentDesk => 'Desk';

  @override
  String get architectComponentKitchenBase => 'Base cabinet';

  @override
  String get architectComponentKitchenSink => 'Sink cabinet';

  @override
  String get architectComponentFridge => 'Refrigerator';

  @override
  String get architectComponentCooktop => 'Cooktop and oven';

  @override
  String get architectComponentExportJsonTooltip => 'Copy JSON';

  @override
  String get architectComponentExportJsonMsg => 'JSON copied to clipboard';

  @override
  String get architectComponentView2d => '2D view';

  @override
  String get architectComponentView3d => '3D view';

  @override
  String get architectApartment => 'Apartment';

  @override
  String get architectRoom => 'Room';

  @override
  String get architectApartmentRooms => 'Rooms';

  @override
  String get architectUnassignedRooms => 'Unassigned rooms';

  @override
  String get architectApartmentAutoAssignment => 'Auto';

  @override
  String get architectApartmentNoRooms => 'No rooms within the outline.';

  @override
  String get architectApartmentBoundaryHelp =>
      'Draw manually along internal wall axes and the exterior faces of exterior walls.';

  @override
  String get architectApartmentGross => 'Contour area';

  @override
  String get architectApartmentNet => 'Room area';

  @override
  String get architectApartmentRoomsHelp =>
      'Rooms are assigned automatically by the largest overlapping area with an apartment. Each room is counted in full only once. Equal areas retain the current apartment. Rooms outside all apartments stay unassigned.';

  @override
  String get architectLineParallelHelp =>
      'Tap to move across the line without changing its angle. Hold to enter a signed offset.';

  @override
  String get architectLineJoinSuccess => 'Lines joined';

  @override
  String get architectLineJoinIncompatible => 'Lines cannot be joined';

  @override
  String get architectLineJoinSelectSecond => 'Select second line to join';

  @override
  String get architectLineEditRejected => 'Line must be at least 1 mm long.';

  @override
  String get architectLineStyle => 'Line style';

  @override
  String get architectLineSolid => 'Continuous';

  @override
  String get architectLineDashed => 'Dashed';

  @override
  String get architectLineShortDashed => 'Short dashes';

  @override
  String get architectLineLongDashed => 'Long dashes';

  @override
  String get architectLineDotted => 'Dotted';

  @override
  String get architectLineSparseDotted => 'Sparse dots';

  @override
  String get architectLineDashDot => 'Dash–dot';

  @override
  String get architectLineDashDoubleDot => 'Dash–double dot';

  @override
  String get architectLineLongDashDot => 'Long dash–dot';

  @override
  String get architectLineLongShortDash => 'Long–short dash';

  @override
  String get architectLineDoubleDashDot => 'Double dash–dot';

  @override
  String get architectLinePatternEditor => 'Custom pattern';

  @override
  String get architectLineDash => 'Dash';

  @override
  String get architectLineGap => 'Gap';

  @override
  String get architectLinePatternHint =>
      'Dashes, gaps and symbols. Sizes are measured on paper.';

  @override
  String get architectLinePatternRange => 'Enter 0.1–100 mm.';

  @override
  String get architectLinePatternAdd => 'Add pair';

  @override
  String get architectLinePatternRemove => 'Remove pair';

  @override
  String get architectLinePowerLine => 'Power line';

  @override
  String get architectLineSymbol => 'Symbol';

  @override
  String get architectLineSymbolNone => 'None';

  @override
  String get architectLineSymbolLightning => 'Lightning';

  @override
  String get architectLineSymbolCircle => 'Circle';

  @override
  String get architectLineSymbolSquare => 'Square';

  @override
  String get architectLineSymbolTriangle => 'Triangle';

  @override
  String get architectLineSymbolDiamond => 'Diamond';

  @override
  String get architectLineSymbolCross => 'Cross';

  @override
  String get architectLineSymbolArrow => 'Arrow';

  @override
  String get architectLineSymbolChevron => 'Chevron';

  @override
  String get architectLineSymbolCustom => 'Custom shape';

  @override
  String get architectLineSymbolSettings => 'Placement';

  @override
  String get architectLineSymbolDraw => 'Edit shape';

  @override
  String get architectLineSymbolSize => 'Size';

  @override
  String get architectLineSymbolSpacing => 'Repeat';

  @override
  String get architectLineSymbolFollow => 'Follow line direction';

  @override
  String get architectLineSymbolClearLine => 'Gap around symbol';

  @override
  String get architectLineSymbolDrawHint =>
      'Place points or draw freehand. You can add separate strokes.';

  @override
  String get architectLineSymbolPoints => 'Point by point';

  @override
  String get architectLineSymbolFreehand => 'Freehand';

  @override
  String get architectToolHatch => 'Hatch';

  @override
  String architectSelectionHatchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hatches',
      one: '1 hatch',
    );
    return '$_temp0';
  }

  @override
  String get architectHatchPattern => 'Pattern';

  @override
  String get architectHatchCustom => 'Custom hatch';

  @override
  String get architectHatchHint =>
      'Layers of lines or symbols. Spacing and sizes are in mm on paper.';

  @override
  String get architectHatchDiagonal => 'Diagonal';

  @override
  String get architectHatchReverseDiagonal => 'Reverse diagonal';

  @override
  String get architectHatchHorizontal => 'Horizontal';

  @override
  String get architectHatchVertical => 'Vertical';

  @override
  String get architectHatchCross => 'Grid';

  @override
  String get architectHatchDiagonalCross => 'Crosshatch';

  @override
  String get architectHatchBrick => 'Brick';

  @override
  String get architectHatchConcrete => 'Concrete';

  @override
  String get architectHatchDots => 'Dots';

  @override
  String get architectHatchEarth => 'Earth';

  @override
  String get architectHatchScale => 'Scale';

  @override
  String get architectHatchBorder => 'Boundary';

  @override
  String architectHatchLayer(int number) {
    return 'Layer $number';
  }

  @override
  String get architectHatchAddLayer => 'Add layer';

  @override
  String get architectHatchSpacing => 'Spacing';

  @override
  String get architectHatchPhase => 'Offset';

  @override
  String get architectHatchShift => 'Row shift';

  @override
  String get architectHatchSymbolsOnly => 'Symbols only';

  @override
  String get architectHatchFinish => 'Finish';

  @override
  String get architectHatchDrawHint =>
      'Place at least three vertices and close the contour.';

  @override
  String get architectLineHatchBrickJoint => 'Joints';

  @override
  String get architectLineHatchAggregate => 'Aggregate';

  @override
  String get architectLineHatchGrain => 'Grain';

  @override
  String get architectLineHatchDots => 'Dots';

  @override
  String get architectLineHatchEarth => 'Earth';

  @override
  String get architectLineSymbolNewStroke => 'New stroke';

  @override
  String get architectLineSymbolCloseStroke => 'Close stroke';

  @override
  String architectLineSymbolRange(String minimum, String maximum, String unit) {
    return 'Enter $minimum–$maximum $unit.';
  }

  @override
  String get architectViewUnlimited => 'Unlimited';

  @override
  String get architectViewDepth => 'View depth';

  @override
  String get architectViewDepthInvalid =>
      'Enter a finite distance of at least 1 cm.';

  @override
  String get architectDrainageTitle => 'Drainage';

  @override
  String get architectDrainageGutter => 'Gutter';

  @override
  String get architectDrainagePipes => 'Downpipes';

  @override
  String get architectDrainagePipe => 'Downpipe';

  @override
  String get architectDrainageSmart => 'Smart downpipe';

  @override
  String get architectDrainageProfile => 'Profile';

  @override
  String get architectDrainageHalfRound => 'Half-round';

  @override
  String get architectDrainageBox => 'Box';

  @override
  String get architectDrainageMaterial => 'Material';

  @override
  String get architectDrainageSteel => 'Galvanized steel';

  @override
  String get architectDrainageAluminium => 'Aluminium';

  @override
  String get architectDrainagePvc => 'PVC';

  @override
  String get architectDrainageCopper => 'Copper';

  @override
  String get architectDrainageWidth => 'Width';

  @override
  String get architectDrainageDepth => 'Depth';

  @override
  String get architectDrainageAdd => 'Add downpipe';

  @override
  String get architectDrainagePlace => 'Place on plan';

  @override
  String get architectDrainagePrompt => 'Pick a position on the eaves.';

  @override
  String get architectDrainageOffset => 'From eaves start';

  @override
  String get architectDrainageDiameter => 'Diameter';

  @override
  String get architectDrainageClearance => 'Wall clearance';

  @override
  String get architectDrainageOutlet => 'Outlet elevation';

  @override
  String get architectDrainageBend => 'Bend angle';

  @override
  String get architectDrainageFacade => 'Facade';

  @override
  String get architectDrainageWall => 'Wall';

  @override
  String get architectDrainageAuto => 'Automatic';

  @override
  String get architectDrainageWaypoints => 'Waypoints';

  @override
  String get architectDrainageWaypointsHelp =>
      'Empty: automatic route. Manual: one point per line — inward offset; absolute elevation (m), top to bottom.';

  @override
  String get architectDrainageInvalid => 'Invalid value.';

  @override
  String get architectDrainageReady => 'Route is clear.';

  @override
  String get architectDrainageNoFacade => 'No facade found. Select a wall.';

  @override
  String get architectDrainageBlocked =>
      'Not enough room for the route. Adjust the position or waypoints.';

  @override
  String get architectDrainageOutside =>
      'Position is outside the exposed eaves.';

  @override
  String get architectDrainageNoRoof => 'Create a roof first.';

  @override
  String get architectRoofTimberTab => 'Framing';

  @override
  String get architectViewStep => 'Add jog';

  @override
  String get architectViewEditHint =>
      'Drag endpoints, jogs or the far boundary, then apply.';

  @override
  String get architectViewDepthBehindSteps =>
      'Place the far boundary beyond every segment.';

  @override
  String get architectViewStraight => 'Straighten';

  @override
  String get architectViewStepHint =>
      'Click beside the marker to set the jog station and offset. Repeat Add jog for more segments.';

  @override
  String get stairConstruction => 'Construction';

  @override
  String get stairSteel => 'Steel';

  @override
  String get stairTreadThickness => 'Tread thickness';

  @override
  String get stairStringerWidth => 'Stringer width';

  @override
  String get stairStringerDepth => 'Stringer depth';

  @override
  String get architectHatchWood => 'Wood';

  @override
  String get architectHatchMetal => 'Metal';

  @override
  String get architectHatchGenerator => 'Pattern generator';

  @override
  String get architectHatchGeneratorHint =>
      'Draw a motif with connected lines. Set its size and row spacing; the preview updates as you draw.';

  @override
  String get architectSketchOrtho => 'Orthogonal lines';

  @override
  String get architectSketchPreview => 'Repeat preview';

  @override
  String get architectTerrain => 'Terrain line';

  @override
  String get architectTerrainHint =>
      'Place points from left to right. Confirm to hide the building below this line in this elevation.';

  @override
  String get architectRoofPitchEdit => 'Roof pitch';

  @override
  String get architectRoofPitchHint =>
      'Drag the green point to change pitch and snap to a neighbouring roof. Tap the roof to choose a fixed axis. Pinch or use the mouse wheel to zoom.';

  @override
  String get architectRoofPitchAxis => 'Use eaves axis';

  @override
  String get architectStrokeWeight => 'Line weight';

  @override
  String get architectCutOpening => 'Cut opening';

  @override
  String get architectCutOpeningHint =>
      'Draw a closed contour inside the selected element, then confirm.';

  @override
  String get architectCutOpeningInvalid =>
      'Keep the opening inside the element, without touching its boundary or another opening.';

  @override
  String get architectHatchAutoHint => 'Fill: tap inside a closed contour.';

  @override
  String get architectHatchAutoFailed =>
      'No closed contour found. Close the boundary or draw it manually.';

  @override
  String get appSettingsTitle => 'Settings';

  @override
  String get uiSettingsCategory => 'UI';

  @override
  String get contextMenuTitle => 'Context menu';

  @override
  String get contextMenuLayout => 'Layout';

  @override
  String get contextMenuCircle => 'Fixed circle';

  @override
  String get contextMenuGrid => 'Fixed grid';

  @override
  String get contextMenuCombination => 'Combination';

  @override
  String get contextMenuDefault => 'Default';

  @override
  String get contextMenuSaveAs => 'New combination';

  @override
  String get contextMenuEdit => 'Edit';

  @override
  String get contextMenuName => 'Name';

  @override
  String get contextMenuEmpty => 'Empty';

  @override
  String get contextMenuMore => 'More';

  @override
  String get contextMenuAssignHint =>
      'Tap a slot to choose a command. Choosing a command already in use swaps the two slots. Other commands remain under More.';

  @override
  String contextMenuPage(int page, int total) {
    return 'More commands: page $page of $total. Tap for the next page.';
  }

  @override
  String get uiSettingsSaveFailed => 'Settings could not be saved. Try again.';

  @override
  String get architectViewVisibility => 'Visibility';

  @override
  String get architectSectionVisibility => 'Section visibility';

  @override
  String get architectSectionProjectRules => 'Project defaults';

  @override
  String get architectSectionViewRules => 'This section';

  @override
  String get architectSectionInherit => 'Use project';

  @override
  String get architectSectionCutAndView => 'Cut and view';

  @override
  String get architectSectionCutOnly => 'Cut only';

  @override
  String get architectSectionHidden => 'Hidden';

  @override
  String get architectSectionVisibilityHelp =>
      'Project defaults apply to all sections unless a section overrides them. Cut only shows the actual intersection with the section plane and omits the projection behind it. 3D and elevations keep their normal visibility.';

  @override
  String get bimGroup => 'Group';

  @override
  String get bimUngroup => 'Ungroup';

  @override
  String get bimEditGroup => 'Edit group';

  @override
  String get bimInsideGroup => 'Inside group';

  @override
  String get bimGroupDone => 'Done';

  @override
  String get bimGroupLabel => 'Group';

  @override
  String get bimOffsetDistance => 'Distance';

  @override
  String get bimOffsetCopy => 'Copy';

  @override
  String get bimOffsetSide => 'Pick a side';

  @override
  String get bimOffsetInvalid =>
      'Cannot offset. Check the selection, distance and side.';

  @override
  String get bimOffsetHelp =>
      'Enter a distance and pick a side. Copy creates parallel elements; uncheck it to change the selection. Connected segments meet at shared corners. Openings in closed contours stay in place. Copying a whole group creates a new group; copies made while editing a group stay in it. For branched chains or groups containing text and symbols, use Edit group to select applicable segments without branches.';

  @override
  String get architectToolFloorDrain => 'Drain';

  @override
  String get architectDrainRound => 'Round';

  @override
  String get architectDrainLinear => 'Linear';

  @override
  String get architectDrainSlope => 'Fall';

  @override
  String get architectDrainDiameter => 'Diameter';

  @override
  String get architectDrainLength => 'Length';

  @override
  String get architectDrainWidth => 'Width';

  @override
  String get architectDrainFromRoom => 'Room';

  @override
  String get architectDrainOutline => 'Outline';

  @override
  String get architectDrainHint =>
      'Click the first point or the green tick to confirm the floor. Drag the grip to move the drain.';

  @override
  String get architectDrainOutsideFloor => 'Drain is outside the floor';

  @override
  String get architectDrainNearDoor => 'Drain is close to a door';

  @override
  String get architectDrainRoomNotFound => 'No closed room here';

  @override
  String get architectDrainInvalid => 'Drain cannot be placed here';

  @override
  String architectSelectionDrainsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drains',
      one: '1 drain',
    );
    return '$_temp0';
  }

  @override
  String get architectComponentLinearDrain => 'Linear Floor Drain';

  @override
  String get architectComponentFloorDrain => 'Floor Drain';

  @override
  String get architectFloorDrainLibraryDesc =>
      'Draft wet room floor with falls and levels to drain';

  @override
  String get architectCategoryViews => 'Views';

  @override
  String get architectToolSection => 'Section';

  @override
  String get architectToolElevation => 'Elevation';

  @override
  String get architectOpenView => 'Open View';

  @override
  String get architectOpenSection => 'Open Section';

  @override
  String get architectOpenElevation => 'Open Elevation';

  @override
  String get architectViewRename => 'Rename';

  @override
  String get architectSectionHint => 'Two points → direction';

  @override
  String get architectElevationHint => 'Two points → direction';

  @override
  String get architectSelectModeRect => 'Rectangle';

  @override
  String get architectSelectModePolygon => 'Point by point';

  @override
  String get architectSelectMarqueeHint =>
      'Click or drag opposite corners to select';

  @override
  String get architectSelectPolygonHint =>
      'Click points to outline selection area';

  @override
  String get architectSelectFinish => 'Select';

  @override
  String get architectFillSolid => 'Solid';

  @override
  String get architectDrawingColor => 'Color';

  @override
  String get architectColorGeneral => 'Basic';

  @override
  String get architectColorBgOup => 'Bulgaria · OUP';

  @override
  String get architectColorBgPup => 'Bulgaria · PUP';

  @override
  String get architectColorGermany => 'Germany · PlanZV';

  @override
  String get architectColorSearch => 'Code or name';

  @override
  String get architectColorCustom => 'Custom';

  @override
  String get architectColorOpacity => 'Opacity';

  @override
  String get architectColorInfo => 'About the palette';

  @override
  String get architectColorHexError => 'Enter six hexadecimal digits.';

  @override
  String get architectColorApprox =>
      'Screen colors are approximate. The RAL reference is stored separately; use a calibrated palette for precise print matching.';

  @override
  String get architectColorBgInfo =>
      'Ordinance No. 8, Annex 2: table 1 for OUP, table 2 for PUP. + and ++ mean lighter shades; − means darker. These are color palettes; complete planning symbols may also require borders, stripes and labels. PUP zone colors apply to PRZ/PZ drawings.';

  @override
  String get architectColorDeInfo =>
      'FNP/B-Plan color groups from PlanZV. The ordinance specifies named tones, not mandatory RGB or RAL codes. These are working approximations; complete planning symbols also include lines, hatching and labels.';

  @override
  String get architectColorBlack => 'Black';

  @override
  String get architectColorWhite => 'White';

  @override
  String get architectColorGray => 'Gray';

  @override
  String get architectColorRed => 'Red';

  @override
  String get architectColorBlue => 'Blue';

  @override
  String get architectColorGreen => 'Green';

  @override
  String get architectColorYellow => 'Yellow';

  @override
  String get architectColorOrange => 'Orange';

  @override
  String get architectColorResidential => 'Residential use';

  @override
  String get architectColorPublicServices => 'Public services';

  @override
  String get architectColorIndustrial => 'Industrial use';

  @override
  String get architectColorStorage => 'Storage';

  @override
  String get architectColorGreenSpace => 'Green space';

  @override
  String get architectColorArable => 'Arable land';

  @override
  String get architectColorPerennial => 'Permanent crops';

  @override
  String get architectColorUncultivated => 'Uncultivated land';

  @override
  String get architectColorForest => 'Forest';

  @override
  String get architectColorRecreationalForest => 'Recreational forest';

  @override
  String get architectColorWater => 'Water';

  @override
  String get architectColorTransport => 'Transport';

  @override
  String get architectColorUtilities => 'Utilities';

  @override
  String get architectColorHousingLowHigh => 'Housing zones · Zhm/Zhg';

  @override
  String get architectColorHousingMediumComplex => 'Housing zones · Zhs/Zhk';

  @override
  String get architectColorVillas => 'Villa zones · base';

  @override
  String get architectColorSpecialPurpose => 'Special purpose';

  @override
  String get architectColorCulturalLand => 'Cultural heritage land';

  @override
  String get architectColorPrimaryRoad => 'Primary roads';

  @override
  String get architectColorSecondaryRoad => 'Secondary roads';

  @override
  String get architectColorCollectingRoad => 'Collector roads';

  @override
  String get architectColorServingRoad => 'Local roads and parking';

  @override
  String get architectColorPedestrian => 'Sidewalks and pedestrian areas';

  @override
  String get architectColorHousingExisting => 'Housing · existing';

  @override
  String get architectColorHousingNew => 'Housing · proposed';

  @override
  String get architectColorPublicExisting => 'Public buildings · existing';

  @override
  String get architectColorPublicNew => 'Public buildings · proposed';

  @override
  String get architectColorHeritageBuilding => 'Heritage buildings';

  @override
  String get architectColorMixedUse => 'Mixed use';

  @override
  String get architectColorSpecialUse => 'Special building areas';

  @override
  String get architectColorRailway => 'Railway land';

  @override
  String get architectColorAgriculture => 'Agricultural land';

  @override
  String get architectRotationPivot => 'Pick centre';

  @override
  String get architectRotationReference => 'Pick point on element';

  @override
  String get architectRotationTarget => 'Pick angle';

  @override
  String get architectRotationPickPivot => 'Pick centre again';

  @override
  String get architectMirrorPickAnchor => 'Pick anchor again';

  @override
  String get architectViewChooseArrow => 'Choose an arrow';

  @override
  String get architectVisibleInSection => 'Visible in section';

  @override
  String architectViewDirectionSide(int side) {
    return 'Viewing direction $side';
  }

  @override
  String get wallPickerTitle => 'Walls';

  @override
  String get wallCategoryExterior => 'Exterior';

  @override
  String get wallCategoryInterior => 'Interior';

  @override
  String get wallCategoryParapet => 'Parapets';

  @override
  String get wallFavorites => 'Favorites';

  @override
  String get wallFavoriteToggle => 'Favorite type';

  @override
  String get wallPickerSearch => 'Type, material, thickness';

  @override
  String get wallPickerEmpty => 'No results';

  @override
  String wallVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '1 variant',
    );
    return '$_temp0';
  }

  @override
  String get wallVariant => 'Variant';

  @override
  String get wallNewVariant => 'New variant';

  @override
  String get wallTypesShort => 'Types';

  @override
  String get wallNoInsulation => 'Uninsulated';

  @override
  String get wallParapetCap => 'Coping cap';

  @override
  String get wallParapetHandrail => 'Handrail';

  @override
  String wallMaterialThickness(String material, String thickness) {
    return '$material $thickness';
  }

  @override
  String get wallNewTypeScope => 'New type · existing walls are preserved';

  @override
  String get wallOptionalName => 'Optional';

  @override
  String get wallSaveToCatalog => 'Save as type';

  @override
  String get wallLayerDetails => 'Layer details';

  @override
  String get wallTypeDetails => 'Type details';

  @override
  String get wallLayerPosition => 'Position';

  @override
  String wallLayerBefore(String layer) {
    return 'Before $layer';
  }

  @override
  String get wallLayerAtEnd => 'At end';

  @override
  String get wallLayerMaterial => 'Material';

  @override
  String get wallLayerCoatings => 'Finishes';

  @override
  String get wallCopyFinish => 'Copy A → B';

  @override
  String get wallCopyFinishHelp => 'Copy finishes from A to unfinished side B';

  @override
  String get wallLayerCoreError =>
      'The core must be continuous and use base materials.';

  @override
  String get wallDrawingMode => 'Drawing mode';

  @override
  String get wallParapetDefaultHeight => 'Default height';

  @override
  String get wallCreate => 'Create';

  @override
  String get wallLayerLimit => 'Up to 20 layers are supported.';

  @override
  String get wallInvalidHeight => 'Enter a positive height.';

  @override
  String wallParapetGroup(String finish, String material) {
    return '$finish · $material';
  }

  @override
  String get roofUiShape => 'Shape';

  @override
  String get roofUiAssembly => 'Build-up';

  @override
  String get roofUiDetails => 'Details';

  @override
  String get roofUiSettings => 'Settings';

  @override
  String get roofUiMethod => 'Method';

  @override
  String get roofUiOnlyPlane => 'This plane';

  @override
  String roofUiWholeRoof(int count) {
    return 'Whole roof ($count)';
  }

  @override
  String get roofUiNewScope => 'For new roofs';

  @override
  String get roofUiSaveDefaults => 'Use for future roofs';

  @override
  String get roofUiScopeHelp =>
      'Only edited fields change. Pipe positions stay with their own plane.';

  @override
  String get roofUiIndependentHelp =>
      'Changing one pitch makes the plane independent.';

  @override
  String get roofUiPreview => 'Diagram';

  @override
  String get roofUiPreviewHelp =>
      'Schematic section; exact dimensions are in the fields.';

  @override
  String get roofUiNumericInvalid => 'Enter a valid value.';

  @override
  String get roofUiLayerPosition => 'Position';

  @override
  String roofUiBeforeLayer(String layer) {
    return 'Before $layer';
  }

  @override
  String get roofUiLayerEnd => 'At end';

  @override
  String get roofUiAbove => 'Above rafters';

  @override
  String get roofUiBetween => 'Between rafters';

  @override
  String get roofUiBelow => 'Below rafters';

  @override
  String get roofUiLayerActions => 'Layer actions';

  @override
  String get roofUiLayerEdit => 'Layer';

  @override
  String get roofUiStructureZone => 'Structural zone';

  @override
  String get roofUiInsulationFit =>
      'Between-rafter insulation exceeds the rafter depth.';

  @override
  String get roofUiParallelZone =>
      'Use one entry for the shared rafter and between-rafter zone.';

  @override
  String get roofUiAutoBreak => 'Automatic break position';

  @override
  String roofUiPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get roofUiAutoPreview => 'New roof';

  @override
  String get roofUiAddRoof => 'Add';

  @override
  String roofUiReplaceRoof(int index, int count) {
    return 'Replace roof $index ($count)';
  }

  @override
  String get roofUiCreate => 'Create';

  @override
  String get roofUiReplace => 'Replace';

  @override
  String get roofUiTarget => 'Apply to';

  @override
  String roofUiGeneratedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planes',
      one: '1 plane',
    );
    return '$_temp0';
  }

  @override
  String get roofUiReviewHelp => 'Other roofs are preserved.';

  @override
  String get roofUiUntouched => 'Keep current';

  @override
  String roofUiReplaceFloor(int count) {
    return 'All on storey ($count)';
  }

  @override
  String get roofUiNewLegend => 'New';

  @override
  String get roofUiKeptLegend => 'Preserved';
}
