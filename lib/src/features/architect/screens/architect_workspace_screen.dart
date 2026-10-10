import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';

import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../models/architect_door.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_3d_builder.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_zone_snap.dart';
import '../services/architect_zone_tool.dart';
import '../widgets/architect_new_project_dialog.dart';
import '../widgets/architect_storey_bar.dart';
import '../widgets/architect_tool_palette.dart';
import '../widgets/architect_zone_drafting_bar.dart';
import '../widgets/architect_zone_properties_card.dart';

/// The primary unified workspace for architectural concept drafting in 2D and 3D.
class ArchitectWorkspaceScreen extends StatefulWidget {
  final ArchitectProject? initialProject;

  const ArchitectWorkspaceScreen({super.key, this.initialProject});

  @override
  State<ArchitectWorkspaceScreen> createState() =>
      _ArchitectWorkspaceScreenState();
}

class _ArchitectWorkspaceScreenState extends State<ArchitectWorkspaceScreen> {
  late ArchitectProject _project;
  ArchitectTool _activeTool = ArchitectTool.zone;
  bool _is3DView = false;

  // Zone Drafting & Dynamic Slab-style Editing State
  ArchitectZoneCategory _activeZoneCategory = ArchitectZoneCategory.living;
  String? _selectedZoneId;
  int? _draggingVertexIndex;
  Offset? _draggingVertexPoint;
  int? _mergeCandidateIndex;
  Offset? _zoneMoveStartPoint;
  List<Offset>? _zoneMoveOriginalPolygon;
  List<(Offset, Offset)> _activeMagneticGuides = [];

  // Unified tool controller for zone drafting, edge extrusion, and geometry
  late final ArchitectZoneTool _zoneTool;

  // Wall Drafting State
  double _wallThickness = 0.25; // 25 cm default
  WallDraftingMode _wallMode = WallDraftingMode.singleLine;
  Offset? _draftStart;
  Offset? _draftEnd;
  String? _activeSnapLabel;

  // Door State (from element_vrata.dxf)
  double _doorWidth = 0.90;
  double _doorHeight = 2.00;
  double _doorSill = 0.0;
  bool _isHingeLeft = true;
  int _doorSpecCounter = 1;

  // Selection & Zoom
  String? _selectedElementId;
  final TransformationController _transformController =
      TransformationController();
  late Cad3DCamera _camera3D;

  ArchitectZone? get _selectedZone {
    if (_selectedZoneId == null) return null;
    final zones = _project.activeStorey.zones;
    for (final z in zones) {
      if (z.id == _selectedZoneId) return z;
    }
    return null;
  }

  bool get _isInteractingWithElement =>
      _zoneTool.isInteracting ||
      _draftStart != null ||
      _draggingVertexIndex != null ||
      _zoneMoveStartPoint != null;

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject ??
        ArchitectProject.starter(
          name: 'Архитектурен проект 1',
          storeyCount: 2,
        );

    _zoneTool = ArchitectZoneTool()
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _camera3D = Cad3DCamera(
      yaw: math.pi / 4,
      pitch: 0.6,
      zoom: 1.0,
      mode: Cad3DInteractionMode.orbit,
    );

