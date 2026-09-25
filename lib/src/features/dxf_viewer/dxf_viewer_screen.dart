import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/coordinate_system_service.dart';
import '../../core/services/dwg_converter_service.dart';
import '../../core/services/dxf_exporter_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/widgets/coordinate_settings_dialog.dart';
import '../../core/widgets/viewer_loading_screen.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../home/widgets/share_options_sheet.dart';
import 'models/dxf_display_settings.dart';
import 'models/dxf_models.dart';
import 'parser/dxf_parser.dart';
import 'binary/kcad_service.dart';
import 'rendering/dxf_math.dart';
import 'rendering/dxf_painter.dart';
import 'rendering/dxf_snap_helper.dart';
import 'widgets/dxf_annotation_dialog.dart';
import 'widgets/dxf_display_settings_sheet.dart';
import 'widgets/dxf_entity_context_sheet.dart';
import 'widgets/dxf_import_dialog.dart';
import 'widgets/dxf_info_sheet.dart';
import 'widgets/dxf_layer_sheet.dart';
import 'widgets/dxf_measure_pointer_painter.dart';
import 'widgets/dxf_measurement_canvas_painter.dart';
import 'widgets/dxf_measurement_overlay.dart';
import '../../core/services/project_bundle_service.dart';
import '../project_viewer/widgets/project_presentation_bar.dart';

class DxfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;
  final String? originalFilePath;
  final bool addToRecent;
  final ProjectBundleInfo? projectBundle;
  final int? currentProjectIndex;
  final void Function(int newIndex)? onSwitchProjectItem;

  const DxfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
    this.originalFilePath,
    this.addToRecent = true,
    this.projectBundle,
    this.currentProjectIndex,
    this.onSwitchProjectItem,
  });

  @override
  State<DxfViewerScreen> createState() => _DxfViewerScreenState();
}

class _DxfViewerScreenState extends State<DxfViewerScreen> {
  final TransformationController _transformController = TransformationController();

  DxfDocument? _document;
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;
  int _fileSizeBytes = 0;

  // View state
  DxfCanvasTheme _canvasTheme = DxfCanvasTheme.darkCad;
  String _activeLayout = 'Model';
  bool _showGrid = true;
  double _currentScale = 1.0;
  double _renderScale = 1.0;
  Offset _currentCadCoord = Offset.zero;
  final ValueNotifier<double> _hudScale = ValueNotifier(1.0);
  final ValueNotifier<Offset> _hudCadCoord = ValueNotifier(Offset.zero);
  Timer? _transformSettleTimer;
  Timer? _wheelSettleTimer;
  bool _isGestureActive = false;
  bool _isWheelScrolling = false;
  DxfDisplaySettings _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;
  DxfUnit get _effectiveUnit => _displaySettings.unitOverride ?? _document?.unit ?? DxfUnit.meters;

  // Measurement & Snap tool
  bool _isMeasureMode = false;
  bool _snapEnabled = true;
  DxfMeasureTool _currentMeasureTool = DxfMeasureTool.distance;
  DxfMeasurement? _measurement;
  DxfSnapResult? _hoveredSnap;
  String? _pointerCustomTitle;
  String? _pointerCustomSubText;
  List<DxfAnnotation> _annotations = [];
  final List<File> _importedDxfFiles = [];
  DxfEntity? _selectedEntity;

  // Offset Snapping Pointer State (Aiming reticle & sharp tip)
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  DxfSnapResult? _activeMeasureSnap;
  int _activePointersCount = 0;
  bool _isMultiTouchGesture = false;

  // Desktop Middle Mouse Pan & Keyboard Focus
  Offset? _middlePanStart;
  Matrix4? _middlePanMatrix;
  final FocusNode _focusNode = FocusNode();

  // Layout & viewport
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _transformController.addListener(_onTransformChanged);
    DxfDisplaySettingsService.settingsNotifier.addListener(_onDisplaySettingsChanged);
    _initDisplaySettings();
    _loadDxfFile();
    _loadSavedAnnotations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  String get _annotationsPrefKey => widget.originalFilePath ?? widget.filePath;

