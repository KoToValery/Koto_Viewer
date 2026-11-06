import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../rendering/architect_2d_painter.dart' show ArchitectTool;

enum ArchitectToolCategory {
  plan,
  build,
  decorative,
  structure,
  services,
  furnishing,
  views,
  annotations,
  drawing,
  selection;

  String label(AppLocalizations l) => switch (this) {
    selection => l.architectCategoryEdit,
    plan => l.architectCategoryPlan,
    build => l.architectCategoryBuild,
    decorative => l.architectCategoryDecorative,
    structure => l.architectCategoryStructure,
    services => l.architectCategoryServices,
    furnishing => l.architectFurnishing,
    views => l.architectCategoryViews,
    annotations => l.architectCategoryAnnotations,
    drawing => l.architectCategoryDrawing,
  };

  AppIconId get iconId => switch (this) {
    selection => AppIconId.select,
    plan => AppIconId.zone,
    build => AppIconId.wall,
    decorative => AppIconId.roundedCorner,
    structure => AppIconId.beam,
    services => AppIconId.component,
    furnishing => AppIconId.furniture,
    views => AppIconId.section,
    annotations => AppIconId.dimension,
    drawing => AppIconId.polyline,
  };

  bool get availableInDrawing =>
      this == selection ||
      this == annotations ||
      this == drawing ||
      this == decorative;

  // A tool has one home. Sanitary fittings belong to furnishing; roofs are
  // architectural building elements rather than structural analysis tools.
  static ArchitectToolCategory of(ArchitectTool tool) => switch (tool) {
    ArchitectTool.select || ArchitectTool.pan => selection,
    ArchitectTool.zone || ArchitectTool.zoneTable || ArchitectTool.axis => plan,
    ArchitectTool.wall ||
    ArchitectTool.door ||
    ArchitectTool.window ||
    ArchitectTool.stair ||
    ArchitectTool.roof => build,
    ArchitectTool.decorativeProfile ||
    ArchitectTool.decorativeFrame ||
    ArchitectTool.decorativeArc ||
    ArchitectTool.decorativeVoid ||
    ArchitectTool.decorativeLibrary => decorative,
    ArchitectTool.opening || ArchitectTool.services => services,
    ArchitectTool.component || ArchitectTool.floorDrain => furnishing,
    ArchitectTool.column ||
    ArchitectTool.beam ||
    ArchitectTool.slab => structure,
    ArchitectTool.section || ArchitectTool.elevation => views,
    ArchitectTool.dimension ||
    ArchitectTool.level ||
    ArchitectTool.text ||
    ArchitectTool.measure => annotations,
    ArchitectTool.cadLine ||
    ArchitectTool.cadRect ||
    ArchitectTool.hatch ||
    ArchitectTool.cadCircle => drawing,
  };

  List<ArchitectTool> get tools => [
    for (final tool in ArchitectTool.values)
      if (of(tool) == this) tool,
  ];
}

