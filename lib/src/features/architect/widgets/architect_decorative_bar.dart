// === SECTION: ARCHITECT DECORATIVE SUB-BAR ===
import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../services/architect_decorative_library_service.dart';
import 'architect_wall_drafting_panel.dart';

extension ArchitectDecorativeMaterialL10n on ArchitectDecorativeMaterial {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ArchitectDecorativeMaterial.eps => l10n.architectDecorativeMaterialEps,
    ArchitectDecorativeMaterial.plaster =>
      l10n.architectDecorativeMaterialPlaster,
    ArchitectDecorativeMaterial.stone => l10n.architectDecorativeMaterialStone,
    ArchitectDecorativeMaterial.timber =>
      l10n.architectDecorativeMaterialTimber,
    ArchitectDecorativeMaterial.concrete =>
      l10n.architectDecorativeMaterialConcrete,
    ArchitectDecorativeMaterial.metal => l10n.architectDecorativeMaterialMetal,
  };
}

extension ArchitectDecorativePresetL10n on ArchitectDecorativeElement {
  String localizedPresetName(AppLocalizations l10n) =>
      ArchitectDecorativeElement.localizedPresetName(l10n, this);
}

class ArchitectDecorativeBar extends StatelessWidget {
  final ArchitectTool activeTool;
  final ArchitectUnit unit;
  final int decimals;
  final double depth;
  final double spanLength;
  final double frameWidth;
  final double normalOffset;
  final ArchitectDecorativeMaterial material;
  final ArchitectDecorativeElement? activePreset;
  final bool showOnPlan;
  final ValueChanged<double>? onDepthChanged;
  final ValueChanged<double>? onSpanLengthChanged;
  final ValueChanged<double>? onFrameWidthChanged;
  final ValueChanged<double>? onNormalOffsetChanged;
  final ValueChanged<ArchitectDecorativeMaterial>? onMaterialChanged;
  final ValueChanged<ArchitectDecorativeElement?>? onPresetChanged;
  final ValueChanged<bool>? onShowOnPlanChanged;
  final VoidCallback? onOpenStudio;

  const ArchitectDecorativeBar({
    super.key,
    required this.activeTool,
    this.unit = ArchitectUnit.centimeters,
    this.decimals = 1,
    required this.depth,
    required this.spanLength,
    required this.frameWidth,
    required this.normalOffset,
    required this.material,
    this.activePreset,
    this.showOnPlan = false,
    this.onDepthChanged,
    this.onSpanLengthChanged,
    this.onFrameWidthChanged,
    this.onNormalOffsetChanged,
    this.onMaterialChanged,
    this.onPresetChanged,
    this.onShowOnPlanChanged,
    this.onOpenStudio,
  });

