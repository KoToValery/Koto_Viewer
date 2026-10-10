import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../rendering/structural_pointer_painter.dart';

enum StructuralToolGroup { underlay, structure, checks }

/// Group selection is UI state; switching tools never changes model ownership.
class StructuralToolGroups extends StatefulWidget {
  final StructuralDrawTool activeTool;
  final VoidCallback onLeavePlacement;
  final Widget? options;
  final Widget Function(BuildContext, StructuralToolGroup) toolsBuilder;
  const StructuralToolGroups({
    super.key,
    required this.activeTool,
    required this.onLeavePlacement,
    this.options,
    required this.toolsBuilder,
  });

  @override
  State<StructuralToolGroups> createState() => _StructuralToolGroupsState();
}

class _StructuralToolGroupsState extends State<StructuralToolGroups> {
  late StructuralToolGroup group;
  StructuralToolGroup groupFor(StructuralDrawTool tool) =>
      tool == StructuralDrawTool.layers || tool == StructuralDrawTool.measure
      ? StructuralToolGroup.underlay
      : StructuralToolGroup.structure;
  @override
  void initState() {
    super.initState();
    group = groupFor(widget.activeTool);
  }

  @override
  void didUpdateWidget(covariant StructuralToolGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool &&
        widget.activeTool != StructuralDrawTool.select) {
      group = groupFor(widget.activeTool);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.bimToolGroupUnderlay,
      context.l10n.bimToolGroupStructure,
      context.l10n.bimToolGroupChecks,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final value in StructuralToolGroup.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    key: ValueKey('bim-tool-group-${value.name}'),
                    onPressed: () {
                      if (group == value) return;
                      widget.onLeavePlacement();
                      setState(() => group = value);
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: group == value
                          ? const Color(0xFF00E5FF)
                          : Colors.white70,
                      backgroundColor: group == value
                          ? const Color(0x3300E5FF)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      labels[value.index],
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (group != StructuralToolGroup.checks && widget.options != null) ...[
          const SizedBox(height: 4),
          KeyedSubtree(
            key: ValueKey(widget.activeTool),
            child: widget.options!,
          ),
        ],
        const SizedBox(height: 4),
        SingleChildScrollView(
          key: ValueKey(group),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: widget.toolsBuilder(context, group),
        ),
      ],
    );
  }
}