  Future<void> _saveAnnotationsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _annotations.map((a) => a.toJson()).toList();
      await prefs.setString('dxf_annotations_$_annotationsPrefKey', jsonEncode(jsonList));
    } on Exception catch (_) {
      // Ignore preference write failure
    }
  }

  Future<void> _loadSavedAnnotations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString('dxf_annotations_$_annotationsPrefKey');
      if (raw == null && widget.originalFilePath != null) {
        // Fallback to widget.filePath for backward compatibility with existing saved annotations
        raw = prefs.getString('dxf_annotations_${widget.filePath}');
      }
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => DxfAnnotation.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _annotations = list;
          });
        }
      }
    } on Exception catch (_) {
      // Ignore corrupted or unreadable preferences
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformSettleTimer?.cancel();
    _wheelSettleTimer?.cancel();
    _transformController.removeListener(_onTransformChanged);
    DxfDisplaySettingsService.settingsNotifier.removeListener(_onDisplaySettingsChanged);
    _transformController.dispose();
    _hudScale.dispose();
    _hudCadCoord.dispose();
    super.dispose();
  }

  void _onDisplaySettingsChanged() {
    if (mounted) {
      setState(() {
        _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;
      });
    }
  }

  Future<void> _initDisplaySettings() async {
    final settings = await DxfDisplaySettingsService.getSettings();
    if (mounted) {
      setState(() {
        _displaySettings = settings;
      });
    }
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    _currentScale = scale;
    if ((scale - _hudScale.value).abs() > 0.001) {
      _hudScale.value = scale;
    }

    // Keep navigation responsive by transforming the cached CAD layer on the GPU first.
    // While actively zooming via wheel, dragging, or middle-mouse panning,
    // skip scheduling CPU repaints so InteractiveViewer transforms the texture layer at 144 FPS.
    if (_isGestureActive || _isWheelScrolling || _middlePanStart != null) {
      return;
    }

    // Repaint scale-dependent strokes and the visible entity set only after input settles.
    _transformSettleTimer?.cancel();
    _transformSettleTimer = Timer(
      const Duration(milliseconds: 100),
      _syncCanvasAfterTransform,
    );
  }

  void _syncCanvasAfterTransform() {
    if (!mounted || _isGestureActive || _isWheelScrolling || _middlePanStart != null) return;
    setState(() {
      _renderScale = _currentScale;
    });
  }

  void _updateHudCadCoord(Offset coord) {
    _currentCadCoord = coord;
    if (_hudCadCoord.value != coord) {
      _hudCadCoord.value = coord;
    }
  }

  Future<void> _loadDxfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        final l10n = mounted ? AppLocalizations.of(context) : null;
        if (mounted) {
          setState(() {
            _errorMessage = l10n?.fileNotFoundOrInaccessible ?? 'File does not exist: ${widget.filePath}';
            _isLoading = false;
          });
        }
        return;
      }

      File? origFile;
      if (widget.originalFilePath != null) {
        origFile = File(widget.originalFilePath!);
        if (await origFile.exists()) {
          _fileSizeBytes = await origFile.length();
        } else {
          _fileSizeBytes = await file.length();
          origFile = null;
        }
      } else {
        _fileSizeBytes = await file.length();
      }
      final doc = await DxfParser.parseFromFile(file, originalFile: origFile);

      if (mounted) {
        setState(() {
          _document = doc;
          _activeLayout = 'Model';
          _isLoading = false;
        });
      }

      _saveToRecentFiles();

      // Fit to screen after frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToScreen();
      });
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._loadDxfFile.fs');
      final l10n = mounted ? AppLocalizations.of(context) : null;
      if (mounted) {
        setState(() {
          _errorMessage = l10n?.fileNotFoundOrInaccessible ?? 'File not found or cannot be accessed.';
          _isLoading = false;
        });
      }
      try {
        await RecentFilesService.removeRecentFile(widget.originalFilePath ?? widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._loadDxfFile.format');
      final l10n = mounted ? AppLocalizations.of(context) : null;
      if (mounted) {
        setState(() {
          _errorMessage = l10n?.errorLoadingDxf(e.message) ?? 'Failed to open DXF file: ${e.message}';
          _isLoading = false;
        });
      }
      try {
        await RecentFilesService.removeRecentFile(widget.originalFilePath ?? widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._loadDxfFile');
      final l10n = mounted ? AppLocalizations.of(context) : null;
      if (mounted) {
        setState(() {
          _errorMessage = l10n?.errorLoadingDxf(e.toString()) ?? 'Failed to open DXF file: $e';
          _isLoading = false;
        });
      }
      try {
        await RecentFilesService.removeRecentFile(widget.originalFilePath ?? widget.filePath);
      } on Exception catch (_) {
        // Ignore recent files cleanup failure
      }
    }
  }

  Future<void> _saveToRecentFiles() async {
    if (!widget.addToRecent) return;
    try {
      final pdfItem = PdfItem(
        path: widget.originalFilePath ?? widget.filePath,
        name: _fileName,
        sizeInBytes: _fileSizeBytes,
        lastOpened: DateTime.now(),
      );
      await RecentFilesService.addRecentFile(pdfItem);
    } on Exception catch (_) {
      // Ignore recent files save failure
    }
  }

  /// Fit the entire DXF drawing inside the available viewport.
  void _fitToScreen() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    _zoomBy(1.35);
  }

  void _zoomOut() {
    _zoomBy(1 / 1.35);
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    if (_viewportSize.isEmpty) return;

    final targetPoint = focalPoint ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentMatrix = _transformController.value;

    final translation = currentMatrix.getTranslation();
    final scale = currentMatrix.getMaxScaleOnAxis();

    final newScale = (scale * factor).clamp(0.001, 1000.0);

    final dx = targetPoint.dx - (targetPoint.dx - translation.x) * (newScale / scale);
    final dy = targetPoint.dy - (targetPoint.dy - translation.y) * (newScale / scale);

    final newMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);

    _transformController.value = newMatrix;
  }

  Rect get _currentBounds {
    if (_document == null) return const Rect.fromLTWH(0, 0, 100, 100);
    if (_activeLayout != 'Model') {
      return _document!.layoutBounds[_activeLayout] ?? _document!.bounds;
    }
    return _document!.bounds;
  }

  void _switchLayout(String layout) {
    if (_activeLayout == layout) return;
    setState(() {
      _activeLayout = layout;
      _selectedEntity = null;
      _measurement = null;
      _hoveredSnap = null;
    });
    _fitToScreen();
  }

  Offset _sceneToCad(Offset scenePoint) {
    if (_document == null || _viewportSize.isEmpty) return Offset.zero;

    final bounds = _currentBounds;
    final double docW = math.max(bounds.width, 1.0);
    final double docH = math.max(bounds.height, 1.0);

    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double fitScale = math.min(availW / docW, availH / docH);

    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = bounds.left;
    final double maxY = bounds.bottom > bounds.top
        ? bounds.bottom
        : bounds.top;

    final double cadX = minX + (scenePoint.dx - tx) / fitScale;
    final double cadY = maxY - (scenePoint.dy - ty) / fitScale;

    return Offset(cadX, cadY);
  }

  Offset _cadToScene(Offset cadPoint) {
    if (_document == null || _viewportSize.isEmpty) return cadPoint;
    final double fitScale = _getCadFitScale();
    final bounds = _currentBounds;
    final double docW = math.max(bounds.width, 1.0);
    final double docH = math.max(bounds.height, 1.0);
    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;
    final double minX = bounds.left;
    final double maxY = bounds.bottom > bounds.top
        ? bounds.bottom
        : bounds.top;

    return Offset(
      tx + (cadPoint.dx - minX) * fitScale,
      ty + (maxY - cadPoint.dy) * fitScale,
    );
  }

  Offset _cadToScreen(Offset cadPoint) {
    final scenePos = _cadToScene(cadPoint);
    return MatrixUtils.transformPoint(_transformController.value, scenePos);
  }

  Rect? _getVisibleCadRect() {
    if (_document == null || _viewportSize.isEmpty) return null;
    try {
      final pTopLeft = _transformController.toScene(Offset.zero);
      final pBottomRight = _transformController.toScene(
        Offset(_viewportSize.width, _viewportSize.height),
      );

      final cadTopLeft = _sceneToCad(pTopLeft);
      final cadBottomRight = _sceneToCad(pBottomRight);

      final left = math.min(cadTopLeft.dx, cadBottomRight.dx);
      final right = math.max(cadTopLeft.dx, cadBottomRight.dx);
      final bottom = math.min(cadTopLeft.dy, cadBottomRight.dy);
      final top = math.max(cadTopLeft.dy, cadBottomRight.dy);

      // Add 10% safety margin around viewport for ultra-smooth panning
      final marginX = (right - left) * 0.1;
      final marginY = (top - bottom) * 0.1;

      final rect = Rect.fromLTRB(
        left - marginX,
        bottom - marginY,
        right + marginX,
        top + marginY,
      );

      // Clamp to current layout bounds (with 5% buffer) so it never queries beyond drawing extents
      final bounds = _currentBounds;
      final maxDocExtent = bounds.inflate(bounds.longestSide * 0.05 + 10.0);
      return rect.intersect(maxDocExtent);
    } catch (_) {
      return null;
    }
  }

  double _getCadFitScale() {
    if (_document == null || _viewportSize.isEmpty) return 1.0;
    final bounds = _currentBounds;
    final double docW = math.max(bounds.width, 1.0);
    final double docH = math.max(bounds.height, 1.0);
    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);
    return math.min(availW / docW, availH / docH);
  }

  void _handleMeasurePointerDown(PointerDownEvent event) {
    if (!_isMeasureMode || _document == null) return;
    _activePointersCount++;
    if (_activePointersCount == 1 || event.kind == PointerDeviceKind.mouse) {
      _isMultiTouchGesture = false;
    } else if (_activePointersCount > 1) {
      // Multi-touch: mark gesture as multi-touch zoom/pan, cancel single finger measurement
      _isMultiTouchGesture = true;
      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeMeasureSnap = null;
      });
      return;
    }

    // Only start a single finger measure pointer if we are NOT in the middle of a multi-touch sequence
    if (!_isMultiTouchGesture) {
      _updateMeasurePointer(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse);
    }
  }

  void _handleMeasurePointerMove(PointerMoveEvent event) {
    if (!_isMeasureMode || _document == null) return;
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
    }
    if (_isMultiTouchGesture || _activePointersCount != 1) return;
    _updateMeasurePointer(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse);
  }

  void _updateMeasurePointer(Offset screenPos, {bool isMouse = false}) {
    final touchPos = screenPos;
    // On mouse/desktop: target tip is EXACTLY at the cursor (zero offset).
    // On touch/mobile: position target tip 56 pixels directly above finger so finger doesn't obscure view.
    final targetPos = isMouse ? screenPos : (screenPos - const Offset(0, 56.0));
    final scenePt = _transformController.toScene(targetPos);
    final rawCadPt = _sceneToCad(scenePt);

    DxfSnapResult? snap;
    Offset? snappedScreen;

    if (_snapEnabled && _document != null) {
      final fitScale = _getCadFitScale();
      final toleranceCad = 22.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
      Offset? basePoint;
      if (_currentMeasureTool == DxfMeasureTool.distance) {
        basePoint = (_measurement != null &&
                _measurement!.tool == DxfMeasureTool.distance &&
                _measurement!.p1Cad != null &&
                _measurement!.p2Cad == null)
            ? _measurement!.p1Cad
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.area) {
        basePoint = null; // Do NOT use perpendicular (right-angle) snap for area measurement!
      } else if (_currentMeasureTool == DxfMeasureTool.angle) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.angle)
            ? _measurement!.angleVertex
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.radius) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.radius)
            ? _measurement!.circleCenter
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.annotation) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.annotation)
            ? _measurement!.annotationTip
            : null;
      }

      snap = DxfSnapHelper.findSnapPoint(
        document: _document!,
        cadPoint: rawCadPt,
        toleranceCad: toleranceCad,
        basePoint: basePoint,
      );

      if (snap != null) {
        if (_activeMeasureSnap == null || _activeMeasureSnap!.point != snap.point) {
          HapticFeedback.selectionClick();
        }
        snappedScreen = _cadToScreen(snap.point);
      }
    }

    final effectiveCad = snap != null ? snap.point : rawCadPt;
    _updateHudCadCoord(effectiveCad);
    String? title;
    String? subText;

    switch (_currentMeasureTool) {
      case DxfMeasureTool.distance:
        title = (_measurement != null &&
                _measurement!.tool == DxfMeasureTool.distance &&
                _measurement!.p1Cad != null &&
                _measurement!.p2Cad == null)
            ? '2nd Point'
            : '1st Point';
        break;

      case DxfMeasureTool.area:
        final count = (_measurement?.tool == DxfMeasureTool.area) ? (_measurement?.areaPoints.length ?? 0) : 0;
        title = 'Vertex ${count + 1}';
        if (count > 0 && _measurement!.areaPoints.isNotEmpty) {
          final lastPt = _measurement!.areaPoints.last;
          final segDist = (effectiveCad - lastPt).distance;
          subText = 'Segment: ${DxfMath.formatDistance(segDist, unit: _effectiveUnit)} m';
        }
        break;

      case DxfMeasureTool.angle:
        if (_measurement == null || _measurement!.tool != DxfMeasureTool.angle || _measurement!.angleVertex == null) {
          title = 'Vertex';
        } else if (_measurement!.angleP1 == null) {
          title = 'Arm 1';
        } else {
          title = 'Arm 2';
          if (_measurement!.angleVertex != null && _measurement!.angleP1 != null) {
            final angle = DxfMath.calculateAngleBetweenVectors(
              _measurement!.angleVertex!,
              _measurement!.angleP1!,
              effectiveCad,
            );
            subText = '∠ ~ ${angle.toStringAsFixed(1)}°';
          }
        }
        break;

      case DxfMeasureTool.radius:
        title = 'Radius / Diameter';
        if (_document != null) {
          final fitScale = _getCadFitScale();
          final toleranceCad = 26.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
          final circleArc = DxfSnapHelper.findClosestCircleOrArc(
            document: _document!,
            cadPoint: effectiveCad,
            toleranceCad: toleranceCad,
          );
          if (circleArc != null) {
            subText = 'R = ${DxfMath.formatDistance(circleArc.radius, unit: _effectiveUnit)} m • Ø = ${DxfMath.formatDistance(circleArc.radius * 2.0, unit: _effectiveUnit)} m';
          }
        }
        break;

      case DxfMeasureTool.annotation:
        if (_measurement == null || _measurement!.tool != DxfMeasureTool.annotation || _measurement!.annotationTip == null) {
          title = 'Arrow Tip';
          subText = 'Snap to feature';
        } else {
          title = 'Text Note Position';
          final dist = (effectiveCad - _measurement!.annotationTip!).distance;
          subText = 'Leader: ${DxfMath.formatDistance(dist, unit: _effectiveUnit)} m';
        }
        break;
    }

    setState(() {
      _touchScreenPos = touchPos;
      _targetScreenPos = targetPos;
      _snappedScreenPos = snappedScreen;
      _activeMeasureSnap = snap;
      _currentCadCoord = effectiveCad;
      _pointerCustomTitle = title;
      _pointerCustomSubText = subText;
    });
  }

  void _applyMeasurementPoint(Offset cadPt) {
    HapticFeedback.mediumImpact();
    setState(() {
      switch (_currentMeasureTool) {
        case DxfMeasureTool.distance:
          if (_measurement == null ||
              _measurement!.tool != DxfMeasureTool.distance ||
              _measurement!.p1Cad == null ||
              _measurement!.p2Cad != null) {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.distance,
              p1Cad: cadPt,
            );
          } else {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.distance,
              p1Cad: _measurement!.p1Cad,
              p2Cad: cadPt,
            );
          }
          break;

        case DxfMeasureTool.area:
          List<Offset> pts = [];
          if (_measurement != null &&
              _measurement!.tool == DxfMeasureTool.area &&
              !_measurement!.isAreaClosed) {
            pts = List<Offset>.from(_measurement!.areaPoints);
          }
          if (pts.length >= 3 && _isNearFirstAreaPoint(cadPt, pts)) {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.area,
              areaPoints: pts,
              isAreaClosed: true,
            );
            break;
          }
          pts.add(cadPt);
          _measurement = DxfMeasurement(
            tool: DxfMeasureTool.area,
            areaPoints: pts,
            isAreaClosed: false,
          );
          break;

        case DxfMeasureTool.angle:
          if (_measurement == null ||
              _measurement!.tool != DxfMeasureTool.angle ||
              _measurement!.angleVertex == null ||
              (_measurement!.angleP1 != null && _measurement!.angleP2 != null)) {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.angle,
              angleVertex: cadPt,
            );
          } else if (_measurement!.angleP1 == null) {
            _measurement = _measurement!.copyWith(angleP1: cadPt);
          } else {
            _measurement = _measurement!.copyWith(angleP2: cadPt);
          }
          break;

        case DxfMeasureTool.radius:
          // Check for direct click on circle/arc
          if (_document != null) {
            final fitScale = _getCadFitScale();
            final toleranceCad = 26.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
            final circleArc = DxfSnapHelper.findClosestCircleOrArc(
              document: _document!,
              cadPoint: cadPt,
              toleranceCad: toleranceCad,
            );

            if (circleArc != null) {
              _measurement = DxfMeasurement(
                tool: DxfMeasureTool.radius,
                circleCenter: circleArc.center,
                radius: circleArc.radius,
                isArc: circleArc.isArc,
                arcLength: circleArc.arcLength,
                circlePoints: [circleArc.samplePoint],
              );
              break;
            }
          }

          // Fallback: 3-point circle
          List<Offset> cPts = [];
          if (_measurement != null &&
              _measurement!.tool == DxfMeasureTool.radius &&
              _measurement!.circleCenter == null &&
              _measurement!.circlePoints.length < 3) {
            cPts = List<Offset>.from(_measurement!.circlePoints);
          }
          cPts.add(cadPt);

          if (cPts.length == 3) {
            final solved = DxfMath.circleFrom3Points(cPts[0], cPts[1], cPts[2]);
            if (solved != null) {
              _measurement = DxfMeasurement(
                tool: DxfMeasureTool.radius,
                circleCenter: solved.center,
                radius: solved.radius,
                circlePoints: cPts,
              );
            } else {
              _measurement = DxfMeasurement(
                tool: DxfMeasureTool.radius,
                circlePoints: cPts,
              );
            }
          } else {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.radius,
              circlePoints: cPts,
            );
          }
          break;

        case DxfMeasureTool.annotation:
          if (_measurement == null ||
              _measurement!.tool != DxfMeasureTool.annotation ||
              _measurement!.annotationTip == null) {
            _measurement = DxfMeasurement(
              tool: DxfMeasureTool.annotation,
              annotationTip: cadPt,
            );
          } else {
            final tip = _measurement!.annotationTip!;
            final textPos = cadPt;
            _measurement = DxfMeasurement(tool: DxfMeasureTool.annotation);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _openAnnotationDialog(arrowTip: tip, textPos: textPos);
            });
          }
          break;
      }
    });
  }

  Future<void> _openAnnotationDialog({
    DxfAnnotation? annotation,
    required Offset arrowTip,
    required Offset textPos,
  }) async {
    final result = await showDialog<DxfAnnotation>(
      context: context,
      builder: (ctx) => DxfAnnotationDialog(
        initialAnnotation: annotation,
        arrowTipCad: arrowTip,
        textPosCad: textPos,
        onDelete: annotation != null
            ? () {
                setState(() {
                  _annotations.removeWhere((a) => a.id == annotation.id);
                });
                _saveAnnotationsToPrefs();
              }
            : null,
      ),
    );

    if (result != null) {
      setState(() {
        if (annotation != null) {
          final idx = _annotations.indexWhere((a) => a.id == annotation.id);
          if (idx != -1) {
            _annotations[idx] = result;
          } else {
            _annotations.add(result);
          }
        } else {
          _annotations.add(result);
        }
      });
      _saveAnnotationsToPrefs();
    }
  }

  Future<void> _saveAsAnnotatedDxf() async {
    if (_document == null) return;
    try {
      final sourcePath = widget.originalFilePath ?? widget.filePath;
      final originalFile = File(sourcePath);
      final dir = originalFile.parent;
      final displayName = widget.title ?? originalFile.uri.pathSegments.last;
      final baseName = displayName
          .replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\.dwg$', caseSensitive: false), '');
      final suffix = _importedDxfFiles.isNotEmpty
          ? (_annotations.isNotEmpty ? '_merged_annotated.dxf' : '_merged.dxf')
          : '_annotated.dxf';
      final outputFileName = '$baseName$suffix';
      File outputFile = File('${dir.path}/$outputFileName');

      File effectiveBase = File(widget.filePath);
      if (widget.filePath.toLowerCase().endsWith('.dwg')) {
        final convertedPath = await DwgConverterService.convertDwgToDxf(widget.filePath);
        effectiveBase = File(convertedPath);
      }

      try {
        await DxfExporterService.exportMergedDxf(
          baseFile: effectiveBase,
          importedFiles: _importedDxfFiles,
          annotations: _annotations,
          outputFile: outputFile,
        );
      } on FileSystemException {
        final docsDir = await getApplicationDocumentsDirectory();
        outputFile = File('${docsDir.path}/$outputFileName');
        await DxfExporterService.exportMergedDxf(
          baseFile: effectiveBase,
          importedFiles: _importedDxfFiles,
          annotations: _annotations,
          outputFile: outputFile,
        );
      }

      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedDxf(outputFileName)),
            backgroundColor: const Color(0xFF1B2433),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: l10n.share,
              textColor: const Color(0xFF00E5FF),
              onPressed: () {
                Share.shareXFiles([XFile(outputFile.path)], subject: outputFileName);
              },
            ),
          ),
        );
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._exportDxf.fs');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSaveDxf(e.message)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._exportDxf');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSaveDxf(e.toString())),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportKcad() async {
    if (_document == null) return;
    try {
      final baseName = (widget.title ?? widget.filePath.split(Platform.pathSeparator).last)
          .replaceAll(RegExp(r'\.(dxf|dwg|kcad)$', caseSensitive: false), '');
      final suffix = _annotations.isNotEmpty ? '_annotated.kcad' : '_fast.kcad';
      final outputFileName = '$baseName$suffix';

      final dir = await getApplicationDocumentsDirectory();
      final outputFile = File('${dir.path}/$outputFileName');

      var docToExport = _document!;
      if (_annotations.isNotEmpty) {
        final newLayers = Map<String, DxfLayer>.from(docToExport.layers);
        if (!newLayers.containsKey('MARKUP')) {
          newLayers['MARKUP'] = DxfLayer(
            name: 'MARKUP',
            colorIndex: 2,
            trueColor: 0xFFFFD600,
            isVisible: true,
            isFrozen: false,
          );
        }

        final addedEntities = <DxfEntity>[];
        for (final anno in _annotations) {
          addedEntities.add(DxfLeader(
            vertices: [anno.arrowTipCad, anno.textPosCad],
            hasArrowhead: true,
            layer: 'MARKUP',
            trueColor: anno.colorValue,
          ));
          addedEntities.add(DxfMText(
            rawText: anno.text,
            cleanText: anno.text,
            insertPoint: anno.textPosCad,
            height: anno.textHeight ?? 2.5,
            layer: 'MARKUP',
            trueColor: anno.colorValue,
            attachmentPoint: 1,
          ));
        }

        final allEntities = List<DxfEntity>.from(docToExport.entities)..addAll(addedEntities);
        final stats = Map<String, int>.from(docToExport.entityStats);
        stats['LEADER'] = (stats['LEADER'] ?? 0) + _annotations.length;
        stats['MTEXT'] = (stats['MTEXT'] ?? 0) + _annotations.length;

        docToExport = DxfDocument(
          layers: newLayers,
          blocks: docToExport.blocks,
          entities: allEntities,
          headerVars: docToExport.headerVars,
          textStyles: docToExport.textStyles,
          bounds: docToExport.bounds,
          entityStats: stats,
          lineTypes: docToExport.lineTypes,
        );
      }

      await KcadService.exportKcadFile(docToExport, outputFile.path);

      if (mounted) {
        final sizeMb = (await outputFile.length()) / (1024 * 1024);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved fast KCAD: $outputFileName (${sizeMb.toStringAsFixed(2)} MB)'),
            backgroundColor: const Color(0xFF1B2433),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              textColor: const Color(0xFF00E5FF),
              onPressed: () {
                Share.shareXFiles([XFile(outputFile.path)], subject: outputFileName);
              },
            ),
          ),
        );
      }
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._exportKcad');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save KCAD: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleUndoAreaPoint() {
    if (_measurement != null && _measurement!.areaPoints.isNotEmpty) {
      final pts = List<Offset>.from(_measurement!.areaPoints)..removeLast();
      setState(() {
        _measurement = _measurement!.copyWith(
          areaPoints: pts,
          isAreaClosed: false,
        );
      });
    }
  }

  void _handleCloseAreaPolygon() {
    if (_measurement != null && _measurement!.areaPoints.length >= 3) {
      setState(() {
        _measurement = _measurement!.copyWith(isAreaClosed: true);
      });
    }
  }

  bool _isNearFirstAreaPoint(Offset cadPt, List<Offset> points) {
    if (points.isEmpty) return false;
    final clickScreen = _cadToScreen(cadPt);
    final firstScreen = _cadToScreen(points.first);
    return (clickScreen - firstScreen).distance <= 18.0;
  }

  bool _closeAreaPolygonFromSecondaryClick() {
    if (_currentMeasureTool != DxfMeasureTool.area ||
        _measurement == null ||
        _measurement!.tool != DxfMeasureTool.area ||
        _measurement!.isAreaClosed ||
        _measurement!.areaPoints.length < 3) {
      return false;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _measurement = _measurement!.copyWith(isAreaClosed: true);
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeMeasureSnap = null;
      _pointerCustomTitle = null;
      _pointerCustomSubText = null;
    });
    return true;
  }

  void _handleMeasurePointerUp(PointerUpEvent event) {
    if (!_isMeasureMode) return;
    _activePointersCount = math.max(0, _activePointersCount - 1);

    if (_isMultiTouchGesture) {
      // If we were in a multi-touch zoom/pan gesture, do NOT place any measurement point
      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeMeasureSnap = null;
        _pointerCustomTitle = null;
        _pointerCustomSubText = null;
      });
      if (_activePointersCount == 0) {
        _isMultiTouchGesture = false; // Reset only when all fingers are lifted
      }
      return;
    }

    if (_touchScreenPos != null) {
      final finalCadPt = _activeMeasureSnap?.point ?? _currentCadCoord;
      _applyMeasurementPoint(finalCadPt);

      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeMeasureSnap = null;
        _pointerCustomTitle = null;
        _pointerCustomSubText = null;
      });
    }
  }

  void _handleMeasurePointerCancel(PointerCancelEvent event) {
    _activePointersCount = 0;
    _isMultiTouchGesture = false;
    setState(() {
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeMeasureSnap = null;
      _pointerCustomTitle = null;
      _pointerCustomSubText = null;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _isGestureActive = false;
      _isWheelScrolling = true;
      _transformSettleTimer?.cancel();
      _wheelSettleTimer?.cancel();
      _wheelSettleTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _isWheelScrolling = false;
        _syncCanvasAfterTransform();
      });
    }
  }

  void _handleGeneralPointerDown(PointerDownEvent event) {
    if ((event.buttons & kTertiaryButton) != 0) {
      _middlePanStart = event.position;
      _middlePanMatrix = _transformController.value.clone();
      _transformSettleTimer?.cancel();
      _wheelSettleTimer?.cancel();
      return;
    }

    if (_isMeasureMode && (event.buttons & kSecondaryButton) != 0) {
      _closeAreaPolygonFromSecondaryClick();
      return;
    }

    if (_isMeasureMode) {
      _handleMeasurePointerDown(event);
    }
  }

  void _handleGeneralPointerMove(PointerMoveEvent event) {
    if (_middlePanStart != null && _middlePanMatrix != null) {
      final delta = event.position - _middlePanStart!;
      final newMatrix = _middlePanMatrix!.clone();
      final translation = newMatrix.getTranslation();
      newMatrix.setTranslationRaw(translation.x + delta.dx, translation.y + delta.dy, translation.z);
      _transformController.value = newMatrix;
      return;
    }

    if (_isMeasureMode) {
      _handleMeasurePointerMove(event);
    }
  }

  void _handleGeneralPointerUp(PointerUpEvent event) {
    if (_middlePanStart != null) {
      _middlePanStart = null;
      _middlePanMatrix = null;
      if (!_isWheelScrolling && !_isGestureActive) {
        _transformSettleTimer?.cancel();
        _transformSettleTimer = Timer(const Duration(milliseconds: 100), _syncCanvasAfterTransform);
      }
      return;
    }

    if (_isMeasureMode) {
      _handleMeasurePointerUp(event);
    }
  }

  void _handleGeneralPointerCancel(PointerCancelEvent event) {
    _middlePanStart = null;
    _middlePanMatrix = null;
    if (_isMeasureMode) {
      _handleMeasurePointerCancel(event);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (widget.projectBundle != null) {
        final currentIndex = widget.currentProjectIndex ?? 0;
        final total = widget.projectBundle!.files.length;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.pageDown) {
          if (currentIndex < total - 1 && widget.onSwitchProjectItem != null) {
            widget.onSwitchProjectItem!(currentIndex + 1);
            return;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.pageUp) {
          if (currentIndex > 0 && widget.onSwitchProjectItem != null) {
            widget.onSwitchProjectItem!(currentIndex - 1);
            return;
          }
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.f3) {
        setState(() {
          _snapEnabled = !_snapEnabled;
          if (!_snapEnabled) {
            _hoveredSnap = null;
            _activeMeasureSnap = null;
            _snappedScreenPos = null;
          }
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_snapEnabled ? 'Object Snap (OSNAP) ON [F3]' : 'Object Snap (OSNAP) OFF [F3]'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          if (_measurement != null) {
            _measurement = null;
            _hoveredSnap = null;
            _touchScreenPos = null;
            _targetScreenPos = null;
            _snappedScreenPos = null;
            _activeMeasureSnap = null;
          } else if (_isMeasureMode) {
            _isMeasureMode = false;
          }
        });
      }
    }
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (_document == null) return;

    final scenePoint = _transformController.toScene(details.localPosition);
    final rawCadPoint = _sceneToCad(scenePoint);

    // If snapped, use the exact snapped landmark point
    final cadPoint = (_isMeasureMode && _snapEnabled && _hoveredSnap != null)
        ? _hoveredSnap!.point
        : rawCadPoint;

    _updateHudCadCoord(cadPoint);
    setState(() {
      _currentCadCoord = cadPoint;
    });

    if (_isMeasureMode) {
      _applyMeasurementPoint(cadPoint);
    } else if (_annotations.isNotEmpty) {
      final fitScale = _getCadFitScale();
      final hitToleranceCad = 24.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
      for (final anno in _annotations) {
        if ((cadPoint - anno.arrowTipCad).distance <= hitToleranceCad ||
            (cadPoint - anno.textPosCad).distance <= hitToleranceCad * 2.5) {
          _openAnnotationDialog(
            annotation: anno,
            arrowTip: anno.arrowTipCad,
            textPos: anno.textPosCad,
          );
          return;
        }
      }
    }
  }

  void _handleCanvasContextTap(Offset localPos) {
    if (_document == null) return;
    final scenePoint = _transformController.toScene(localPos);
    final cadPoint = _sceneToCad(scenePoint);

    final fitScale = _getCadFitScale();
    final toleranceCad = 26.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));

    final entity = DxfSnapHelper.hitTestEntity(
      document: _document!,
      cadPoint: cadPoint,
      toleranceCad: toleranceCad,
    );

    if (entity != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _selectedEntity = entity;
      });

      final layerName = entity.layer;
      final layer = _document!.layers[layerName];

      DxfEntityContextSheet.show(
        context: context,
        entity: entity,
        document: _document!,
        isDark: _canvasTheme.isDark,
        onHideLayer: () {
          if (layer != null) {
            setState(() {
              layer.isVisible = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Layer "$layerName" hidden'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: const Color(0xFF00E5FF),
                  onPressed: () {
                    setState(() {
                      layer.isVisible = true;
                    });
                  },
                ),
              ),
            );
          }
        },
        onIsolateLayer: () {
          setState(() {
            for (final l in _document!.layers.values) {
              l.isVisible = (l.name == layerName);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Isolated layer "$layerName"'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Show All',
                textColor: const Color(0xFF00E5FF),
                onPressed: () {
                  setState(() {
                    for (final l in _document!.layers.values) {
                      l.isVisible = true;
                    }
                  });
                },
              ),
            ),
          );
        },
        onShowAllLayers: () {
          setState(() {
            for (final l in _document!.layers.values) {
              l.isVisible = true;
            }
          });
        },
        onOpenLayerManager: _showLayersSheet,
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _selectedEntity = null;
          });
        }
      });
    } else {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No CAD entity found at cursor position'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (_document == null) return;
    final scenePoint = _transformController.toScene(event.localPosition);
    final cadPoint = _sceneToCad(scenePoint);

    if (!_isMeasureMode) {
      _updateHudCadCoord(cadPoint);
      return;
    }

    DxfSnapResult? snap;
    if (_isMeasureMode && _snapEnabled) {
      final fitScale = _getCadFitScale();
      // 18 screen pixels tolerance converted to CAD coordinates
      final toleranceCad = 18.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
      Offset? basePoint;
      if (_currentMeasureTool == DxfMeasureTool.distance) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.distance && _measurement!.p2Cad == null)
            ? _measurement!.p1Cad
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.area) {
        basePoint = null; // Do NOT use perpendicular snap for area measurement!
      } else if (_currentMeasureTool == DxfMeasureTool.angle) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.angle)
            ? _measurement!.angleVertex
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.radius) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.radius)
            ? _measurement!.circleCenter
            : null;
      } else if (_currentMeasureTool == DxfMeasureTool.annotation) {
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.annotation)
            ? _measurement!.annotationTip
            : null;
      }

      snap = DxfSnapHelper.findSnapPoint(
        document: _document!,
        cadPoint: cadPoint,
        toleranceCad: toleranceCad,
        basePoint: basePoint,
      );
    }

    final effectiveCadPoint = snap != null ? snap.point : cadPoint;
    _updateHudCadCoord(effectiveCadPoint);
    setState(() {
      _currentCadCoord = effectiveCadPoint;
      _hoveredSnap = snap;
    });
  }

  /// Handles importing an additional DXF drawing into the current workspace.
  Future<void> _importDxfFile() async {
    if (_document == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final lower = filePath.toLowerCase();

      if (!lower.endsWith('.dxf') && !lower.endsWith('.dwg')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a valid .dxf or .dwg file to import.')),
          );
        }
        return;
      }

      File effectiveDxfFile;
      File? originalSourceFile;
      if (lower.endsWith('.dwg')) {
        originalSourceFile = File(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Converting DWG to DXF for import...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        final convertedDxfPath = await DwgConverterService.convertDwgToDxf(filePath);
        effectiveDxfFile = File(convertedDxfPath);
      } else {
        effectiveDxfFile = File(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parsing DXF for import...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      final importedDoc = await DxfParser.parseFromFile(effectiveDxfFile, originalFile: originalSourceFile);
      final activeCrs = CoordinateSystemService.activeSystemNotifier.value;

      if (!mounted) return;

      final action = await DxfImportDialog.show(
        context: context,
        file: File(filePath),
        currentDoc: _document!,
        importedDoc: importedDoc,
        activeCrs: activeCrs,
      );

      if (action == null || !mounted) return;

      // Merge imported document into current document
      final mergedLayers = Map<String, DxfLayer>.from(_document!.layers);
      for (final entry in importedDoc.layers.entries) {
        if (!mergedLayers.containsKey(entry.key)) {
          mergedLayers[entry.key] = entry.value;
        }
      }

      final mergedBlocks = Map<String, DxfBlock>.from(_document!.blocks);
      for (final entry in importedDoc.blocks.entries) {
        if (!mergedBlocks.containsKey(entry.key)) {
          mergedBlocks[entry.key] = entry.value;
        }
      }

      final mergedTextStyles = Map<String, DxfTextStyle>.from(_document!.textStyles);
      for (final entry in importedDoc.textStyles.entries) {
        if (!mergedTextStyles.containsKey(entry.key)) {
          mergedTextStyles[entry.key] = entry.value;
        }
      }

      final mergedLineTypes = Map<String, List<double>>.from(_document!.lineTypes);
      for (final entry in importedDoc.lineTypes.entries) {
        if (!mergedLineTypes.containsKey(entry.key)) {
          mergedLineTypes[entry.key] = entry.value;
        }
      }

      final mergedEntities = List<DxfEntity>.from(_document!.entities)..addAll(importedDoc.entities);
      final mergedBounds = _document!.bounds.expandToInclude(importedDoc.bounds);

      final mergedStats = Map<String, int>.from(_document!.entityStats);
      for (final entry in importedDoc.entityStats.entries) {
        mergedStats[entry.key] = (mergedStats[entry.key] ?? 0) + entry.value;
      }

      setState(() {
        _importedDxfFiles.add(effectiveDxfFile);
        _document = DxfDocument(
          layers: mergedLayers,
          blocks: mergedBlocks,
          entities: mergedEntities,
          headerVars: _document!.headerVars,
          textStyles: mergedTextStyles,
          bounds: mergedBounds,
          entityStats: mergedStats,
          lineTypes: mergedLineTypes,
        );
      });

      final importedName = filePath.split(Platform.pathSeparator).last;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.importedDxfSuccess(importedDoc.totalEntities, importedName)),
          action: SnackBarAction(
            label: l10n.fitScreen,
            onPressed: _fitToScreen,
          ),
        ),
      );
    } on DwgConversionException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._importFile.dwg');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorImportingDxf(e.message)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._importDxf.fs');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorImportingDxf(e.message))),
        );
      }
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._importDxf.format');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorImportingDxf(e.message))),
        );
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._importDxf');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorImportingDxf(e.toString()))),
        );
      }
    }
  }

  void _showLayersSheet() {
    if (_document == null) return;
    DxfLayerSheet.show(
      context: context,
      document: _document!,
      isDark: _canvasTheme.isDark,
      onLayersChanged: () {
        setState(() {});
      },
    );
  }

  void _showInfoSheet() {
    if (_document == null) return;
    DxfInfoSheet.show(
      context: context,
      document: _document!,
      fileName: _fileName,
      fileSizeBytes: _fileSizeBytes,
    );
  }

  void _showCoordinateSettings() async {
    final selected = await CoordinateSettingsDialog.show(context);
    if (selected != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _shareDxf() async {
    String fileToShare = widget.filePath;

    if (_importedDxfFiles.isNotEmpty || _annotations.isNotEmpty) {
      try {
        File effectiveBase = File(widget.filePath);
        if (widget.filePath.toLowerCase().endsWith('.dwg')) {
          final convertedPath = await DwgConverterService.convertDwgToDxf(widget.filePath);
          effectiveBase = File(convertedPath);
        }

        final sourcePath = widget.originalFilePath ?? widget.filePath;
        final displayName = widget.title ?? File(sourcePath).uri.pathSegments.last;
        final baseName = displayName
            .replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\.dwg$', caseSensitive: false), '');
        final suffix = _importedDxfFiles.isNotEmpty
            ? (_annotations.isNotEmpty ? '_merged_annotated.dxf' : '_merged.dxf')
            : '_annotated.dxf';
        final outputFileName = '$baseName$suffix';

        final tempDir = await getTemporaryDirectory();
        final tempOutputFile = File('${tempDir.path}/$outputFileName');

        await DxfExporterService.exportMergedDxf(
          baseFile: effectiveBase,
          importedFiles: _importedDxfFiles,
          annotations: _annotations,
          outputFile: tempOutputFile,
        );

        fileToShare = tempOutputFile.path;
      } catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'DxfViewer._shareDxf.export');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareOptionsSheet(filePath: fileToShare),
    );
  }

  Future<void> _printDxf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName);
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._printDxf.fs');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.printPreviewUnavailable(e.message))),
        );
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DxfViewer._printDxf');
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.printPreviewUnavailable(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final isDwg = _fileName.toLowerCase().endsWith('.dwg');
      final l10n = context.l10n;
      return ViewerLoadingScreen(
        fileName: _fileName,
        fileSizeBytes: _fileSizeBytes > 0 ? _fileSizeBytes : null,
        icon: Icons.architecture_rounded,
        accentColor: const Color(0xFFFF9800),
        loadingTitle: isDwg ? l10n.convertingDwg : l10n.loadingCad,
        statusMessage: l10n.statusAnalyzingCad,
        onCancel: () => Navigator.of(context).pop(false),
      );
    }

    final theme = Theme.of(context);
    final activeCrs = CoordinateSystemService.activeSystemNotifier.value;

    return Scaffold(
      backgroundColor: _canvasTheme.bgColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                // Layout Switcher Tabs (Model | Layout1 | Sheet1 ...)
                if (_document != null && _document!.layouts.length > 1)
                  Flexible(
                    child: Container(
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _document!.layouts.map((layout) {
                            final isSelected = layout == _activeLayout;
                            return InkWell(
                              onTap: () => _switchLayout(layout),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF9800)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      layout == 'Model' ? Icons.grid_4x4 : Icons.article_outlined,
                                      size: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      layout,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : (Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white70
                                                : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                const Spacer(),

                // Fit to screen (Zoom Extents)
                IconButton(
                  icon: const Icon(Icons.fit_screen_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Fit to Screen',
                  onPressed: _document != null ? _fitToScreen : null,
                ),

                // Import DXF
                IconButton(
                  icon: const Icon(Icons.add_to_photos_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Import',
                  onPressed: _document != null ? _importDxfFile : null,
                ),

                // Layer Manager
                IconButton(
                  icon: const Icon(Icons.layers_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'CAD Layers',
                  onPressed: _document != null ? _showLayersSheet : null,
                ),

                // Measurement & Markup Tool
                IconButton(
                  icon: Icon(
                    Icons.straighten,
                    size: 20,
                    color: _isMeasureMode ? const Color(0xFFFF5252) : null,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _isMeasureMode
                      ? 'Exit Measure & Markup'
                      : 'Measure Tools',
                  onPressed: _document != null
                      ? () {
                          setState(() {
                            _isMeasureMode = !_isMeasureMode;
                            if (!_isMeasureMode) {
                              _measurement = null;
                              _hoveredSnap = null;
                              _touchScreenPos = null;
                              _targetScreenPos = null;
                              _snappedScreenPos = null;
                              _activeMeasureSnap = null;
                              _pointerCustomTitle = null;
                              _pointerCustomSubText = null;
                            } else {
                              _measurement = DxfMeasurement(tool: _currentMeasureTool);
                            }
                          });
                        }
                      : null,
                ),

                // Save Annotated DXF
                if (_annotations.isNotEmpty || _importedDxfFiles.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.save_as_outlined, size: 20, color: Color(0xFF00E5FF)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: _importedDxfFiles.isNotEmpty ? 'Save Merged DXF' : 'Save Annotated DXF',
                    onPressed: _saveAsAnnotatedDxf,
                  ),

                // Theme / Background Popup
                PopupMenuButton<DxfCanvasTheme>(
                  icon: const Icon(Icons.palette_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Canvas Theme',
                  initialValue: _canvasTheme,
                  onSelected: (t) {
                    setState(() {
                      _canvasTheme = t;
                    });
                  },
                  itemBuilder: (context) => DxfCanvasTheme.values.map((t) {
                    return PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: t.bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(t.name),
                          if (t == _canvasTheme) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // More Options
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  onSelected: (value) {
                    switch (value) {
                      case 'save_merged':
                        _saveAsAnnotatedDxf();
                        break;
                      case 'import':
                        _importDxfFile();
                        break;
                      case 'crs':
                        _showCoordinateSettings();
                        break;
                      case 'info':
                        _showInfoSheet();
                        break;
                      case 'grid':
                        setState(() {
                          _showGrid = !_showGrid;
                        });
                        break;
                      case 'share':
                        _shareDxf();
                        break;
                      case 'export_kcad':
                        _exportKcad();
                        break;
                      case 'print':
                        _printDxf();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'export_kcad',
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 20),
                          SizedBox(width: 12),
                          Text('Export as Fast KCAD'),
                        ],
                      ),
                    ),
                    if (_annotations.isNotEmpty || _importedDxfFiles.isNotEmpty)
                      PopupMenuItem(
                        value: 'save_merged',
                        child: Row(
                          children: [
                            const Icon(Icons.save_as_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(_importedDxfFiles.isNotEmpty ? 'Save Merged DXF' : 'Save Annotated DXF'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'crs',
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Coordinate System'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'grid',
                      child: Row(
                        children: [
                          Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                          const SizedBox(width: 12),
                          Text(_showGrid ? 'Hide CAD Grid' : 'Show CAD Grid'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 12),
                          Text('Drawing Properties'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Share File'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Print / Export'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

              if (_isLoading) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading CAD Drawing...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDxfFile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_document == null) {
                return const SizedBox.shrink();
              }

              return Stack(
                children: [
                  // Interactive CAD Canvas with Touch/Mouse Wheel/Middle Pan Listener
                  Listener(
                    onPointerDown: _handleGeneralPointerDown,
                    onPointerMove: _handleGeneralPointerMove,
                    onPointerUp: _handleGeneralPointerUp,
                    onPointerCancel: _handleGeneralPointerCancel,
                    onPointerSignal: _handlePointerSignal,
                    child: MouseRegion(
                      onHover: _handlePointerHover,
                      child: GestureDetector(
                        onTapUp: _isMeasureMode ? null : _handleCanvasTap,
                        onLongPressStart: _isMeasureMode
                            ? null
                            : (details) => _handleCanvasContextTap(details.localPosition),
                        onSecondaryTapUp: _isMeasureMode
                            ? null
                            : (details) => _handleCanvasContextTap(details.localPosition),
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          panEnabled: !_isMeasureMode || _isMultiTouchGesture,
                          scaleEnabled: true,
                          scaleFactor: 350.0,
                          trackpadScrollCausesScale: true,
                          minScale: 0.001,
                          maxScale: 1000.0,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          onInteractionStart: (details) {
                            if (!_isWheelScrolling) {
                              _isGestureActive = true;
                              _transformSettleTimer?.cancel();
                              _wheelSettleTimer?.cancel();
                            }
                          },
                          onInteractionUpdate: (details) {
                            if (!_isWheelScrolling) {
                              _transformSettleTimer?.cancel();
                            }
                          },
                          onInteractionEnd: (details) {
                            _activePointersCount = 0;
                            _isMultiTouchGesture = false;
                            if (!_isWheelScrolling) {
                              _isGestureActive = false;
                              if (_middlePanStart == null) {
                                _transformSettleTimer?.cancel();
                                _transformSettleTimer = Timer(
                                  const Duration(milliseconds: 100),
                                  _syncCanvasAfterTransform,
                                );
                              }
                            }
                          },
                          child: RepaintBoundary(
                            child: CustomPaint(
                              size: _viewportSize,
                              isComplex: true,
                              willChange: false,
                              painter: DxfPainter(
                                document: _document!,
                                theme: _canvasTheme,
                                activeLayout: _activeLayout,
                                currentScale: _renderScale,
                                measurement: null, // Rendered crisply on screen-space overlay above InteractiveViewer
                                annotations: const [], // Rendered crisply on screen-space overlay above InteractiveViewer
                                visibleCadRect: _getVisibleCadRect(),
                                highlightedEntity: _selectedEntity,
                                snapResult: _isMeasureMode && _snapEnabled ? (_hoveredSnap ?? _activeMeasureSnap) : null,
                                showGrid: _showGrid,
                                settings: _displaySettings,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Crisp Screen-Space Measurement & Markup Overlay (Vector-sharp, never blurry, centered)
                  if ((_isMeasureMode && _measurement != null) || _annotations.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _transformController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: DxfMeasurementCanvasPainter(
                                measurement: _isMeasureMode ? _measurement : null,
                                unit: _effectiveUnit,
                                cadToScreen: _cadToScreen,
                                candidateCadPoint: (_snapEnabled && (_hoveredSnap != null || _activeMeasureSnap != null))
                                    ? (_hoveredSnap?.point ?? _activeMeasureSnap?.point)
                                    : (_touchScreenPos != null ? _currentCadCoord : null),
                                annotations: _annotations,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Offset Snapping Pointer Overlay (Sharp tip 56px above finger with magnetism halo)
                  if (_isMeasureMode && _touchScreenPos != null && _targetScreenPos != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: DxfMeasurePointerPainter(
                            touchPos: _touchScreenPos!,
                            targetPos: _targetScreenPos!,
                            snappedPos: _snappedScreenPos,
                            snapType: _activeMeasureSnap?.type,
                            currentCadCoord: _currentCadCoord,
                            p1CadCoord: _measurement?.p1Cad,
                            isSettingSecondPoint: _measurement != null &&
                                _measurement!.tool == DxfMeasureTool.distance &&
                                _measurement!.p1Cad != null &&
                                _measurement!.p2Cad == null,
                            tool: _currentMeasureTool,
                            customTitle: _pointerCustomTitle,
                            customSubText: _pointerCustomSubText,
                            unit: _effectiveUnit,
                          ),
                        ),
                      ),
                    ),

                  // Top Measure Status Bar
                  if (_isMeasureMode)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: DxfMeasurementOverlay(
                          currentTool: _currentMeasureTool,
                          unit: _effectiveUnit,
                          onSelectTool: (tool) {
                            setState(() {
                              _currentMeasureTool = tool;
                              _measurement = DxfMeasurement(tool: tool);
                              _hoveredSnap = null;
                              _touchScreenPos = null;
                              _targetScreenPos = null;
                              _snappedScreenPos = null;
                              _activeMeasureSnap = null;
                              _pointerCustomTitle = null;
                              _pointerCustomSubText = null;
                            });
                          },
                          measurement: _measurement,
                          snapEnabled: _snapEnabled,
                          onToggleSnap: () {
                            setState(() {
                              _snapEnabled = !_snapEnabled;
                              if (!_snapEnabled) {
                                _hoveredSnap = null;
                                _activeMeasureSnap = null;
                                _snappedScreenPos = null;
                              }
                            });
                          },
                          onUndoPoint: _handleUndoAreaPoint,
                          onClosePolygon: _handleCloseAreaPolygon,
                          onClear: () {
                            setState(() {
                              _measurement = DxfMeasurement(tool: _currentMeasureTool);
                              _touchScreenPos = null;
                              _targetScreenPos = null;
                              _snappedScreenPos = null;
                              _activeMeasureSnap = null;
                              _pointerCustomTitle = null;
                              _pointerCustomSubText = null;
                            });
                          },
                          onExit: () {
                            setState(() {
                              _isMeasureMode = false;
                              _measurement = null;
                              _hoveredSnap = null;
                              _touchScreenPos = null;
                              _targetScreenPos = null;
                              _snappedScreenPos = null;
                              _activeMeasureSnap = null;
                              _pointerCustomTitle = null;
                              _pointerCustomSubText = null;
                            });
                          },
                        ),
                      ),
                    ),

                  // Bottom Left Coordinate & Scale HUD
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: ValueListenableBuilder<Offset>(
                      valueListenable: _hudCadCoord,
                      builder: (context, cadCoord, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _hudScale,
                          builder: (context, scale, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xCC1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'X: ${DxfMath.formatCadNumber(cadCoord.dx)}  Y: ${DxfMath.formatCadNumber(cadCoord.dy)}  |  Zoom: ${(scale * 100).toStringAsFixed(0)}%  |  ',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      DxfDisplaySettingsSheet.show(
                                        context: context,
                                        initialSettings: _displaySettings,
                                        onSettingsChanged: (s) {
                                          setState(() {
                                            _displaySettings = s;
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: Text(
                                        _effectiveUnit.symbol.toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 10.5,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '  |  ${activeCrs.name}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Right Floating Navigation Controls
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFloatingButton(
                          icon: Icons.add,
                          tooltip: 'Zoom In',
                          onPressed: _zoomIn,
                        ),
                        const SizedBox(height: 8),
                        _buildFloatingButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom Out',
                          onPressed: _zoomOut,
                        ),
                        const SizedBox(height: 8),
                        _buildFloatingButton(
                          icon: Icons.center_focus_strong,
                          tooltip: 'Fit to Screen',
                          onPressed: _fitToScreen,
                        ),
                      ],
                    ),
                  ),

                  // Presentation Mode Switcher Bar (shown when opened from a project bundle)
                  if (widget.projectBundle != null)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildProjectSwitchBar()),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSwitchBar() {
    return ProjectPresentationBar(
      projectBundle: widget.projectBundle!,
      currentIndex: widget.currentProjectIndex ?? 0,
      onSwitchProjectItem: widget.onSwitchProjectItem,
      onExit: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xEE1E293B),
      shape: const CircleBorder(side: BorderSide(color: Colors.white12)),
      elevation: 6,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
