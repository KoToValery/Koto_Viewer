import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import '../rendering/structural_3d_mesh_builder.dart';

/// Fullscreen interactive 3D viewport for structural frames, slabs, and cantilevers.
class Structural3dViewport extends StatefulWidget {
  final StructuralProject project;
  final List<CantileverZone> cantileverZones;
  final VoidCallback onExit;

  const Structural3dViewport({
    super.key,
    required this.project,
    this.cantileverZones = const [],
    required this.onExit,
  });

  @override
  State<Structural3dViewport> createState() => _Structural3dViewportState();
}

class _Structural3dViewportState extends State<Structural3dViewport> {
  late final Cad3DCamera _camera;
  Cad3DShadingMode _shadingMode = Cad3DShadingMode.cadShadedEdges;
  int? _highlightStoreyIndex;
  late Mesh3D _mesh;
  bool _isInteracting = false;

  Offset? _lastPanPos;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _camera = Cad3DCamera(
      yaw: math.pi / 4,
      pitch: 0.615,
      zoom: 1.0,
      mode: Cad3DInteractionMode.orbit,
    );
    _rebuildMesh();
  }

  void _rebuildMesh() {
    _mesh = Structural3dMeshBuilder.buildProjectMesh(
      widget.project,
      cantileverZones: widget.cantileverZones,
      highlightStoreyIndex: _highlightStoreyIndex,
    );
  }

  @override
  void didUpdateWidget(covariant Structural3dViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project ||
        oldWidget.cantileverZones != widget.cantileverZones) {
      _rebuildMesh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onExit,
          tooltip: 'Назад към 2D план',
        ),
        title: Text(
          '3D Конструктивен Модел (${_mesh.triangleCount} полигона)',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // Shading mode menu
          PopupMenuButton<Cad3DShadingMode>(
            icon: Icon(_shadingMode.icon, color: Colors.white70),
            tooltip: 'Режим на осветяване',
            onSelected: (mode) => setState(() => _shadingMode = mode),
            itemBuilder: (ctx) => [
              for (final m in Cad3DShadingMode.values)
                PopupMenuItem(
                  value: m,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(m.label),
                    ],
                  ),
                ),
            ],
          ),
          // Reset Camera
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
            tooltip: 'Центрирай изглед',
            onPressed: () {
              setState(() {
                _camera.yaw = math.pi / 4;
                _camera.pitch = 0.615;
                _camera.zoom = 1.0;
                _camera.panOffset = Offset.zero;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 3D Canvas with Gestures
          GestureDetector(
            onScaleStart: (details) {
              _isInteracting = true;
              _lastPanPos = details.localFocalPoint;
              _baseZoom = _camera.zoom;
            },
            onScaleUpdate: (details) {
              setState(() {
                if (details.pointerCount == 1 && _lastPanPos != null) {
                  // Single finger: orbit rotation
                  final delta = details.localFocalPoint - _lastPanPos!;
                  _camera.yaw += delta.dx * 0.01;
                  _camera.pitch = (_camera.pitch - delta.dy * 0.01)
                      .clamp(-math.pi / 2.1, math.pi / 2.1);
                  _lastPanPos = details.localFocalPoint;
                } else if (details.pointerCount > 1) {
                  // Multi-touch: zoom & pan
                  _camera.zoom = (_baseZoom * details.scale).clamp(0.2, 10.0);
                  if (_lastPanPos != null) {
                    final delta = details.localFocalPoint - _lastPanPos!;
                    _camera.panOffset += delta;
                    _lastPanPos = details.localFocalPoint;
                  }
                }
              });
            },
            onScaleEnd: (_) {
              setState(() {
                _isInteracting = false;
                _lastPanPos = null;
              });
            },
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  setState(() {
                    final factor = signal.scrollDelta.dy > 0 ? 0.9 : 1.1;
                    _camera.zoom = (_camera.zoom * factor).clamp(0.2, 10.0);
                  });
                }
              },
              child: CustomPaint(
                size: Size.infinite,
                painter: Cad3DMeshPainter(
                  mesh: _mesh,
                  camera: _camera,
                  shadingMode: _shadingMode,
                  theme: Cad3DTheme.darkCad,
                  showGrid: true,
                  isInteracting: _isInteracting,
                ),
              ),
            ),
          ),

          // Storey Filter Chips (Top Overlay)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Всички етажи'),
                    selected: _highlightStoreyIndex == null,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _highlightStoreyIndex = null;
                          _rebuildMesh();
                        });
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  for (int i = 0; i < widget.project.storeys.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(widget.project.storeys[i].name),
                        selected: _highlightStoreyIndex == i,
                        onSelected: (sel) {
                          setState(() {
                            _highlightStoreyIndex = sel ? i : null;
                            _rebuildMesh();
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
