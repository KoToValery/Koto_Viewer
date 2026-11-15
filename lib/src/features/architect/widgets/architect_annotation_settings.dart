import 'architect_dialog.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_drawing_publisher.dart';
import 'architect_numeric_keypad.dart';

/// Localized label for an annotation typography role.
String architectAnnotationRoleLabel(
  AppLocalizations l,
  ArchitectAnnotationRole value,
) => switch (value) {
  ArchitectAnnotationRole.axis => l.architectAnnotationAxis,
  ArchitectAnnotationRole.section => l.architectAnnotationSection,
  ArchitectAnnotationRole.title => l.architectAnnotationTitle,
  ArchitectAnnotationRole.roomName => l.architectAnnotationRooms,
  ArchitectAnnotationRole.dimension => l.architectAnnotationDimension,
  ArchitectAnnotationRole.opening => l.architectAnnotationOpening,
  ArchitectAnnotationRole.site => l.architectAnnotationSite,
  ArchitectAnnotationRole.ordinary => l.architectAnnotationOrdinary,
  ArchitectAnnotationRole.table => l.architectAnnotationTable,
  ArchitectAnnotationRole.area => l.architectAnnotationArea,
  ArchitectAnnotationRole.symbol => l.architectAnnotationSymbol,
};

/// Compact per-scale paper font size matrix shared by Main Settings and Layout.
class ArchitectTypographyProfilePanel extends StatefulWidget {
  final Map<String, double> profileMm;
  final ValueChanged<Map<String, double>> onChanged;
  final int initialScale;

  const ArchitectTypographyProfilePanel({
    super.key,
    required this.profileMm,
    required this.onChanged,
    this.initialScale = 100,
  });

  @override
  State<ArchitectTypographyProfilePanel> createState() =>
      _ArchitectTypographyProfilePanelState();
}

