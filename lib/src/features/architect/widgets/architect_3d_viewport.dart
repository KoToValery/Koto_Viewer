import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../cad_3d/cad_3d_controller.dart';
import '../../cad_3d/models/mesh_3d.dart';
import '../../cad_3d/rendering/cad_3d_backend.dart';
import '../../cad_3d/rendering/cad_3d_labels.dart';
import '../../cad_3d/rendering/cad_3d_mesh_painter.dart';
import '../../cad_3d/widgets/cad_3d_viewport.dart';
import '../models/architect_project.dart';
import '../rendering/architect_3d_builder.dart';
import '../services/architect_projection_loader.dart';
import 'architect_projection_status.dart';

/// Caches the architectural scene independently of workspace and camera builds.
class Architect3dViewport extends StatefulWidget {
  final ArchitectProject project;
  final Cad3DController controller;
  final VoidCallback? onBackToPlan;
  const Architect3dViewport({
    super.key,
    required this.project,
    required this.controller,
    this.onBackToPlan,
  });

  @override
  State<Architect3dViewport> createState() => _Architect3dViewportState();
}

class _Architect3dViewportState extends State<Architect3dViewport> {
  Mesh3D? _mesh;
  late final ArchitectProjectionLoader<Mesh3D> _loader =
      ArchitectProjectionLoader<Mesh3D>(() {
        if (mounted) setState(() => _mesh = _loader.data);
      });
  Cad3DShadingMode _shading = Cad3DShadingMode.smoothShaded;
  bool _nativeDepth = true;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    if (!widget.project.storeys.any(
      (s) => s.walls.any((w) => w.system.isSpecial),
    )) {
      _loader.invalidate();
      _mesh = Architect3dBuilder.buildProjectMesh(widget.project);
      return;
    }
    final project = widget.project;
    _loader.ensure(
      project,
      'scene',
      () => Architect3dBuilder.buildProjectMeshAsync(project),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Architect3dViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.project.storeys, widget.project.storeys) ||
        !identical(
          oldWidget.project.slabAssemblies,
          widget.project.slabAssemblies,
        ) ||
        !identical(
          oldWidget.project.existingTerrain,
          widget.project.existingTerrain,
        ) ||
        !identical(
          oldWidget.project.proposedTerrain,
          widget.project.proposedTerrain,
        )) {
      _rebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        if (_mesh != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _loader.loading,
              child: Cad3DViewport(
                mesh: _mesh!,
                controller: widget.controller,
                unitsPerMeter: 1,
                theme: Cad3DTheme.lightStudio,
                shadingMode: _shading,
                preferNativeDepth: _nativeDepth,
              ),
            ),
          ),
        if (_loader.loading || _loader.failed)
          Positioned.fill(
            child: ArchitectProjectionStatus(
              failed: _loader.failed,
              onRetry: () => setState(() {
                _loader.invalidate();
                _rebuild();
              }),
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: Material(
            color: Cad3DTheme.lightStudio.background,
            borderRadius: BorderRadius.circular(12),
            child: PopupMenuButton<Object>(
              key: const ValueKey('architect-3d-display'),
              tooltip: l10n.shadingModeTitle,
              icon: AppIcon(_shading.iconId),
              onSelected: (value) => setState(() {
                if (value is Cad3DShadingMode) {
                  _shading = value;
                } else {
                  _nativeDepth = !_nativeDepth;
                }
              }),
              itemBuilder: (_) => [
                for (final mode in Cad3DShadingMode.values)
                  CheckedPopupMenuItem(
                    value: mode,
                    checked: _shading == mode,
                    child: AppMenuLabel(
                      icon: mode.iconId,
                      child: Text(mode.localizedLabel(l10n)),
                    ),
                  ),
                if (Cad3DRenderBackend.acceleratedAvailable) ...[
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: 'nativeDepth',
                    checked: _nativeDepth,
                    child: AppMenuLabel(
                      icon: AppIconId.layers,
                      child: Text(l10n.cad3dNativeDepthOn),
                  ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.onBackToPlan != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: SafeArea(
              top: false,
              left: false,
              child: Material(
                color: const Color(0xFF1E1E26).withValues(alpha: 0.92),
                elevation: 3,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  key: const ValueKey('architect-3d-back-to-plan'),
                  borderRadius: BorderRadius.circular(24),
                  onTap: widget.onBackToPlan,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(
                            AppIconId.back,
                            size: 16,
                            color: Color(0xFF00E5FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.architectView2D,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