    // Initial camera scale for 2D canvas: 1 meter = 40 logical pixels
    _initTransform();
  }

  void _initTransform() {
    final matrix = Matrix4.identity()
      ..translateByDouble(200.0, 300.0, 0.0, 1.0)
      ..scaleByDouble(40.0, 40.0, 1.0, 1.0);
    _transformController.value = matrix;
  }

  @override
  void dispose() {
    _zoneTool.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // COORDINATE TRANSFORMS (SCREEN <-> MODEL METERS)
  // ===========================================================================

  Offset _screenToModel(Offset screenPos) {
    return _transformController.toScene(screenPos);
  }


  double get _currentScale =>
      _transformController.value.getMaxScaleOnAxis().clamp(0.01, 10000.0);

  // ===========================================================================
  // 2D POINTER & TOUCH HANDLING
  // ===========================================================================

  int? _hitTestZoneVertex(Offset modelPt, ArchitectZone zone) {
    final tolerance = 14.0 / _currentScale;
    for (int i = 0; i < zone.polygon.length; i++) {
      if ((modelPt - zone.polygon[i]).distance <= tolerance) {
        return i;
      }
    }
    return null;
  }

  int? _hitTestZoneMidpoint(Offset modelPt, ArchitectZone zone) {
    final tolerance = 12.0 / _currentScale;
    for (int i = 0; i < zone.polygon.length; i++) {
      final p1 = zone.polygon[i];
      final p2 = zone.polygon[(i + 1) % zone.polygon.length];
      final mid = (p1 + p2) / 2.0;
      if ((modelPt - mid).distance <= tolerance) {
        return i;
      }
    }
    return null;
  }

  ArchitectZone? _findZoneAt(Offset modelPt) {
    final zones = _project.activeStorey.zones;
    for (int i = zones.length - 1; i >= 0; i--) {
      if (zones[i].containsPoint(modelPt)) {
        return zones[i];
      }
    }
    return null;
  }

  void _commitDraftedZone() {
    final l10n = context.l10n;
    final newZone = _zoneTool.commitDrafting(
      category: _activeZoneCategory,
      defaultName: _activeZoneCategory.defaultBgName,
    );

    if (newZone != null) {
      final activeStorey = _project.activeStorey;
      final updatedStorey = activeStorey.copyWith(
        zones: [...activeStorey.zones, newZone],
      );

      setState(() {
        _project = _project.updateActiveStorey(updatedStorey);
        _selectedZoneId = newZone.id;
        _activeMagneticGuides = [];
        _activeSnapLabel = null;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.architectZoneCreated(newZone.name, newZone.area.toStringAsFixed(1)),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      if (_zoneTool.pointStatus == ZoneDraftingPointStatus.selfIntersects) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneSelfIntersectError),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneMinPointsError),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _onPointerDown(Offset screenPos) {
    final rawModel = _screenToModel(screenPos);

    if (_activeTool == ArchitectTool.zone) {
      // 1. If currently in point-by-point drafting mode:
      if (_zoneTool.isDrafting) {
        if (_zoneTool.isClosingSnap) {
          _commitDraftedZone();
          return;
        }

        final candidate = _zoneTool.candidatePoint ?? rawModel;
        final added = _zoneTool.addDraftingPoint(candidate);
        if (_zoneTool.pointStatus == ZoneDraftingPointStatus.closeTarget) {
          _commitDraftedZone();
        } else if (added) {
          HapticFeedback.lightImpact();
        } else if (_zoneTool.pointStatus == ZoneDraftingPointStatus.selfIntersects) {
          HapticFeedback.heavyImpact();
        }
        return;
      }

      // 2. Check if a zone handle is hit on the selected zone
      final currentSelected = _selectedZone;
      if (currentSelected != null) {
        // Vertex handle check (drag existing vertex)
        final vIdx = _hitTestZoneVertex(rawModel, currentSelected);
        if (vIdx != null) {
          setState(() {
            _draggingVertexIndex = vIdx;
            _draggingVertexPoint = currentSelected.polygon[vIdx];
            _mergeCandidateIndex = null;
            _activeMagneticGuides = [];
          });
          HapticFeedback.selectionClick();
          return;
        }

        // Midpoint handle check (extrude/pull edge preserving endpoints and creating new vertices)
        final midIdx = _hitTestZoneMidpoint(rawModel, currentSelected);
        if (midIdx != null) {
          _zoneTool.startExtrude(
            zone: currentSelected,
            edgeIndex: midIdx,
            pointerModel: rawModel,
          );
          HapticFeedback.mediumImpact();
          return;
        }

        // Tap inside currently selected zone -> initiate whole zone move
        if (currentSelected.containsPoint(rawModel)) {
          setState(() {
            _zoneMoveStartPoint = rawModel;
            _zoneMoveOriginalPolygon = List<Offset>.from(currentSelected.polygon);
          });
          return;
        }
      }

      // 3. Check if tapped inside another zone to select it
      final hitZone = _findZoneAt(rawModel);
      if (hitZone != null) {
        setState(() {
          _selectedZoneId = hitZone.id;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        return;
      }

      // 4. In Zone tool, tapping empty space starts point-by-point drafting
      final snap = ArchitectZoneSnap.snap(
        raw: rawModel,
        project: _project,
        tolerance: 14.0 / _currentScale,
      );
      _zoneTool.startDrafting(snap.isSnapped ? snap.point : rawModel);
      setState(() {
        _selectedZoneId = null;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    if (_activeTool == ArchitectTool.select) {
      final currentSelected = _selectedZone;
      if (currentSelected != null) {
        final vIdx = _hitTestZoneVertex(rawModel, currentSelected);
        if (vIdx != null) {
          setState(() {
            _draggingVertexIndex = vIdx;
            _draggingVertexPoint = currentSelected.polygon[vIdx];
            _mergeCandidateIndex = null;
            _activeMagneticGuides = [];
          });
          HapticFeedback.selectionClick();
          return;
        }

        final midIdx = _hitTestZoneMidpoint(rawModel, currentSelected);
        if (midIdx != null) {
          _zoneTool.startExtrude(
            zone: currentSelected,
            edgeIndex: midIdx,
            pointerModel: rawModel,
          );
          HapticFeedback.mediumImpact();
          return;
        }

        if (currentSelected.containsPoint(rawModel)) {
          setState(() {
            _zoneMoveStartPoint = rawModel;
            _zoneMoveOriginalPolygon = List<Offset>.from(currentSelected.polygon);
          });
          return;
        }
      }

      final hitZone = _findZoneAt(rawModel);
      if (hitZone != null) {
        setState(() {
          _selectedZoneId = hitZone.id;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        return;
      }

      _trySelectElementAt(rawModel);
      return;
    }

    if (_activeTool == ArchitectTool.wall) {
      if (_draftStart == null) {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: rawModel,
          project: _project,
          tolerance: 10.0 / _currentScale,
        );
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
          _activeSnapLabel = snap.snapLabel;
        });
      } else {
        _commitCurrentWallSegment(rawModel);
      }
    } else if (_activeTool == ArchitectTool.door) {
      _tryPlaceDoorAt(rawModel);
    }
  }

  void _onPointerMove(Offset screenPos) {
    final rawModel = _screenToModel(screenPos);

    // 1. Point-by-point zone drafting preview
    if (_activeTool == ArchitectTool.zone && _zoneTool.isDrafting) {
      _zoneTool.updateDraftingPointer(
        rawModelPoint: rawModel,
        project: _project,
        currentScale: _currentScale,
      );
      return;
    }

    // 2. Dragging edge midpoint (extruding segment)
    if (_zoneTool.isExtruding) {
      _zoneTool.updateExtrudePointer(rawModel);
      return;
    }

    // 3. Dragging a zone vertex (dynamic slab editing)
    if (_draggingVertexIndex != null && _selectedZone != null) {
      final snap = ArchitectZoneSnap.snap(
        raw: rawModel,
        project: _project,
        excludedZoneId: _selectedZoneId,
        movingVertexIndex: _draggingVertexIndex,
        tolerance: 14.0 / _currentScale,
      );
      setState(() {
        _draggingVertexPoint = snap.point;
        _mergeCandidateIndex = snap.mergeCandidateIndex;
        _activeMagneticGuides = snap.magneticGuides;
        _activeSnapLabel = snap.snapLabel;
      });
      return;
    }

    // 4. Moving whole zone
    if (_zoneMoveStartPoint != null && _zoneMoveOriginalPolygon != null && _selectedZone != null) {
      final delta = rawModel - _zoneMoveStartPoint!;
      final translated = _zoneMoveOriginalPolygon!.map((p) => p + delta).toList();
      _updateZone(_selectedZone!.copyWith(polygon: translated));
      return;
    }

    // 5. Wall drafting
    if (_activeTool == ArchitectTool.wall && _draftStart != null) {
      final snap = ArchitectSnapHelper.snapWithAnchor(
        anchor: _draftStart!,
        rawPoint: rawModel,
        project: _project,
        tolerance: 12.0 / _currentScale,
      );
      setState(() {
        _draftEnd = snap.point;
        _activeSnapLabel = snap.snapLabel;
      });
    }
  }

  void _onPointerUp(Offset screenPos) {
    final l10n = context.l10n;

    // 1. Edge extrusion commit
    if (_zoneTool.isExtruding) {
      final isSelfIntersecting = _zoneTool.isExtrudeSelfIntersecting;
      final result = _zoneTool.commitExtrude();
      if (result != null) {
        final (updatedZone, cleanedCount) = result;
        _updateZone(updatedZone);
        HapticFeedback.mediumImpact();
        if (cleanedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneCleaned(cleanedCount)),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (isSelfIntersecting) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneSelfIntersectError),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 2. Commit vertex drag with orphan cleaning & self-intersection protection
    if (_draggingVertexIndex != null && _selectedZone != null) {
      final zone = _selectedZone!;
      final idx = _draggingVertexIndex!;
      final mergeCandidate = _mergeCandidateIndex;

      if (mergeCandidate != null && zone.polygon.length > 3) {
        final updated = zone.removeVertex(idx);
        if (updated != null) {
          final cleaned = ArchitectZoneGeometry.cleanPolygon(updated.polygon);
          _updateZone(updated.copyWith(polygon: cleaned));
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneMerged),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (_draggingVertexPoint != null) {
        final candidatePoly = List<Offset>.from(zone.polygon)..[idx] = _draggingVertexPoint!;
        if (ArchitectZoneGeometry.hasSelfIntersections(candidatePoly)) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneSelfIntersectError),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final cleaned = ArchitectZoneGeometry.cleanPolygon(candidatePoly);
          final updated = zone.copyWith(polygon: cleaned);
          _updateZone(updated);
          HapticFeedback.lightImpact();
        }
      }

      setState(() {
        _draggingVertexIndex = null;
        _draggingVertexPoint = null;
        _mergeCandidateIndex = null;
        _activeMagneticGuides = [];
        _activeSnapLabel = null;
      });
      return;
    }

    // 3. Commit whole zone move
    if (_zoneMoveStartPoint != null) {
      setState(() {
        _zoneMoveStartPoint = null;
        _zoneMoveOriginalPolygon = null;
        _activeMagneticGuides = [];
      });
      return;
    }

    // 4. Wall drafting commit
    if (_activeTool == ArchitectTool.wall &&
        _wallMode == WallDraftingMode.singleLine &&
        _draftStart != null &&
        _draftEnd != null) {
      _commitCurrentWallSegment(_draftEnd!);
      setState(() {
        _draftStart = null;
        _draftEnd = null;
        _activeSnapLabel = null;
      });
    }
  }

  void _updateZone(ArchitectZone updated) {
    final activeStorey = _project.activeStorey;
    final updatedZones = activeStorey.zones
        .map((z) => z.id == updated.id ? updated : z)
        .toList();
    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(zones: updatedZones),
      );
    });
  }

  void _deleteSelectedZone() {
    if (_selectedZoneId == null) return;
    final activeStorey = _project.activeStorey;
    final updatedZones = activeStorey.zones
        .where((z) => z.id != _selectedZoneId)
        .toList();
    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(zones: updatedZones),
      );
      _selectedZoneId = null;
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectZoneDeleted),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _commitCurrentWallSegment(Offset targetPoint) {
    if (_draftStart == null) return;
    final p1 = _draftStart!;
    final p2 = targetPoint;
    final len = (p2 - p1).distance;
    if (len < 0.20) return; // Ignore micro taps < 20 cm

    final now = DateTime.now().millisecondsSinceEpoch;
    final newWall = ArchitectWall(
      id: 'wall_$now',
      startPoint: p1,
      endPoint: p2,
      thickness: _wallThickness,
      height: _project.activeStorey.height,
    );

    final updatedStorey = _project.activeStorey.copyWith(
      walls: [..._project.activeStorey.walls, newWall],
    );

    setState(() {
      _project = _project.updateActiveStorey(updatedStorey);
      if (_wallMode == WallDraftingMode.chained) {
        _draftStart = p2;
        _draftEnd = p2;
      }
    });

    HapticFeedback.lightImpact();
  }

  void _finishChainedWall() {
    setState(() {
      _draftStart = null;
      _draftEnd = null;
      _activeSnapLabel = null;
    });
  }

  void _tryPlaceDoorAt(Offset point) {
    final activeStorey = _project.activeStorey;
    ArchitectWall? targetWall;
    double bestDist = double.infinity;

    for (final wall in activeStorey.walls) {
      final (_, dist) = wall.projectPoint(point);
      if (dist <= wall.thickness / 2.0 + 0.30 && dist < bestDist) {
        bestDist = dist;
        targetWall = wall;
      }
    }

    if (targetWall == null) return;

    final (ratio, _) = targetWall.projectPoint(point);
    final now = DateTime.now().millisecondsSinceEpoch;

    final newDoor = ArchitectDoor(
      id: 'door_$now',
      wallId: targetWall.id,
      offsetRatio: ratio,
      width: _doorWidth,
      height: _doorHeight,
      sillHeight: _doorSill,
      isHingeLeft: _isHingeLeft,
      specId: '$_doorSpecCounter',
      uuid: 'UUID_$now',
    );

    _doorSpecCounter++;
    final updatedWall = targetWall.addDoor(newDoor);
    final updatedWalls = activeStorey.walls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();

    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(walls: updatedWalls),
      );
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Врата ${newDoor.specId} (${(newDoor.width * 100).round()}/${(newDoor.height * 100).round()}) поставена',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _trySelectElementAt(Offset point) {
    final activeStorey = _project.activeStorey;
    for (final wall in activeStorey.walls) {
      if (wall.containsPoint(point)) {
        setState(() {
          _selectedElementId = wall.id;
          _selectedZoneId = null;
        });
        return;
      }
    }
    setState(() {
      _selectedElementId = null;
      _selectedZoneId = null;
    });
  }

  // ===========================================================================
  // WIZARD & ACTIONS
  // ===========================================================================

  Future<void> _openNewProjectWizard() async {
    final newProj = await showDialog<ArchitectProject>(
      context: context,
      builder: (_) => const ArchitectNewProjectDialog(),
    );
    if (newProj != null && mounted) {
      setState(() {
        _project = newProj;
        _draftStart = null;
        _draftEnd = null;
      });
      _initTransform();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _project.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              l10n.architectStudioSubtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          // 2D / 3D Toggle Button
          IconButton(
            tooltip: _is3DView ? l10n.architectView2D : l10n.architectView3D,
            icon: Icon(
              _is3DView ? Icons.crop_square_rounded : Icons.view_in_ar_rounded,
              color: const Color(0xFF00E5FF),
            ),
            onPressed: () => setState(() => _is3DView = !_is3DView),
          ),
          // Reset View Button
          IconButton(
            tooltip: l10n.architectResetView,
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: () {
              if (_is3DView) {
                setState(() {
                  _camera3D.yaw = math.pi / 4;
                  _camera3D.pitch = 0.6;
                  _camera3D.zoom = 1.0;
                });
              } else {
                _initTransform();
              }
            },
          ),
          // New Project Wizard Button
          IconButton(
            tooltip: l10n.architectNewProject,
            icon: const Icon(Icons.add_business_rounded),
            onPressed: _openNewProjectWizard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Storey Level Bar
          ArchitectStoreyBar(
            project: _project,
            onStoreySelected: (sId) =>
                setState(() => _project = _project.copyWith(activeStoreyId: sId)),
          ),

          // Main Viewport (2D Canvas or 3D Solid Model)
          Expanded(
            child: Stack(
              children: [
                _is3DView ? _build3DViewport() : _build2DCanvas(),
                if (_zoneTool.isDrafting && !_is3DView)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: ArchitectZoneDraftingBar(
                      tool: _zoneTool,
                      category: _activeZoneCategory,
                      onClose: _commitDraftedZone,
                      onUndo: () => setState(
                          () => _zoneTool.undoDraftingPoint()),
                      onCancel: () =>
                          setState(() => _zoneTool.cancelDrafting()),
                    ),
                  ),
              ],
            ),
          ),

          // Floating Zone Property Inspector Card if a zone is selected
          if (_selectedZone != null && !_is3DView)
            ArchitectZonePropertiesCard(
              zone: _selectedZone!,
              onZoneUpdated: _updateZone,
              onDeleteZone: _deleteSelectedZone,
              onClose: () => setState(() => _selectedZoneId = null),
            ),

          // Bottom Responsive Tool Palette
          if (!_is3DView)
            ArchitectToolPalette(
              activeTool: _activeTool,
              onToolChanged: (tool) => setState(() {
                _zoneTool.cancelAll();
                _activeTool = tool;
                _draftStart = null;
                _draftEnd = null;
                _activeMagneticGuides = [];
                _activeSnapLabel = null;
              }),
              activeZoneCategory: _activeZoneCategory,
              onZoneCategoryChanged: (cat) =>
                  setState(() => _activeZoneCategory = cat),
              wallThickness: _wallThickness,
              onWallThicknessChanged: (t) =>
                  setState(() => _wallThickness = t),
              wallMode: _wallMode,
              onWallModeChanged: (m) => setState(() => _wallMode = m),
              isChainingWall: _draftStart != null &&
                  _wallMode == WallDraftingMode.chained,
              onFinishChainedWall: _finishChainedWall,
              doorWidth: _doorWidth,
              onDoorWidthChanged: (w) => setState(() => _doorWidth = w),
              doorHeight: _doorHeight,
              onDoorHeightChanged: (h) => setState(() => _doorHeight = h),
              doorSill: _doorSill,
              onDoorSillChanged: (s) => setState(() => _doorSill = s),
              isHingeLeft: _isHingeLeft,
              onHingeSideChanged: (left) =>
                  setState(() => _isHingeLeft = left),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2D CANVAS VIEWPORT
  // ===========================================================================

  Widget _build2DCanvas() {
    return MouseRegion(
      onHover: (event) {
        if (_zoneTool.isDrafting) {
          _onPointerMove(event.localPosition);
        }
      },
      child: GestureDetector(
        onTapDown: (details) => _onPointerDown(details.localPosition),
        onPanStart: (details) {
          if (!_zoneTool.isDrafting) {
            _onPointerDown(details.localPosition);
          }
        },
        onPanUpdate: (details) => _onPointerMove(details.localPosition),
        onPanEnd: (details) => _onPointerUp(details.localPosition),
        child: InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(5000),
          minScale: 0.05,
          maxScale: 50.0,
          panEnabled: !_isInteractingWithElement,
          child: SizedBox.expand(
            child: CustomPaint(
              painter: Architect2dPainter(
                project: _project,
                activeTool: _activeTool,
                activeDraftStart: _draftStart,
                activeDraftEnd: _draftEnd,
                activeWallThickness: _wallThickness,
                activeSnapLabel: _activeSnapLabel,
                selectedElementId: _selectedElementId,
                selectedZoneId: _selectedZoneId,
                activeZoneCategory: _activeZoneCategory,
                draggingVertexIndex: _draggingVertexIndex,
                draggingVertexPoint: _draggingVertexPoint,
                mergeCandidateIndex: _mergeCandidateIndex,
                magneticGuides: _zoneTool.isDrafting
                    ? _zoneTool.magneticGuides
                    : _activeMagneticGuides,
                zoomScale: _currentScale,
                zoneDraftingPoints: _zoneTool.draftPoints,
                zoneDraftingCandidate: _zoneTool.candidatePoint,
                zoneOrthoGuide: _zoneTool.orthoGuide,
                zoneOrthoLabel: _zoneTool.orthoLabel,
                isZoneClosingSnap: _zoneTool.isClosingSnap,
                isZoneDraftingSelfIntersecting:
                    _zoneTool.pointStatus ==
                        ZoneDraftingPointStatus.selfIntersects,
                zoneCloseLabel: context.l10n.architectZonePointSnapStart,
                zoneExtrudePreviewPolygon:
                    _zoneTool.extrudePreviewPolygon,
                zoneExtrudeV1: _zoneTool.extrudeV1,
                zoneExtrudeV2: _zoneTool.extrudeV2,
                zoneExtrudeNormal: _zoneTool.extrudeNormal,
                zoneExtrudeDistance: _zoneTool.extrudeDistance,
                isZoneExtrudeSelfIntersecting:
                    _zoneTool.isExtrudeSelfIntersecting,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3D SOLID VIEWPORT
  // ===========================================================================

  Widget _build3DViewport() {
    final mesh = Architect3dBuilder.buildProjectMesh(_project);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _camera3D.yaw += details.delta.dx * 0.01;
          _camera3D.pitch =
              (_camera3D.pitch + details.delta.dy * 0.01).clamp(0.05, math.pi / 2 - 0.05);
        });
      },
      child: Container(
        color: const Color(0xFF181A20),
        child: CustomPaint(
          size: Size.infinite,
          painter: Cad3DMeshPainter(
            mesh: mesh,
            camera: _camera3D,
            shadingMode: Cad3DShadingMode.smoothShaded,
            theme: Cad3DTheme.darkCad,
            showGrid: true,
            isInteracting: false,
          ),
        ),
      ),
    );
  }
}