class _ArchitectTypographyProfilePanelState
    extends State<ArchitectTypographyProfilePanel> {
  late int _scale = ArchitectDrawingScale.presets.contains(widget.initialScale)
      ? widget.initialScale
      : ArchitectDimensionScale.forDenominator(widget.initialScale).denominator;

  bool _hasScaleOverride(int scale) =>
      widget.profileMm.keys.any((k) => k.startsWith('$scale/'));

  double _valueFor(ArchitectAnnotationRole role) =>
      widget.profileMm['$_scale/${role.name}'] ??
      ArchitectDrawingScale.defaultMmFor(role, _scale);

  bool _isCustom(ArchitectAnnotationRole role) =>
      widget.profileMm.containsKey('$_scale/${role.name}');

  void _setRole(ArchitectAnnotationRole role, double value) {
    final rounded = (value.clamp(0.5, 20.0) * 100).round() / 100;
    final def = ArchitectDrawingScale.defaultMmFor(role, _scale);
    final next = Map<String, double>.from(widget.profileMm);
    final key = '$_scale/${role.name}';
    if ((rounded - def).abs() < 1e-4) {
      next.remove(key);
    } else {
      next[key] = rounded;
    }
    widget.onChanged(next);
  }

  void _resetRole(ArchitectAnnotationRole role) {
    final next = Map<String, double>.from(widget.profileMm)
      ..remove('$_scale/${role.name}');
    widget.onChanged(next);
  }

  void _resetScale() {
    final prefix = '$_scale/';
    final next = Map<String, double>.from(widget.profileMm)
      ..removeWhere((k, _) => k.startsWith(prefix));
    widget.onChanged(next);
  }

  void _resetAll() => widget.onChanged(const {});

  Future<void> _editExact(ArchitectAnnotationRole role, String label) async {
    final controller = TextEditingController(
      text: _valueFor(role).toStringAsFixed(2),
    );
    await openArchitectNumericKeypad(
      context: context,
      controller: controller,
      title: '$label · 1:$_scale',
      unitLabel: 'mm',
      decimals: 2,
      min: 0.5,
      max: 20.0,
    );
    final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
    controller.dispose();
    if (parsed != null && parsed.isFinite && parsed > 0) {
      _setRole(role, parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final hasScaleCustom = _hasScaleOverride(_scale);
    final hasAnyCustom = widget.profileMm.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset in ArchitectDrawingScale.presets)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('architect-font-scale-$preset'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      _hasScaleOverride(preset) ? '1:$preset •' : '1:$preset',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _scale == preset,
                    onSelected: (_) => setState(() => _scale = preset),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final role in ArchitectAnnotationRole.editableRoles) ...[
          Builder(
            builder: (context) {
              final value = _valueFor(role);
              final custom = _isCustom(role);
              final roleLabel = architectAnnotationRoleLabel(l, role);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        roleLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: custom ? FontWeight.w600 : FontWeight.w400,
                          color: custom ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('architect-font-dec-$_scale-${role.name}'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: value <= 0.5
                          ? null
                          : () => _setRole(
                              role,
                              math.max(0.5, value - 0.1),
                            ),
                    ),
                    InkWell(
                      key: ValueKey('architect-font-val-$_scale-${role.name}'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _editExact(role, roleLabel),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: custom
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${value.toStringAsFixed(1)} mm',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('architect-font-inc-$_scale-${role.name}'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: value >= 20.0
                          ? null
                          : () => _setRole(
                              role,
                              math.min(20.0, value + 0.1),
                            ),
                    ),
                    SizedBox(
                      width: 28,
                      child: custom
                          ? IconButton(
                              key: ValueKey(
                                'architect-font-reset-$_scale-${role.name}',
                              ),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              tooltip: l.architectLayoutFontsResetScale,
                              icon: const Icon(Icons.undo),
                              onPressed: () => _resetRole(role),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        if (hasScaleCustom || hasAnyCustom) ...[
          const Divider(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              if (hasScaleCustom)
                TextButton(
                  onPressed: _resetScale,
                  child: Text(l.architectLayoutFontsResetScale),
                ),
              if (hasAnyCustom)
                TextButton(
                  onPressed: _resetAll,
                  child: Text(l.architectLayoutFontsResetAll),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Opens the standalone layout typography profile dialog (used from Layout).
Future<void> showArchitectTypographySettings(
  BuildContext context,
  ArchitectCommandController controller, {
  int initialScale = 100,
}) async {
  final l = context.l10n;
  var draft = Map<String, double>.from(controller.project.document.profileMm);
  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => architectAlertDialog(
        title: Text(l.architectLayoutFonts),
        content: SizedBox(
          width: (MediaQuery.sizeOf(c).width - 80).clamp(240.0, 420.0),
          child: SingleChildScrollView(
            child: ArchitectTypographyProfilePanel(
              profileMm: draft,
              initialScale: initialScale,
              onChanged: (next) => update(() => draft = next),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('architect-layout-fonts-save'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.save),
          ),
        ],
      ),
    ),
  );
  if (saved == true &&
      !mapEquals(draft, controller.project.document.profileMm)) {
    final doc = controller.project.document;
    controller.commit(
      controller.project.copyWith(
        document: doc.copyWith(profileMm: Map.unmodifiable(draft)),
      ),
    );
  }
}

Future<void> showArchitectAnnotationSettings(
  BuildContext context,
  ArchitectCommandController controller,
  ArchitectSavedDrawing drawing,
  int scale,
) async {
  final l = context.l10n;
  var role = ArchitectAnnotationRole.dimension;
  String? element;
  final scene = ArchitectDrawingPublisher.build(
    controller.project,
    drawing,
    scale,
    l,
  );
  final annotations = <String, String>{};
  for (final op in scene.operations.whereType<ArchitectVectorText>()) {
    if (op.sources.length == 1) annotations[op.sources.single] = op.text;
  }
  final input = TextEditingController();
  bool invalid = false;
  void load() => input.text = controller.project.document
      .textMm(drawing.sourceKey, element ?? '', role, scale)
      .toStringAsFixed(2);
  load();
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) {
        void save({bool reset = false}) {
          final value = double.tryParse(input.text.replaceAll(',', '.'));
          if (!reset && (value == null || !value.isFinite || value <= 0)) {
            update(() => invalid = true);
            return;
          }
          final doc = controller.project.document;
          final sizes = Map<String, double>.from(
            element == null ? doc.profileMm : doc.overrideMm,
          );
          final key = element == null
              ? '$scale/${role.name}'
              : '${drawing.sourceKey}/$element/${role.name}/$scale';
          if (reset) {
            sizes.remove(key);
          } else {
            sizes[key] = value!;
          }
          controller.commit(
            controller.project.copyWith(
              document: element == null
                  ? doc.copyWith(profileMm: sizes)
                  : doc.copyWith(overrideMm: sizes),
            ),
          );
          update(() {
            invalid = false;
            load();
          });
        }

        return architectAlertDialog(
          title: Text('${l.architectAnnotationSettings} · 1:$scale'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: element ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.architectAnnotationElement,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l.architectAnnotationProfile),
                      ),
                      for (final e in annotations.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      element = v == '' ? null : v;
                      load();
                    }),
                  ),
                  DropdownButtonFormField<ArchitectAnnotationRole>(
                    initialValue: role,
                    items: [
                      for (final value in ArchitectAnnotationRole.editableRoles)
                        DropdownMenuItem(
                          value: value,
                          child: Text(architectAnnotationRoleLabel(l, value)),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      role = v!;
                      load();
                    }),
                  ),
                  TextField(
                    controller: input,
                    keyboardType: TextInputType.none,
                    onTap: () => openArchitectNumericKeypad(
                      context: c,
                      controller: input,
                      title: l.architectAnnotationSize,
                      unitLabel: 'mm',
                      decimals: 2,
                      min: .000001,
                    ),
                    decoration: InputDecoration(
                      labelText: l.architectAnnotationSize,
                      errorText: invalid ? l.architectSheetInvalid : null,
                    ),
                  ),
                  TextButton(
                    onPressed: () => save(reset: true),
                    child: Text(l.architectAnnotationReset),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l.architectSheetCancel),
            ),
            FilledButton(
              onPressed: () => save(),
              child: Text(l.architectSheetSave),
            ),
          ],
        );
      },
    ),
  );
  input.dispose();
}
