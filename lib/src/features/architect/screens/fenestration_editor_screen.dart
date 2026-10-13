// === SECTION: ARCHITECTURAL FENESTRATION EDITOR SCREEN ===
// Table of Contents:
// 1. STATE & CONTROLLER INITIALIZATION
// 2. 2D/3D VIEWPORT RENDERING (Elevation, Plan, 3D Orbit View)
// 3. MOCK WALL & 3D MESH GENERATION (Casing over insulation demo)
// 4. EDITOR HUD & BOTTOM CONTROLS (Responsive Tabs)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../models/architect_fenestration_style.dart';
import '../rendering/fenestration_3d_builder.dart';
import '../rendering/fenestration_elevation_painter.dart';
import '../services/fenestration_library_service.dart';
import '../widgets/architect_wall_drafting_panel.dart';
import '../widgets/fenestration_editor_tabs.dart';

enum FenestrationViewMode {
  elevation2D,
  plan2D,
  orbit3D,
}

class FenestrationEditorScreen extends StatefulWidget {
  final ArchitectFenestrationStyle? initialStyle;
  final FenestrationKind initialKind;

  const FenestrationEditorScreen({
    super.key,
    this.initialStyle,
    this.initialKind = FenestrationKind.window,
  });

  @override
  State<FenestrationEditorScreen> createState() =>
      _FenestrationEditorScreenState();
}

