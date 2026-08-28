import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/coordinate_system_service.dart';
import '../../core/services/dxf_exporter_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/widgets/coordinate_settings_dialog.dart';
import '../home/widgets/share_options_sheet.dart';
import 'models/dxf_display_settings.dart';
import 'models/dxf_models.dart';
import 'parser/dxf_parser.dart';
import 'rendering/dxf_math.dart';
import 'rendering/dxf_painter.dart';
import 'rendering/dxf_snap_helper.dart';
import 'widgets/dxf_annotation_dialog.dart';
import 'widgets/dxf_entity_context_sheet.dart';
import 'widgets/dxf_import_dialog.dart';
import 'widgets/dxf_info_sheet.dart';
import 'widgets/dxf_layer_sheet.dart';
import 'widgets/dxf_measure_pointer_painter.dart';
import 'widgets/dxf_measurement_overlay.dart';

class DxfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const DxfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
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
  bool _showGrid = true;
  double _currentScale = 1.0;
  Offset _currentCadCoord = Offset.zero;
  DxfDisplaySettings _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;

  // Measurement & Snap tool
  bool _isMeasureMode = false;
  bool _snapEnabled = true;
  DxfMeasureTool _currentMeasureTool = DxfMeasureTool.distance;
  DxfMeasurement? _measurement;
  DxfSnapResult? _hoveredSnap;
  String? _pointerCustomTitle;
  String? _pointerCustomSubText;
  List<DxfAnnotation> _annotations = [];
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

  Future<void> _saveAnnotationsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _annotations.map((a) => a.toJson()).toList();
      await prefs.setString('dxf_annotations_${widget.filePath}', jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadSavedAnnotations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dxf_annotations_${widget.filePath}');
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.removeListener(_onTransformChanged);
    DxfDisplaySettingsService.settingsNotifier.removeListener(_onDisplaySettingsChanged);
    _transformController.dispose();
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
    if ((scale - _currentScale).abs() > 0.001) {
      setState(() {
        _currentScale = scale;
      });
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
        setState(() {
          _errorMessage = 'File does not exist: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      _fileSizeBytes = await file.length();
      final doc = await DxfParser.parseFromFile(file);

      setState(() {
        _document = doc;
        _isLoading = false;
      });

      _saveToRecentFiles();

      // Fit to screen after frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToScreen();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open DXF file: $e';
        _isLoading = false;
      });
      try {
        await RecentFilesService.removeRecentFile(widget.filePath);
      } catch (_) {}
    }
  }

  Future<void> _saveToRecentFiles() async {
    try {
      final pdfItem = PdfItem(
        path: widget.filePath,
        name: _fileName,
        sizeInBytes: _fileSizeBytes,
        lastOpened: DateTime.now(),
      );
      await RecentFilesService.addRecentFile(pdfItem);
    } catch (_) {}
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

  Offset _sceneToCad(Offset scenePoint) {
    if (_document == null || _viewportSize.isEmpty) return Offset.zero;

    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);

    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double fitScale = math.min(availW / docW, availH / docH);

    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = _document!.bounds.left;
    final double maxY = _document!.bounds.bottom > _document!.bounds.top
        ? _document!.bounds.bottom
        : _document!.bounds.top;

    final double cadX = minX + (scenePoint.dx - tx) / fitScale;
    final double cadY = maxY - (scenePoint.dy - ty) / fitScale;

    return Offset(cadX, cadY);
  }

  Offset _cadToScene(Offset cadPoint) {
    if (_document == null || _viewportSize.isEmpty) return cadPoint;
    final double fitScale = _getCadFitScale();
    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);
    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;
    final double minX = _document!.bounds.left;
    final double maxY = _document!.bounds.bottom > _document!.bounds.top
        ? _document!.bounds.bottom
        : _document!.bounds.top;

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

      return Rect.fromLTRB(
        left - marginX,
        bottom - marginY,
        right + marginX,
        top + marginY,
      );
    } catch (_) {
      return null;
    }
  }

  double _getCadFitScale() {
    if (_document == null || _viewportSize.isEmpty) return 1.0;
    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);
    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);
    return math.min(availW / docW, availH / docH);
  }

  void _handleMeasurePointerDown(PointerDownEvent event) {
    if (!_isMeasureMode || _document == null) return;
    _activePointersCount++;
    if (_activePointersCount > 1) {
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
        basePoint = (_measurement != null && _measurement!.tool == DxfMeasureTool.distance && _measurement!.p2Cad == null)
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
    String? title;
    String? subText;

    switch (_currentMeasureTool) {
      case DxfMeasureTool.distance:
        title = (_measurement != null && _measurement!.tool == DxfMeasureTool.distance && _measurement!.p2Cad == null)
            ? '2nd Point'
            : '1st Point';
        break;

      case DxfMeasureTool.area:
        final count = (_measurement?.tool == DxfMeasureTool.area) ? (_measurement?.areaPoints.length ?? 0) : 0;
        title = 'Vertex ${count + 1}';
        if (count > 0 && _measurement!.areaPoints.isNotEmpty) {
          final lastPt = _measurement!.areaPoints.last;
          final segDist = (effectiveCad - lastPt).distance;
          subText = 'Segment: ${DxfMath.formatDistance(segDist)} m';
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
            subText = 'R = ${DxfMath.formatDistance(circleArc.radius)} • Ø = ${DxfMath.formatDistance(circleArc.radius * 2.0)}';
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
          subText = 'Leader: ${DxfMath.formatDistance(dist)} m';
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
      final originalFile = File(widget.filePath);
      final dir = originalFile.parent;
      final originalName = originalFile.uri.pathSegments.last;
      final baseName = originalName.replaceAll(RegExp(r'\.dxf$', caseSensitive: false), '');
      final outputFileName = '${baseName}_annotated.dxf';
      final outputFile = File('${dir.path}/$outputFileName');

      await DxfExporterService.saveDxfWithAnnotations(
        originalFile: originalFile,
        annotations: _annotations,
        outputFile: outputFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved DXF: $outputFileName'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save DXF: $e'),
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
      final delta = event.scrollDelta.dy;
      if (delta < 0) {
        _zoomBy(1.20, focalPoint: event.localPosition);
      } else if (delta > 0) {
        _zoomBy(1 / 1.20, focalPoint: event.localPosition);
      }
    }
  }

  void _handleGeneralPointerDown(PointerDownEvent event) {
    if ((event.buttons & kTertiaryButton) != 0) {
      _middlePanStart = event.position;
      _middlePanMatrix = _transformController.value.clone();
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

    setState(() {
      _currentCadCoord = snap != null ? snap.point : cadPoint;
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
      final file = File(filePath);

      if (!filePath.toLowerCase().endsWith('.dxf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a valid .dxf file to import.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parsing DXF for import...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final importedDoc = await DxfParser.parseFromFile(file);
      final activeCrs = CoordinateSystemService.activeSystemNotifier.value;

      if (!mounted) return;

      final action = await DxfImportDialog.show(
        context: context,
        file: file,
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
        mergedBlocks[entry.key] = entry.value;
      }

      final mergedEntities = List<DxfEntity>.from(_document!.entities)..addAll(importedDoc.entities);
      final mergedBounds = _document!.bounds.expandToInclude(importedDoc.bounds);

      final mergedStats = Map<String, int>.from(_document!.entityStats);
      for (final entry in importedDoc.entityStats.entries) {
        mergedStats[entry.key] = (mergedStats[entry.key] ?? 0) + entry.value;
      }

      setState(() {
        _document = DxfDocument(
          layers: mergedLayers,
          blocks: mergedBlocks,
          entities: mergedEntities,
          headerVars: _document!.headerVars,
          bounds: mergedBounds,
          entityStats: mergedStats,
        );
      });

      final importedName = filePath.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${importedDoc.totalEntities} entities from $importedName'),
          action: SnackBarAction(
            label: 'Fit Screen',
            onPressed: _fitToScreen,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing DXF: $e')),
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

  void _shareDxf() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareOptionsSheet(filePath: widget.filePath),
    );
  }

  Future<void> _printDxf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print preview unavailable: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  tooltip: 'Import DXF',
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
                if (_annotations.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.save_as_outlined, size: 20, color: Color(0xFF00E5FF)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Save Annotated DXF',
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
                      case 'print':
                        _printDxf();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
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
                    onPointerSignal: _handlePointerSignal,
                    onPointerDown: _handleGeneralPointerDown,
                    onPointerMove: _handleGeneralPointerMove,
                    onPointerUp: _handleGeneralPointerUp,
                    onPointerCancel: _handleGeneralPointerCancel,
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
                          minScale: 0.001,
                          maxScale: 1000.0,
                          boundaryMargin: const EdgeInsets.all(1000.0),
                          child: CustomPaint(
                            size: _viewportSize,
                            painter: DxfPainter(
                              document: _document!,
                              theme: _canvasTheme,
                              currentScale: _currentScale,
                              measurement: _measurement,
                              annotations: _annotations,
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
                                _measurement!.p2Cad == null,
                            tool: _currentMeasureTool,
                            customTitle: _pointerCustomTitle,
                            customSubText: _pointerCustomSubText,
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'X: ${DxfMath.formatDistance(_currentCadCoord.dx)}  Y: ${DxfMath.formatDistance(_currentCadCoord.dy)}  |  Zoom: ${(_currentScale * 100).toStringAsFixed(0)}%  |  ${activeCrs.name}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                ],
              );
            },
          ),
        ),
      ),
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