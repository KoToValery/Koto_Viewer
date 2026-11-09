import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;
import '../services/architect_selection_candidates.dart';

class ArchitectCandidateLabel {
  final String id, label;
  final String? storey;
  const ArchitectCandidateLabel(this.id, this.label, this.storey);
}

List<ArchitectCandidateLabel> architectCandidateLabels(
  BuildContext context,
  ArchitectProject project,
  List<String> ids, {
  bool includeStorey = false,
}) {
  final l = context.l10n;
  String type(ArchitectTool? tool) => switch (tool) {
    ArchitectTool.wall => l.architectToolWall,
    ArchitectTool.door => l.architectToolDoor,
    ArchitectTool.window => l.architectToolWindow,
    ArchitectTool.column => l.architectToolColumn,
    ArchitectTool.beam => l.architectToolBeam,
    ArchitectTool.slab => l.architectToolSlab,
    ArchitectTool.roof => l.architectToolRoof,
    ArchitectTool.opening => l.architectToolOpening,
    ArchitectTool.stair => l.architectToolStair,
    ArchitectTool.component => l.architectToolComponent,
    ArchitectTool.services => l.architectServiceBodies,
    ArchitectTool.zone => l.architectToolZone,
    ArchitectTool.dimension => l.architectToolDimension,
    ArchitectTool.level => l.architectToolLevel,
    ArchitectTool.text => l.architectToolText,
    ArchitectTool.cadLine => l.architectToolCadLine,
    ArchitectTool.cadRect => l.architectToolCadRect,
    ArchitectTool.cadCircle => l.architectToolCadCircle,
    ArchitectTool.hatch => l.architectToolHatch,
    ArchitectTool.floorDrain => l.architectToolFloorDrain,
    ArchitectTool.axis => l.architectToolAxis,
    ArchitectTool.section => l.architectToolSection,
    ArchitectTool.elevation => l.architectToolElevation,
    _ => l.architectToolSelect,
  };
  final labels = <String, ArchitectCandidateLabel>{};
  final wanted = ids.toSet();
  for (final storey
      in includeStorey ? project.storeys : [project.activeStorey]) {
    final kinds = ArchitectSelectionCandidates.tools(
      project.copyWith(activeStoreyId: storey.id),
    );
    void add(String id, Map<String, dynamic> Function() serialize) {
      if (!wanted.contains(id) ||
          labels.containsKey(id) ||
          !kinds.containsKey(id)) {
        return;
      }
      // Only serialize the requested record, never the complete BIM project.
      final record = serialize();
      final name =
          (record['name'] ??
                  record['text'] ??
                  record['label'] ??
                  record['specId'])
              as String?;
      final label = name == null || name.trim().isEmpty
          ? type(kinds[id])
          : l.architectPickNamed(type(kinds[id]), name);
      labels[id] = ArchitectCandidateLabel(
        id,
        label,
        includeStorey ? storey.name : null,
      );
    }

    for (final wall in storey.walls) {
      add(wall.id, wall.toJson);
      for (final door in wall.doors) {
        add(door.id, door.toJson);
      }
      for (final window in wall.windows) {
        add(window.id, window.toJson);
      }
    }
    for (final e in storey.columns) {
      add(e.id, e.toJson);
    }
    for (final e in storey.beams) {
      add(e.id, e.toJson);
    }
    for (final e in storey.slabs) {
      add(e.id, e.toJson);
    }
    for (final e in storey.roofs) {
      add(e.id, e.toJson);
    }
    for (final e in storey.openings) {
      add(e.id, e.toJson);
    }
    for (final e in storey.stairs) {
      add(e.id, e.toJson);
    }
    for (final e in storey.dimensions) {
      add(e.id, e.toJson);
    }
    for (final e in storey.elevationMarkers) {
      add(e.id, e.toJson);
    }
    for (final e in storey.annotations) {
      add(e.id, e.toJson);
    }
    for (final e in storey.cadPrimitives) {
      add(e.id, e.toJson);
    }
    for (final e in storey.components) {
      add(e.id, e.toJson);
    }
    for (final e in storey.floorDrains) {
      add(e.id, e.toJson);
    }
    for (final e in storey.zones) {
      add(e.id, e.toJson);
    }
    for (final e in project.gridAxes) {
      add(e.id, e.toJson);
    }
    for (final e in project.sections) {
      add(e.id, e.toJson);
    }
    for (final e in project.elevations) {
      add(e.id, e.toJson);
    }
    if (labels.length == wanted.length) break;
  }
  for (final id in ids) {
    if (labels.containsKey(id)) continue;
    if (id == 'underlay_cad') {
      final cfg = project.cadUnderlays[project.activeStoreyId];
      final name = cfg?.fileName.isNotEmpty == true ? cfg!.fileName : l.architectUnderlayToggle;
      labels[id] = ArchitectCandidateLabel(id, l.architectUnderlayCandidate(name), null);
    } else if (id.startsWith('underlay_raster_')) {
      final rasterId = id.substring('underlay_raster_'.length);
      final r = project.rasterUnderlays.where((x) => x.id == rasterId).firstOrNull;
      final name = r?.fileName.isNotEmpty == true ? r!.fileName : 'Raster';
      labels[id] = ArchitectCandidateLabel(id, l.architectUnderlayCandidate(name), null);
    }
  }
  return [
    for (final id in ids)
      labels[id] ?? ArchitectCandidateLabel(id, l.architectToolSelect, null),
  ];
}