class _FenestrationEditorScreenState extends State<FenestrationEditorScreen>
    with SingleTickerProviderStateMixin {
  late ArchitectFenestrationStyle _style;
  FenestrationViewMode _viewMode = FenestrationViewMode.elevation2D;
  String? _selectedPaneId;
  bool? _keypadDimensionIsWidth;

  late final TabController _tabController;
  final Cad3DCamera _camera3D = Cad3DCamera(
    yaw: math.pi / 4,
    pitch: 0.45,
    zoom: 1.2,
    mode: Cad3DInteractionMode.orbit,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    if (widget.initialStyle != null) {
      _style = widget.initialStyle!;
    } else {
      final catalog = ArchitectFenestrationStyle.standardCatalog();
      _style = catalog.firstWhere(
        (s) => s.kind == widget.initialKind,
        orElse: () => catalog.first,
      );
    }

    final panes = _style.rootSubdivision.collectPanes();
    if (panes.isNotEmpty) {
      _selectedPaneId = panes.first.id;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSaveToLibrary() async {
    await FenestrationLibraryService.instance.saveStyle(_style);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectFenestrationSaveSuccess),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, _style);
    }
  }

  void _onEditName() {
    final textController = TextEditingController(text: _style.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.architectFenestrationStyle),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                setState(() {
                  _style = _style.copyWith(name: textController.text.trim());
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF14171E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        title: InkWell(
          onTap: _onEditName,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _style.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
        actions: [
          // View Mode Selector
          SegmentedButton<FenestrationViewMode>(
            segments: [
              ButtonSegment(
                value: FenestrationViewMode.elevation2D,
                icon: const Icon(Icons.crop_square_rounded, size: 16),
                tooltip: l10n.architectFenestrationViewElevation,
              ),
              ButtonSegment(
                value: FenestrationViewMode.plan2D,
                icon: const Icon(Icons.horizontal_rule_rounded, size: 16),
                tooltip: l10n.architectFenestrationViewPlan,
              ),
              ButtonSegment(
                value: FenestrationViewMode.orbit3D,
                icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                tooltip: l10n.architectFenestrationView3D,
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) {
              setState(() => _viewMode = set.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),

          // Save to Library
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded, size: 16),
            label: Text(l10n.architectFenestrationSave),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _onSaveToLibrary,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Central Viewport (2D Elevation, 2D Plan, or 3D Solid)
            Expanded(
              flex: 5,
              child: ClipRect(
                child: _buildCentralViewport(),
              ),
            ),

            // Bottom Configuration Panel with Tabs & Step Navigation
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E222B),
                border: Border(
                  top: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: const Color(0xFF00E5FF),
                      labelColor: const Color(0xFF00E5FF),
                      unselectedLabelColor: Colors.white60,
                      tabs: [
                        Tab(text: l10n.architectFenestrationStep1),
                        Tab(text: l10n.architectFenestrationStep2),
                        Tab(text: l10n.architectFenestrationStep3),
                        Tab(text: l10n.architectFenestrationCasing),
                        Tab(text: l10n.architectFenestrationProfile),
                        Tab(text: l10n.architectFenestrationPresets),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_tabController.index > 0 && _tabController.index < 3)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                              tooltip: l10n.architectFenestrationPrevStep,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _tabController.animateTo(
                                _tabController.index - 1,
                              ),
                            ),
                          if (_tabController.index < 2)
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              tooltip: l10n.architectFenestrationNextStep,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _tabController.animateTo(
                                _tabController.index + 1,
                              ),
                            ),
                          const SizedBox(width: 4),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF191C23),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    FenestrationStep1FrameGridTab(
                      style: _style,
                      selectedPaneId: _selectedPaneId,
                      onSelectPane: (id) => setState(() => _selectedPaneId = id),
                      onChanged: _updateStyle,
                      onOpenKeypad: _openKeypad,
                    ),
                    FenestrationStep2OperabilityTab(
                      style: _style,
                      selectedPaneId: _selectedPaneId,
                      onSelectPane: (id) => setState(() => _selectedPaneId = id),
                      onChanged: _updateStyle,
                    ),
                    FenestrationStep3InfillMuntinsTab(
                      style: _style,
                      selectedPaneId: _selectedPaneId,
                      onSelectPane: (id) => setState(() => _selectedPaneId = id),
                      onChanged: _updateStyle,
                    ),
                    FenestrationCasingTab(
                      style: _style,
                      onChanged: _updateStyle,
                    ),
                    FenestrationProfileTab(
                      style: _style,
                      onChanged: _updateStyle,
                    ),
                    FenestrationPresetsTab(
                      onSelectPreset: (preset) {
                        setState(() {
                          _style = preset.copyWith(name: _style.name);
                          final panes = _style.rootSubdivision.collectPanes();
                          if (panes.isNotEmpty) _selectedPaneId = panes.first.id;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStyle(ArchitectFenestrationStyle newStyle) {
    setState(() {
      _style = newStyle;
      final panes = _style.rootSubdivision.collectPanes();
      if (!panes.any((p) => p.id == _selectedPaneId)) {
        _selectedPaneId = panes.firstOrNull?.id;
      }
    });
  }

  void _openKeypad(bool isWidth) {
    setState(() {
      _keypadDimensionIsWidth = isWidth;
    });
  }

  Widget _buildCanvasQuickHud() {
    final l10n = context.l10n;
    final rect = _style.getPaneRect(_selectedPaneId!);
    final wCm = ((rect?.width ?? _style.defaultWidth) * 100).round();
    final hCm = ((rect?.height ?? _style.defaultHeight) * 100).round();

    return Material(
      color: const Color(0xE61E242C),
      borderRadius: BorderRadius.circular(8),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.crop_square_rounded, size: 16, color: Color(0xFF00E5FF)),
            const SizedBox(width: 6),
            Text(
              '$wCm × $hCm cm',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _openKeypad(true),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dialpad_rounded, size: 13, color: Colors.cyanAccent),
                    const SizedBox(width: 4),
                    Text(
                      l10n.architectFenestrationExactDimension,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.splitscreen_rounded, size: 16),
              tooltip: l10n.architectFenestrationAddMullion,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                _updateStyle(_style.splitPane(_selectedPaneId!, vertical: true));
              },
            ),
            IconButton(
              icon: const Icon(Icons.table_rows_rounded, size: 16),
              tooltip: l10n.architectFenestrationAddTransom,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                _updateStyle(_style.splitPane(_selectedPaneId!, vertical: false));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              tooltip: l10n.architectFenestrationRemoveSplit,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                _updateStyle(_style.collapsePane(_selectedPaneId!));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadOverlay() {
    final l10n = context.l10n;
    final isWidth = _keypadDimensionIsWidth ?? true;
    final rect = _style.getPaneRect(_selectedPaneId!);
    final currentDim = isWidth
        ? (rect?.width ?? _style.defaultWidth)
        : (rect?.height ?? _style.defaultHeight);
    final currentDimCm = (currentDim * 100).roundToDouble();

    return ArchitectWallDraftingPanel(
      length: currentDimCm,
      unit: 'cm',
      minimumLength: 10.0,
      showContinue: false,
      showDirection: false,
      keypadInitiallyOpen: true,
      title: isWidth
          ? l10n.architectFenestrationLeafWidth
          : l10n.architectFenestrationLeafHeight,
      endLabel: l10n.ok,
      onLength: (valCm) {
        final valM = valCm / 100.0;
        setState(() {
          _style = _style.setPaneMetricDimension(
            _selectedPaneId!,
            valM,
            isWidth,
          );
        });
      },
      onEnd: () {
        setState(() => _keypadDimensionIsWidth = null);
      },
      onCancel: () {
        setState(() => _keypadDimensionIsWidth = null);
      },
      onContinue: () {},
      onUnlock: () {},
    );
  }

  // ===========================================================================
  // SECTION 2: VIEWPORT ROUTING
  // ===========================================================================

  Widget _buildCentralViewport() {
    switch (_viewMode) {
      case FenestrationViewMode.elevation2D:
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(80),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final hit = _style.hitTestFromCanvas(
                          details.localPosition,
                          canvasSize,
                        );
                        if (hit != null) {
                          setState(() {
                            _selectedPaneId = hit.$1.id;
                          });
                          HapticFeedback.selectionClick();
                        }
                      },
                      child: CustomPaint(
                        size: canvasSize,
                        painter: FenestrationElevationPainter(
                          style: _style,
                          selectedPaneId: _selectedPaneId,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Floating Quick CAD HUD on top-left of canvas
            if (_selectedPaneId != null)
              Positioned(
                top: 10,
                left: 10,
                child: _buildCanvasQuickHud(),
              ),

            // Keypad overlay if active
            if (_keypadDimensionIsWidth != null && _selectedPaneId != null)
              Positioned(
                top: 50,
                right: 12,
                width: 260,
                child: _buildKeypadOverlay(),
              ),
          ],
        );

      case FenestrationViewMode.plan2D:
        return _build2DPlanViewport();

      case FenestrationViewMode.orbit3D:
        return _build3DOrbitViewport();
    }
  }

  // ===========================================================================
  // SECTION 3: 2D PARAMETRIC PLAN VIEWPORT
  // ===========================================================================

  Widget _build2DPlanViewport() {
    return Container(
      color: const Color(0xFF1E222B),
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(80),
        minScale: 0.5,
        maxScale: 5.0,
        child: CustomPaint(
          size: Size.infinite,
          painter: _PlanDemoPainter(style: _style),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: 3D ORBIT VIEWPORT WITH WALL SLICE & CASING DEMO
  // ===========================================================================

  Widget _build3DOrbitViewport() {
    final mesh = _buildSampleWallMesh();

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _camera3D.yaw += details.delta.dx * 0.01;
          _camera3D.pitch = (_camera3D.pitch + details.delta.dy * 0.01).clamp(
            0.05,
            math.pi / 2 - 0.05,
          );
        });
      },
      child: Container(
        color: const Color(0xFF14171E),
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

  Mesh3D _buildSampleWallMesh() {
    final List<Triangle3D> allTris = [];

    // Wall parameters: 25 cm brick core + 12 cm exterior EPS insulation = 37 cm total
    const wallThick = 0.37;
    const coreThick = 0.25;
    const insThick = 0.12;
    const extSign = 1.0; // Positive normal points to exterior

    final wallLen = _style.defaultWidth + 1.20;
    final wallStart = Offset(-wallLen / 2.0, 0);
    final wallEnd = Offset(wallLen / 2.0, 0);

    const storeyElev = 0.0;
    final wallH = _style.defaultHeight + _style.defaultSillHeight + 0.60;

    // 1. Build opening geometry (Frame, Mullions, Double Glazing, Exterior Casing)
    allTris.addAll(
      Fenestration3dBuilder.buildOpening3D(
        style: _style,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThick,
        coreThickness: coreThick,
        insulationThickness: insThick,
        exteriorSign: extSign,
        offsetRatio: 0.5,
        width: _style.defaultWidth,
        height: _style.defaultHeight,
        sillHeight: _style.defaultSillHeight,
        storeyElevation: storeyElev,
      ),
    );

    // 2. Add realistic surrounding wall slices (showing casing sitting on exterior face)
    _addWallCutoutPrisms(
      tris: allTris,
      wallStart: wallStart,
      wallEnd: wallEnd,
      wallLen: wallLen,
      coreThick: coreThick,
      insThick: insThick,
      opW: _style.defaultWidth,
      opH: _style.defaultHeight,
      opSill: _style.defaultSillHeight,
      wallH: wallH,
    );

    return Mesh3D(name: _style.name, triangles: allTris);
  }

  void _addWallCutoutPrisms({
    required List<Triangle3D> tris,
    required Offset wallStart,
    required Offset wallEnd,
    required double wallLen,
    required double coreThick,
    required double insThick,
    required double opW,
    required double opH,
    required double opSill,
    required double wallH,
  }) {
    final halfOpW = opW / 2.0;
    final halfLen = wallLen / 2.0;

    const brickColor = Color(0xFFD32F2F); // Brick red
    const epsColor = Color(0xFFB0BEC5);   // EPS insulation light gray

    // Helper to add rectangular prism along X
    void addPrism(double x1, double x2, double y1, double y2, double z1, double z2, Color col) {
      if (x2 <= x1 + 1e-4 || z2 <= z1 + 1e-4) return;
      final b1 = Offset(x1, y1);
      final b2 = Offset(x2, y1);
      final b3 = Offset(x2, y2);
      final b4 = Offset(x1, y2);

      final v1B = Vector3(b1.dx, b1.dy, z1);
      final v2B = Vector3(b2.dx, b2.dy, z1);
      final v3B = Vector3(b3.dx, b3.dy, z1);
      final v4B = Vector3(b4.dx, b4.dy, z1);

      final v1T = Vector3(b1.dx, b1.dy, z2);
      final v2T = Vector3(b2.dx, b2.dy, z2);
      final v3T = Vector3(b3.dx, b3.dy, z2);
      final v4T = Vector3(b4.dx, b4.dy, z2);

      // Sides
      tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: col));
      tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: col));
      tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: col));
      tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: col));
      tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: col));
      tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: col));
      tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: col));
      tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: col));
      // Top & Bottom
      tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: col));
      tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: col));
    }

    // Core is Y in [-coreThick/2, coreThick/2] = [-0.125, 0.125]
    // EPS is Y in [coreThick/2, coreThick/2 + insThick] = [0.125, 0.245]
    final cY1 = -coreThick / 2.0;
    final cY2 = coreThick / 2.0;
    final eY1 = cY2;
    final eY2 = cY2 + insThick;

    final zHead = opSill + opH;

    // 1. Left wall pier
    addPrism(-halfLen, -halfOpW, cY1, cY2, 0, wallH, brickColor);
    addPrism(-halfLen, -halfOpW, eY1, eY2, 0, wallH, epsColor);

    // 2. Right wall pier
    addPrism(halfOpW, halfLen, cY1, cY2, 0, wallH, brickColor);
    addPrism(halfOpW, halfLen, eY1, eY2, 0, wallH, epsColor);

    // 3. Sill section below opening
    if (opSill > 0) {
      addPrism(-halfOpW, halfOpW, cY1, cY2, 0, opSill, brickColor);
      addPrism(-halfOpW, halfOpW, eY1, eY2, 0, opSill, epsColor);
    }

    // 4. Lintel section above opening
    if (zHead < wallH) {
      addPrism(-halfOpW, halfOpW, cY1, cY2, zHead, wallH, brickColor);
      addPrism(-halfOpW, halfOpW, eY1, eY2, zHead, wallH, epsColor);
    }
  }
}