extension ArchitectToolCatalogLabel on ArchitectTool {
  (AppIconId, String) presentation(AppLocalizations l) => switch (this) {
    ArchitectTool.pan => (AppIconId.pan, l.architectToolPan),
    ArchitectTool.select => (AppIconId.select, l.architectToolSelect),
    ArchitectTool.wall => (AppIconId.wall, l.architectToolWall),
    ArchitectTool.door => (AppIconId.door, l.architectToolDoor),
    ArchitectTool.window => (AppIconId.window, l.architectToolWindow),
    ArchitectTool.column => (AppIconId.column, l.architectToolColumn),
    ArchitectTool.beam => (AppIconId.beam, l.architectToolBeam),
    ArchitectTool.slab => (AppIconId.slab, l.architectToolSlab),
    ArchitectTool.floorDrain => (
      AppIconId.floorDrain,
      l.architectToolFloorDrain,
    ),
    ArchitectTool.roof => (AppIconId.roof, l.architectToolRoof),
    ArchitectTool.opening => (AppIconId.opening, l.architectToolOpening),
    ArchitectTool.stair => (AppIconId.stairs, l.architectToolStair),
    ArchitectTool.component => (AppIconId.furniture, l.architectLibrary),
    ArchitectTool.services => (AppIconId.component, l.architectServiceBodies),
    ArchitectTool.zone => (AppIconId.zone, l.architectToolZone),
    ArchitectTool.zoneTable => (AppIconId.schedule, l.architectToolZoneTable),
    ArchitectTool.dimension => (AppIconId.dimension, l.architectToolDimension),
    ArchitectTool.level => (AppIconId.level, l.architectToolLevel),
    ArchitectTool.text => (AppIconId.text, l.architectToolText),
    ArchitectTool.cadLine => (AppIconId.line, l.architectToolCadLine),
    ArchitectTool.cadRect => (AppIconId.rectangle, l.architectToolCadRect),
    ArchitectTool.hatch => (AppIconId.hatch, l.architectToolHatch),
    ArchitectTool.cadCircle => (AppIconId.radioOff, l.architectToolCadCircle),
    ArchitectTool.section => (AppIconId.section, l.architectToolSection),
    ArchitectTool.elevation => (AppIconId.elevation, l.architectToolElevation),
    ArchitectTool.axis => (AppIconId.axis, l.architectToolAxis),
    ArchitectTool.measure => (AppIconId.measure, l.architectToolMeasure),
    ArchitectTool.decorativeProfile => (
      AppIconId.polygon,
      l.architectToolDecorativeProfile,
    ),
    ArchitectTool.decorativeFrame => (
      AppIconId.offset,
      l.architectToolDecorativeFrame,
    ),
    ArchitectTool.decorativeArc => (
      AppIconId.arc,
      l.architectToolDecorativeArc,
    ),
    ArchitectTool.decorativeVoid => (
      AppIconId.cutOpening,
      l.architectToolDecorativeVoid,
    ),
    ArchitectTool.decorativeLibrary => (
      AppIconId.library,
      l.architectToolDecorativeLibrary,
    ),
  };
}

typedef ArchitectToolChoice = ({
  ArchitectToolCategory category,
  ArchitectTool? tool,
});

/// Category overview and direct tool search share the same localized catalog.
class ArchitectToolBrowser extends StatefulWidget {
  final ArchitectToolCategory category;
  final ArchitectTool activeTool;
  final bool drawingOnly;
  const ArchitectToolBrowser({
    super.key,
    required this.category,
    required this.activeTool,
    this.drawingOnly = false,
  });

  @override
  State<ArchitectToolBrowser> createState() => _ToolBrowserState();
}

class _ToolBrowserState extends State<ArchitectToolBrowser> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, colors = Theme.of(context).colorScheme;
    final categories = [
      ArchitectToolCategory.selection,
      ...ArchitectToolCategory.values.where(
        (c) => c != ArchitectToolCategory.selection,
      ),
    ].where((c) => !widget.drawingOnly || c.availableInDrawing).toList();
    final current = categories.contains(widget.category)
        ? widget.category
        : ArchitectToolCategory.drawing;
    final matches = [
      for (final c in categories)
        for (final t in c.tools)
          if (query.isEmpty ||
              '${t.presentation(l).$2} ${c.label(l)}'.toLowerCase().contains(
                query.trim().toLowerCase(),
              ))
            t,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.architectToolCategories,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  icon: const AppIcon(AppIconId.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('architect-tool-search'),
              decoration: InputDecoration(
                labelText: l.architectToolSearch,
                prefixIcon: const AppIcon(AppIconId.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (query.isEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 600 ? 4 : 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in categories)
                                SizedBox(
                                  width:
                                      (constraints.maxWidth -
                                          (columns - 1) * 8) /
                                      columns,
                                  child: Material(
                                    color: c == current
                                        ? colors.secondaryContainer
                                        : colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      key: ValueKey(
                                        'architect-category-${c.name}',
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => Navigator.pop(context, (
                                        category: c,
                                        tool: null,
                                      )),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                AppIcon(
                                                  c.iconId,
                                                  size: 20,
                                                  color: colors.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    c.label(l),
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelLarge,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              c.tools
                                                  .map(
                                                    (t) => t.presentation(l).$2,
                                                  )
                                                  .join(' · '),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
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
                      ),
                    if (query.isEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        current.label(l),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (query.isNotEmpty && matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l.architectToolNoResults),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in query.isEmpty ? current.tools : matches)
                          OutlinedButton.icon(
                            key: ValueKey('architect-catalog-tool-${t.name}'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: t == widget.activeTool
                                  ? colors.secondaryContainer
                                  : null,
                            ),
                            icon: AppIcon(t.presentation(l).$1, size: 20),
                            label: Text(t.presentation(l).$2),
                            onPressed: () => Navigator.pop(context, (
                              category: ArchitectToolCategory.of(t),
                              tool: t,
                            )),
                          ),
                      ],
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
}