/// Shared by the plan and native projection editors. Its sheet owns no model
/// state: every check reads the host selection and every edit goes through it.
class ArchitectCandidatePicker extends StatefulWidget {
  final List<ArchitectCandidateLabel> labels;
  final int index;
  final ValueChanged<int> onIndex;
  final VoidCallback? onApply;
  final bool Function(String) isSelected;
  final bool Function(String) willRemove;
  final Widget? trailing;
  const ArchitectCandidatePicker({
    super.key,
    required this.labels,
    required this.index,
    required this.onIndex,
    this.onApply,
    required this.isSelected,
    required this.willRemove,
    this.trailing,
  });

  @override
  State<ArchitectCandidatePicker> createState() =>
      _ArchitectCandidatePickerState();
}

class _ArchitectCandidatePickerState extends State<ArchitectCandidatePicker> {
  ModalRoute<dynamic>? _sheetRoute;
  void _closeSheet() {
    final route = _sheetRoute;
    _sheetRoute = null;
    if (route != null && route.isActive) {
      // Invalidation may happen while the host is rebuilding.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ArchitectCandidatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.map((e) => e.id).join('\u0000') !=
        widget.labels.map((e) => e.id).join('\u0000')) {
      _closeSheet();
    }
  }

  @override
  void dispose() {
    _closeSheet();
    super.dispose();
  }

  Future<void> _showList() async {
    final l = context.l10n;
    var index = widget.index;
    final labels = widget.labels;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        _sheetRoute = ModalRoute.of(sheetContext);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .45,
            ),
            child: StatefulBuilder(
              builder: (context, refresh) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.architectPickTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('architect-candidate-close'),
                          tooltip: l.close,
                          onPressed: () => Navigator.pop(context),
                          icon: const AppIcon(AppIconId.close),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: labels.length,
                      itemBuilder: (context, i) {
                        final item = labels[i];
                        void choose() {
                          if (!mounted) return;
                          widget.onIndex(i);
                          if (widget.onApply == null) {
                            Navigator.pop(context);
                          } else {
                            widget.onApply!();
                            refresh(() => index = i);
                          }
                        }

                        return ListTile(
                          key: ValueKey('architect-candidate-row-${item.id}'),
                          selected: i == index,
                          title: Text(l.architectPickItem(item.label, i + 1)),
                          subtitle: item.storey == null
                              ? null
                              : Text(item.storey!),
                          trailing: widget.onApply == null
                              ? (i == index ? const AppIcon(AppIconId.confirm) : null)
                              : Checkbox(
                                  semanticLabel: l.architectPickItem(
                                    item.label,
                                    i + 1,
                                  ),
                                  value: widget.isSelected(item.id),
                                  onChanged: (_) => choose(),
                                ),
                          onTap: choose,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _sheetRoute = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final item = widget.labels[widget.index];
    final remove = widget.willRemove(item.id);
    return Material(
      key: const ValueKey('architect-candidate-picker'),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('architect-candidate-previous'),
            tooltip: l.architectPickPrevious,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () =>
                widget.onIndex((widget.index - 1) % widget.labels.length),
            icon: const AppIcon(AppIconId.chevronLeft),
          ),
          Expanded(
            child: TextButton(
              key: const ValueKey('architect-candidate-list'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: _showList,
              child: Semantics(
                label: l.architectPickPosition(
                  item.label,
                  widget.index + 1,
                  widget.labels.length,
                ),
                excludeSemantics: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.index + 1}/${widget.labels.length}',
                      key: const ValueKey('architect-candidate-position'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('architect-candidate-next'),
            tooltip: l.architectPickNext,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () =>
                widget.onIndex((widget.index + 1) % widget.labels.length),
            icon: const AppIcon(AppIconId.chevronRight),
          ),
          if (widget.onApply != null)
            IconButton(
              key: const ValueKey('architect-candidate-apply'),
              tooltip: remove ? l.architectPickRemove : l.architectPickAdd,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: widget.onApply,
              icon: AppIcon.fromMaterial(remove ? Icons.remove : Icons.add),
            ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}

/// A dashed contour makes a candidate distinct from committed selection even
/// on a monochrome display. Coordinates are mapped by the owning editor.
class ArchitectCandidateOutline extends CustomPainter {
  final Path path;
  final Offset Function(Offset) toScreen;
  ArchitectCandidateOutline(this.path, this.toScreen);
  @override
  void paint(Canvas canvas, Size size) {
    final origin = toScreen(Offset.zero);
    final x = toScreen(const Offset(1, 0)) - origin;
    final y = toScreen(const Offset(0, 1)) - origin;
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, x.dx)
      ..setEntry(1, 0, x.dy)
      ..setEntry(0, 1, y.dx)
      ..setEntry(1, 1, y.dy)
      ..setEntry(0, 3, origin.dx)
      ..setEntry(1, 3, origin.dy);
    final screenPath = path.transform(matrix.storage);
    canvas.drawPath(
      screenPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in screenPath.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArchitectCandidateOutline oldDelegate) => true;
}