/// Custom painter for horizontal 2D CAD plan representation in editor.
class _PlanDemoPainter extends CustomPainter {
  final ArchitectFenestrationStyle style;

  const _PlanDemoPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10 || size.height < 10) return;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    const wallLen = 4.0;
    const zoomScale = 120.0;

    final wallStart = center - Offset(wallLen * zoomScale / 2.0, 0);
    final wallEnd = center + Offset(wallLen * zoomScale / 2.0, 0);

    const wallThick = 0.37;
    const coreThick = 0.25;
    const insThick = 0.12;

    // Draw background wall body
    final wallPaint = Paint()
      ..color = const Color(0xFF455A64)
      ..strokeWidth = wallThick * zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(wallStart, wallEnd, wallPaint);

    style.paintPlan2D(
      canvas: canvas,
      wallStart: wallStart,
      wallEnd: wallEnd,
      wallThickness: wallThick * zoomScale,
      coreThickness: coreThick * zoomScale,
      insulationThickness: insThick * zoomScale,
      exteriorSign: 1.0,
      offsetRatio: 0.5,
      elementWidth: style.defaultWidth * zoomScale,
      elementHeight: style.defaultHeight * zoomScale,
      elementSillHeight: style.defaultSillHeight * zoomScale,
      zoomScale: 1.0,
      isSelected: true,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanDemoPainter oldDelegate) =>
      oldDelegate.style != style;
}
