// === SECTION: 3D DECORATIVE DETAIL STUDIO SCREEN ===
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../services/architect_decorative_geometry.dart';
import '../services/architect_decorative_library_service.dart';
import '../widgets/architect_decorative_bar.dart';
import '../widgets/architect_wall_drafting_panel.dart';

class DecorativeEditorScreen extends StatefulWidget {
  final ArchitectDecorativeElement? initialElement;
  final ArchitectUnit unit;
  final int decimals;

  const DecorativeEditorScreen({
    super.key,
    this.initialElement,
    this.unit = ArchitectUnit.centimeters,
    this.decimals = 1,
  });

  @override
  State<DecorativeEditorScreen> createState() => _DecorativeEditorScreenState();
}

class _DecorativeEditorScreenState extends State<DecorativeEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ArchitectDecorativeElement _element;
  late TextEditingController _nameController;
  bool _holeMode = false;
  Offset? _holeStart;
  Offset? _holeCurrent;
  int? _draggingVertexIndex;

  // 3D Orbit camera state
  double _yaw = -0.65;
  double _pitch = 0.42;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _element =
        widget.initialElement ??
        ArchitectDecorativeElement.standardCatalog().first;
    _nameController = TextEditingController(text: _element.name);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _promptDimension({
    required String title,
    required double currentMetres,
    required ValueChanged<double> onChanged,
    bool allowZero = false,
  }) async {
    double draft = widget.unit.toUnit(currentMetres);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: 260,
          child: ArchitectWallDraftingPanel(
            length: draft,
            unit: widget.unit.symbol,
            decimals: widget.decimals,
            title: title,
            endLabel: ctx.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            minimumLength: allowZero ? 0.0 : 0.01,
            onLength: (v) => draft = v,
            onEnd: () => Navigator.pop(ctx, draft),
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.pop(ctx, null),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      final metres = widget.unit.fromUnit(result);
      if (allowZero || metres >= 0.005) {
        setState(() => onChanged(metres));
      }
    }
  }

  Future<void> _saveToLibrary() async {
    final l = context.l10n;
    final updated = _element.copyWith(
      id: _element.id.startsWith('preset_')
          ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
          : _element.id,
      name: _nameController.text.trim().isEmpty
          ? l.architectCategoryDecorative
          : _nameController.text.trim(),
    );
    await ArchitectDecorativeLibraryService.instance.saveTemplate(updated);
    if (!mounted) return;
    setState(() => _element = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.architectDecorativeSavedMsg)));
  }

  void _applyAndClose() {
    final l = context.l10n;
    final updated = _element.copyWith(
      name: _nameController.text.trim().isEmpty
          ? l.architectCategoryDecorative
          : _nameController.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final templates = ArchitectDecorativeLibraryService.instance
        .getAllTemplates();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.architectDecorativeStudioTitle),
        actions: [
          IconButton(
            key: const ValueKey('decorative-studio-save-library'),
            tooltip: l.architectDecorativeSaveLibrary,
            onPressed: _saveToLibrary,
            icon: const AppIcon(AppIconId.bookmarkAdd),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              key: const ValueKey('decorative-studio-apply'),
              onPressed: _applyAndClose,
              icon: const AppIcon(AppIconId.confirm, size: 18),
              label: Text(l.save),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.crop_original, size: 18),
              text: l.architectDecorativeTabFront,
            ),
            Tab(
              icon: const Icon(Icons.architecture, size: 18),
              text: l.architectDecorativeTabProfile,
            ),
            Tab(
              icon: const Icon(Icons.view_in_ar, size: 18),
              text: l.architectDecorativeTab3D,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top Preset & Dimensions Bar
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final preset in templates)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: _element.id == preset.id,
                            label: Text(preset.localizedPresetName(l)),
                            onSelected: (_) {
                              setState(() {
                                _element = preset.copyWith(id: _element.id);
                                _nameController.text = preset
                                    .localizedPresetName(l);
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        key: const ValueKey('studio-width-chip'),
                        label: Text(
                          '${l.architectDecorativeWidth}: ${widget.unit.format(_element.spanLength, decimals: widget.decimals)}',
                        ),
                        onPressed: () => _promptDimension(
                          title: l.architectDecorativeWidth,
                          currentMetres: _element.spanLength,
                          onChanged: (m) => _element = _element.withWidth(m),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        key: const ValueKey('studio-height-chip'),
                        label: Text(
                          '${l.architectDecorativeHeight}: ${widget.unit.format(_element.height, decimals: widget.decimals)}',
                        ),
                        onPressed: () => _promptDimension(
                          title: l.architectDecorativeHeight,
                          currentMetres: _element.height,
                          onChanged: (m) => _element = _element.withHeight(m),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        key: const ValueKey('studio-depth-chip'),
                        label: Text(
                          '${l.architectDecorativeDepth}: ${widget.unit.format(_element.depth, decimals: widget.decimals)}',
                        ),
                        onPressed: () => _promptDimension(
                          title: l.architectDecorativeDepth,
                          currentMetres: _element.depth,
                          onChanged: (m) => _element = _element.withDepth(m),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        key: const ValueKey('studio-frame-chip'),
                        label: Text(
                          (_element.frameWidth ?? 0) <= 1e-4
                              ? l.architectDecorativeSolid
                              : '${l.architectDecorativeFrameWidth}: ${widget.unit.format(_element.frameWidth!, decimals: widget.decimals)}',
                        ),
                        onPressed: () => _promptDimension(
                          title: l.architectDecorativeFrameWidth,
                          currentMetres: _element.frameWidth ?? 0.0,
                          allowZero: true,
                          onChanged: (m) => _element = _element.copyWith(
                            frameWidth: m <= 1e-4 ? null : m,
                            clearFrameWidth: m <= 1e-4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<ArchitectDecorativeMaterial>(
                        onSelected: (m) => setState(
                          () => _element = _element.copyWith(material: m),
                        ),
                        itemBuilder: (_) => [
                          for (final m in ArchitectDecorativeMaterial.values)
                            PopupMenuItem(
                              value: m,
                              child: Text(m.localizedLabel(l)),
                            ),
                        ],
                        child: Chip(
                          label: Text(_element.material.localizedLabel(l)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        selected: _element.showOnPlan,
                        label: Text(l.architectDecorativeShowOnPlan),
                        onSelected: (v) => setState(
                          () => _element = _element.copyWith(showOnPlan: v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main 2D / 3D Canvas Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _build2dViewEditor(isFront: true),
                _build2dViewEditor(isFront: false),
                _build3dPreview(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build2dViewEditor({required bool isFront}) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final maxX = isFront ? _element.spanLength : _element.depth;
    final maxY = _element.height;
    final contour = isFront ? _element.frontPolygon : _element.sidePolygon;
    final holes = isFront ? _element.frontHoles : _element.sideHoles;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = 44.0;
        final availW = math.max(100.0, constraints.maxWidth - pad * 2);
        final availH = math.max(100.0, constraints.maxHeight - pad * 2 - 48);
        final scale = math.min(
          availW / math.max(maxX, 0.05),
          availH / math.max(maxY, 0.05),
        );
        final originScreen = Offset(
          (constraints.maxWidth - maxX * scale) / 2,
          pad + (availH + maxY * scale) / 2,
        );

        Offset toScreen(Offset local) => Offset(
          originScreen.dx + local.dx * scale,
          originScreen.dy - local.dy * scale,
        );

        Offset toLocal(Offset screen) {
          final rawX = (screen.dx - originScreen.dx) / scale;
          final rawY = (originScreen.dy - screen.dy) / scale;
          // Snap to 5 mm grid
          final snapX = (rawX / 0.005).round() * 0.005;
          final snapY = (rawY / 0.005).round() * 0.005;
          return Offset(snapX.clamp(0.0, maxX), snapY.clamp(0.0, maxY));
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (_holeMode) return;
                // Check if user tapped an edge midpoint to insert a new vertex
                for (var i = 0; i < contour.length; i++) {
                  final a = contour[i];
                  final b = contour[(i + 1) % contour.length];
                  final midScreen = toScreen((a + b) / 2);
                  if ((details.localPosition - midScreen).distance <= 18) {
                    final next = List<Offset>.from(contour)
                      ..insert(i + 1, (a + b) / 2);
                    setState(() {
                      _element = isFront
                          ? _element.copyWith(frontPolygon: next)
                          : _element.copyWith(sidePolygon: next);
                    });
                    return;
                  }
                }
              },
              onPanStart: (details) {
                final pos = details.localPosition;
                if (_holeMode) {
                  setState(() {
                    _holeStart = toLocal(pos);
                    _holeCurrent = _holeStart;
                  });
                  return;
                }
                for (var i = 0; i < contour.length; i++) {
                  if ((toScreen(contour[i]) - pos).distance <= 22) {
                    _draggingVertexIndex = i;
                    return;
                  }
                }
              },
              onPanUpdate: (details) {
                final pos = details.localPosition;
                if (_holeMode && _holeStart != null) {
                  setState(() {
                    _holeCurrent = toLocal(pos);
                  });
                  return;
                }
                if (_draggingVertexIndex != null) {
                  final next = List<Offset>.from(contour);
                  next[_draggingVertexIndex!] = toLocal(pos);
                  setState(() {
                    _element = isFront
                        ? _element.copyWith(frontPolygon: next)
                        : _element.copyWith(sidePolygon: next);
                  });
                }
              },
              onPanEnd: (_) {
                if (_holeMode && _holeStart != null && _holeCurrent != null) {
                  final r = Rect.fromPoints(_holeStart!, _holeCurrent!);
                  if (r.width >= 0.01 && r.height >= 0.01) {
                    final hole = [
                      Offset(r.left, r.top),
                      Offset(r.right, r.top),
                      Offset(r.right, r.bottom),
                      Offset(r.left, r.bottom),
                    ];
                    setState(() {
                      if (isFront) {
                        _element = _element.copyWith(
                          frontHoles: [..._element.frontHoles, hole],
                        );
                      } else {
                        _element = _element.copyWith(
                          sideHoles: [..._element.sideHoles, hole],
                        );
                      }
                    });
                  }
                }
                setState(() {
                  _holeStart = null;
                  _holeCurrent = null;
                  _draggingVertexIndex = null;
                });
              },
              child: CustomPaint(
                painter: _Decorative2dStudioPainter(
                  element: _element,
                  isFront: isFront,
                  toScreen: toScreen,
                  holeStart: _holeStart,
                  holeCurrent: _holeCurrent,
                  unit: widget.unit,
                  decimals: widget.decimals,
                ),
              ),
            ),

            // Bottom toolbar for 2D contour & hole editing
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          key: ValueKey(
                            'studio-hole-mode-${isFront ? 'front' : 'side'}',
                          ),
                          selected: _holeMode,
                          avatar: Icon(
                            Icons.content_cut,
                            size: 16,
                            color: _holeMode
                                ? colors.onSecondaryContainer
                                : colors.primary,
                          ),
                          label: Text(l.architectDecorativeAddHole),
                          onSelected: (v) => setState(() => _holeMode = v),
                        ),
                        if (holes.isNotEmpty)
                          ActionChip(
                            label: Text(l.architectDecorativeClearHoles),
                            onPressed: () => setState(() {
                              _element = isFront
                                  ? _element.copyWith(frontHoles: const [])
                                  : _element.copyWith(sideHoles: const []);
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _build3dPreview(BuildContext context) {
    final mesh = ArchitectDecorativeGeometry.buildLocalMesh(_element);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleUpdate: (details) {
        setState(() {
          if (details.pointerCount == 1) {
            _yaw += details.focalPointDelta.dx * 0.012;
            _pitch = (_pitch + details.focalPointDelta.dy * 0.012).clamp(
              -1.4,
              1.4,
            );
          } else {
            _zoom = (_zoom * (details.scale > 1 ? 1.02 : 0.98)).clamp(0.4, 3.5);
          }
        });
      },
      child: CustomPaint(
        painter: _Decorative3dPreviewPainter(
          mesh: mesh,
          element: _element,
          yaw: _yaw,
          pitch: _pitch,
          zoom: _zoom,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Decorative2dStudioPainter extends CustomPainter {
  final ArchitectDecorativeElement element;
  final bool isFront;
  final Offset Function(Offset) toScreen;
  final Offset? holeStart;
  final Offset? holeCurrent;
  final ArchitectUnit unit;
  final int decimals;

  const _Decorative2dStudioPainter({
    required this.element,
    required this.isFront,
    required this.toScreen,
    this.holeStart,
    this.holeCurrent,
    required this.unit,
    required this.decimals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxX = isFront ? element.spanLength : element.depth;
    final maxY = element.height;
    final boxRect = Rect.fromPoints(
      toScreen(Offset(0, maxY)),
      toScreen(Offset(maxX, 0)),
    );

    // Draw background grid box
    canvas.drawRect(boxRect, Paint()..color = const Color(0xFFF8FAFC));
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    for (var i = 1; i < 4; i++) {
      final gx = boxRect.left + boxRect.width * (i / 4);
      final gy = boxRect.top + boxRect.height * (i / 4);
      canvas.drawLine(Offset(gx, boxRect.top), Offset(gx, boxRect.bottom), gridPaint);
      canvas.drawLine(Offset(boxRect.left, gy), Offset(boxRect.right, gy), gridPaint);
    }
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final path = isFront
        ? ArchitectDecorativeGeometry.frontPath(element)
        : ArchitectDecorativeGeometry.sidePath(element);

    // Transform local (0..maxX, 0..maxY) path to screen
    final p0 = toScreen(Offset.zero);
    final px = toScreen(const Offset(1, 0)) - p0;
    final py = toScreen(const Offset(0, 1)) - p0;
    final m = Matrix4.identity()
      ..setEntry(0, 0, px.dx)
      ..setEntry(1, 0, px.dy)
      ..setEntry(0, 1, py.dx)
      ..setEntry(1, 1, py.dy)
      ..setEntry(0, 3, p0.dx)
      ..setEntry(1, 3, p0.dy);
    final screenPath = path.transform(m.storage);

    canvas.drawPath(
      screenPath,
      Paint()..color = const Color(0x3300838F),
    );
    canvas.drawPath(
      screenPath,
      Paint()
        ..color = const Color(0xFF006064)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Draw draggable vertices & midpoint add handles
    final contour = isFront ? element.frontPolygon : element.sidePolygon;
    for (var i = 0; i < contour.length; i++) {
      final a = contour[i];
      final b = contour[(i + 1) % contour.length];
      final mid = toScreen((a + b) / 2);
      canvas.drawCircle(mid, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        mid,
        4.5,
        Paint()
          ..color = const Color(0xFF00ACC1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final pt in contour) {
      final s = toScreen(pt);
      canvas.drawCircle(s, 7.0, Paint()..color = const Color(0xFF00838F));
      canvas.drawCircle(
        s,
        7.0,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Active hole drag preview
    if (holeStart != null && holeCurrent != null) {
      final r = Rect.fromPoints(toScreen(holeStart!), toScreen(holeCurrent!));
      canvas.drawRect(r, Paint()..color = const Color(0x33D32F2F));
      canvas.drawRect(
        r,
        Paint()
          ..color = const Color(0xFFD32F2F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Decorative2dStudioPainter oldDelegate) => true;
}

class _Decorative3dPreviewPainter extends CustomPainter {
  final List<Triangle3D> mesh;
  final ArchitectDecorativeElement element;
  final double yaw;
  final double pitch;
  final double zoom;

  const _Decorative3dPreviewPainter({
    required this.mesh,
    required this.element,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.isEmpty) return;
    final center = Vector3(
      element.spanLength / 2,
      element.depth / 2,
      element.height / 2,
    );
    final maxDim = math.max(
      math.max(element.spanLength, element.height),
      element.depth,
    );
    final scale =
        (math.min(size.width, size.height) * 0.58 * zoom) /
        math.max(maxDim, 0.05);
    final screenCenter = Offset(size.width / 2, size.height / 2);

    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);

    Vector3 rotate(Vector3 p) {
      final d = p - center;
      final rx = d.x * cosY - d.y * sinY;
      final ry = d.x * sinY + d.y * cosY;
      final rz = d.z;
      final py = ry * cosP - rz * sinP;
      final pz = ry * sinP + rz * cosP;
      return Vector3(rx, py, pz);
    }

    Offset project(Vector3 r) =>
        Offset(screenCenter.dx + r.x * scale, screenCenter.dy - r.z * scale);

    final baseColor = element.effectiveColor;
    final lightDir = Vector3(0.4, -0.7, 0.6).normalized();

    final faces = <({double depth, Path path, Color color})>[];
    for (final tri in mesh) {
      final v0 = rotate(tri.v0), v1 = rotate(tri.v1), v2 = rotate(tri.v2);
      final normal = (v1 - v0).cross(v2 - v0);
      if (normal.lengthSquared <= 1e-12) continue;
      final nUnit = normal.normalized();
      final intensity = (0.55 + 0.45 * nUnit.dot(lightDir).abs()).clamp(
        0.35,
        1.0,
      );
      final faceColor = Color.fromARGB(
        255,
        ((baseColor.r * 255.0) * intensity).round().clamp(0, 255),
        ((baseColor.g * 255.0) * intensity).round().clamp(0, 255),
        ((baseColor.b * 255.0) * intensity).round().clamp(0, 255),
      );
      final p0 = project(v0), p1 = project(v1), p2 = project(v2);
      final path = Path()..addPolygon([p0, p1, p2], true);
      faces.add((
        depth: (v0.y + v1.y + v2.y) / 3.0,
        path: path,
        color: faceColor,
      ));
    }

    // Painter's algorithm back-to-front
    faces.sort((a, b) => b.depth.compareTo(a.depth));
    final edgePaint = Paint()
      ..color = const Color(0x331E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final f in faces) {
      canvas.drawPath(f.path, Paint()..color = f.color);
      canvas.drawPath(f.path, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Decorative3dPreviewPainter oldDelegate) => true;
}
