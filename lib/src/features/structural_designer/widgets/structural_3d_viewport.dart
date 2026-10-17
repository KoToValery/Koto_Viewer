import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../cad_3d/cad_3d_controller.dart';
import '../../cad_3d/models/mesh_3d.dart';
import '../../cad_3d/rendering/cad_3d_backend.dart';
import '../../cad_3d/rendering/cad_3d_labels.dart';
import '../../cad_3d/rendering/cad_3d_mesh_painter.dart';
import '../../cad_3d/widgets/cad_3d_viewport.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import '../rendering/structural_3d_mesh_builder.dart';

/// Structural analyses retain their colors/filters in the common 3D viewport.
class Structural3dViewport extends StatefulWidget {
  final StructuralProject project;
  final List<CantileverZone> cantileverZones;
  final VerticalCapacityReport? verticalReport;
  final SeismicAnalysisReport? seismicReport;
  final VoidCallback onExit;
  final double cadUnitsPerMeter;

  const Structural3dViewport({
    super.key,
    required this.project,
    this.cantileverZones = const [],
    this.verticalReport,
    this.seismicReport,
    required this.onExit,
    this.cadUnitsPerMeter = 1.0,
  });

  @override
  State<Structural3dViewport> createState() => _Structural3dViewportState();
}

class _Structural3dViewportState extends State<Structural3dViewport> {
  final Cad3DController _navigation = Cad3DController();
  Cad3DShadingMode _shadingMode = Cad3DShadingMode.cadShadedEdges;
  int? _highlightStoreyIndex;
  late Mesh3D _mesh;
  bool _preferNativeDepth = true;

  @override
  void initState() {
    super.initState();
    _rebuildMesh();
  }

  @override
  void dispose() {
    _navigation.dispose();
    super.dispose();
  }

  void _rebuildMesh() {
    _mesh = Structural3dMeshBuilder.buildProjectMesh(
      widget.project,
      cantileverZones: widget.cantileverZones,
      verticalReport: widget.verticalReport,
      seismicReport: widget.seismicReport,
      highlightStoreyIndex: _highlightStoreyIndex,
      cadUnitsPerMeter: widget.cadUnitsPerMeter,
    );
  }

  @override
  void didUpdateWidget(Structural3dViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_highlightStoreyIndex != null &&
        _highlightStoreyIndex! >= widget.project.storeys.length) {
      _highlightStoreyIndex = null;
    }
    if (oldWidget.project != widget.project ||
        oldWidget.cantileverZones != widget.cantileverZones ||
        oldWidget.verticalReport != widget.verticalReport ||
        oldWidget.seismicReport != widget.seismicReport ||
        oldWidget.cadUnitsPerMeter != widget.cadUnitsPerMeter) {
      _rebuildMesh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Cad3DTheme.darkCad.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onExit,
        ),
        title: Text(l10n.structural3dTitle),
        actions: [
          if (Cad3DRenderBackend.acceleratedAvailable)
            IconButton(
              icon: Icon(
                _preferNativeDepth ? Icons.layers : Icons.layers_outlined,
              ),
              tooltip: _preferNativeDepth
                  ? l10n.cad3dNativeDepthOn
                  : l10n.cad3dNativeDepthOff,
              onPressed: () =>
                  setState(() => _preferNativeDepth = !_preferNativeDepth),
            ),
          PopupMenuButton<Cad3DShadingMode>(
            icon: Icon(_shadingMode.icon),
            tooltip: l10n.shadingModeTitle,
            onSelected: (mode) => setState(() => _shadingMode = mode),
            itemBuilder: (_) => [
              for (final mode in Cad3DShadingMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Text(mode.localizedLabel(l10n)),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Cad3DViewport(
              mesh: _mesh,
              controller: _navigation,
              shadingMode: _shadingMode,
              unitsPerMeter: widget.cadUnitsPerMeter,
              preferNativeDepth: _preferNativeDepth,
              controlsTop: 64,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n.allStoreys),
                    selected: _highlightStoreyIndex == null,
                    onSelected: (_) => setState(() {
                      _highlightStoreyIndex = null;
                      _rebuildMesh();
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                  for (var i = 0; i < widget.project.storeys.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(widget.project.storeys[i].name),
                        selected: _highlightStoreyIndex == i,
                        onSelected: (selected) => setState(() {
                          _highlightStoreyIndex = selected ? i : null;
                          _rebuildMesh();
                        }),
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