  Future<void> _promptNumber(
    BuildContext context, {
    required String title,
    required double currentMetres,
    required ValueChanged<double>? onChanged,
    bool signed = false,
  }) async {
    if (onChanged == null) return;
    double draft = unit.toUnit(currentMetres);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: 260,
          child: ArchitectWallDraftingPanel(
            length: draft,
            unit: unit.symbol,
            decimals: decimals,
            title: title,
            endLabel: ctx.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            minimumLength: signed ? -double.infinity : 0.0,
            onLength: (v) => draft = v,
            onEnd: () => Navigator.pop(ctx, draft),
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.pop(ctx, null),
          ),
        ),
      ),
    );
    if (result != null) {
      onChanged(unit.fromUnit(result));
    }
  }

  Future<void> _showPresetSheet(BuildContext context) async {
    final l = context.l10n;
    final presets = ArchitectDecorativeLibraryService.instance.getAllTemplates();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.architectDecorativeTemplates,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    if (onOpenStudio != null)
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onOpenStudio!();
                        },
                        icon: const Icon(Icons.view_in_ar, size: 18),
                        label: Text(l.architectDecorativeEditStudio),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: activePreset == null,
                          label: Text(l.architectToolDecorativeProfile),
                          onSelected: (_) {
                            onPresetChanged?.call(null);
                            Navigator.pop(ctx);
                          },
                        ),
                        for (final preset in presets)
                          ChoiceChip(
                            selected: activePreset?.id == preset.id,
                            avatar: Icon(
                              preset.mode ==
                                      ArchitectDecorativeCreationMode.section
                                  ? Icons.architecture
                                  : Icons.crop_square,
                              size: 16,
                              color: colors.primary,
                            ),
                            label: Text(preset.localizedPresetName(l)),
                            onSelected: (_) {
                              onPresetChanged?.call(preset);
                              Navigator.pop(ctx);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. 3D Studio button
          if (onOpenStudio != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                key: const ValueKey('architect-decorative-open-studio'),
                avatar: Icon(
                  Icons.view_in_ar,
                  size: 16,
                  color: colors.primary,
                ),
                label: Text(l.architectDecorativeEditStudio),
                onPressed: onOpenStudio,
              ),
            ),

          // 2. Template / Preset selector
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: const ValueKey('architect-decorative-preset-chip'),
              avatar: AppIcon(
                AppIconId.library,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                activePreset != null
                    ? activePreset!.localizedPresetName(l)
                    : l.architectDecorativeTemplates,
              ),
              onPressed: () => _showPresetSheet(context),
            ),
          ),

          // 3. Depth (thickness perpendicular to facade / section)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: const ValueKey('architect-decorative-depth-chip'),
              label: Text(
                '${l.architectDecorativeDepth}: ${unit.format(depth, decimals: decimals)}',
              ),
              onPressed: () => _promptNumber(
                context,
                title: l.architectDecorativeDepth,
                currentMetres: depth,
                onChanged: (v) => onDepthChanged?.call(v.clamp(0.005, 5.0)),
              ),
            ),
          ),

          // 4. Span Length (extrusion length when drawn in Section)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: const ValueKey('architect-decorative-span-chip'),
              label: Text(
                '${l.architectDecorativeLength}: ${unit.format(spanLength, decimals: decimals)}',
              ),
              onPressed: () => _promptNumber(
                context,
                title: l.architectDecorativeLength,
                currentMetres: spanLength,
                onChanged: (v) =>
                    onSpanLengthChanged?.call(v.clamp(0.05, 50.0)),
              ),
            ),
          ),

          // 5. Frame width (when Frame tool is active)
          if (activeTool == ArchitectTool.decorativeFrame)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                key: const ValueKey('architect-decorative-frame-width-chip'),
                label: Text(
                  frameWidth <= 1e-4
                      ? l.architectDecorativeSolid
                      : '${l.architectDecorativeFrameWidth}: ${unit.format(frameWidth, decimals: decimals)}',
                ),
                onPressed: () => _promptNumber(
                  context,
                  title: l.architectDecorativeFrameWidth,
                  currentMetres: frameWidth,
                  onChanged: (v) =>
                      onFrameWidthChanged?.call(v.clamp(0.0, 2.0)),
                ),
              ),
            ),

          // 6. Normal offset (in/out of wall face)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              key: const ValueKey('architect-decorative-normal-offset-chip'),
              label: Text(
                '${l.architectDecorativeNormalOffset}: ${unit.format(normalOffset, decimals: decimals)}',
              ),
              onPressed: () => _promptNumber(
                context,
                title: l.architectDecorativeNormalOffset,
                currentMetres: normalOffset,
                signed: true,
                onChanged: (v) =>
                    onNormalOffsetChanged?.call(v.clamp(-1.0, 2.0)),
              ),
            ),
          ),

          // 7. Material selector
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PopupMenuButton<ArchitectDecorativeMaterial>(
              tooltip: l.architectDecorativeMaterial,
              onSelected: onMaterialChanged,
              itemBuilder: (_) => [
                for (final m in ArchitectDecorativeMaterial.values)
                  PopupMenuItem(
                    value: m,
                    child: Text(m.localizedLabel(l)),
                  ),
              ],
              child: Chip(
                label: Text(
                  '${l.architectDecorativeMaterial}: ${material.localizedLabel(l)}',
                ),
              ),
            ),
          ),

          // 8. Show on Floor Plan toggle
          if (onShowOnPlanChanged != null)
            FilterChip(
              key: const ValueKey('architect-decorative-show-on-plan'),
              selected: showOnPlan,
              label: Text(l.architectDecorativeShowAllOnPlan),
              onSelected: onShowOnPlanChanged,
            ),
        ],
      ),
    );
  }
}
