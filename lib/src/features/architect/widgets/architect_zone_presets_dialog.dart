import 'architect_dialog.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import 'architect_zone_preset_field.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_PRESETS_DIALOG ===
//    - ArchitectZonePresetsDialog (StatefulWidget)
//      * Modal dialog for redefining room types, default names and finishes
// =============================================================================

// === SECTION: ZONE_PRESETS_DIALOG ===

/// Lightweight and unobtrusive editor for configuring room categories,
/// default room names, and default finishes (floor, wall, ceiling).
class ArchitectZonePresetsDialog extends StatefulWidget {
  final ArchitectZonePresets presets;
  final ValueChanged<ArchitectZonePresets> onSave;
  final ArchitectZoneCategory? initialCategory;

  const ArchitectZonePresetsDialog({
    super.key,
    required this.presets,
    required this.onSave,
    this.initialCategory,
  });

  static Future<void> show({
    required BuildContext context,
    required ArchitectZonePresets presets,
    required ValueChanged<ArchitectZonePresets> onSave,
    ArchitectZoneCategory? initialCategory,
  }) => showDialog(
    context: context,
    builder: (ctx) => ArchitectZonePresetsDialog(
      presets: presets,
      onSave: onSave,
      initialCategory: initialCategory,
    ),
  );

  @override
  State<ArchitectZonePresetsDialog> createState() =>
      _ArchitectZonePresetsDialogState();
}

class _ArchitectZonePresetsDialogState
    extends State<ArchitectZonePresetsDialog> {
  late ArchitectZonePresets _currentPresets;
  late ArchitectZoneCategory _selectedCategory;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _wallController = TextEditingController();
  final TextEditingController _ceilingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPresets = widget.presets;
    _selectedCategory = widget.initialCategory ?? ArchitectZoneCategory.living;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategoryFields();
  }

  void _loadCategoryFields() {
    final l = context.l10n;
    _nameController.text = _currentPresets.categoryName(_selectedCategory, l);
    _floorController.text = _currentPresets.defaultFloorFinish(
      _selectedCategory,
      l,
    );
    _wallController.text = _currentPresets.defaultWallFinish(
      _selectedCategory,
      l,
    );
    _ceilingController.text = _currentPresets.defaultCeilingFinish(
      _selectedCategory,
      l,
    );
  }

  void _applyCurrentCategoryEdits() {
    final l = context.l10n;
    _currentPresets = _currentPresets.withCategoryDefaults(
      category: _selectedCategory,
      name: _nameController.text.trim(),
      floorFinish: _floorController.text.trim(),
      wallFinish: _wallController.text.trim(),
      ceilingFinish: _ceilingController.text.trim(),
      l10n: l,
    );
  }

  void _switchCategory(ArchitectZoneCategory cat) {
    if (cat == _selectedCategory) return;
    _applyCurrentCategoryEdits();
    setState(() {
      _selectedCategory = cat;
      _loadCategoryFields();
    });
  }

  void _resetSelectedCategory() {
    final l = context.l10n;
    setState(() {
      _currentPresets = _currentPresets.resetCategory(_selectedCategory);
      _loadCategoryFields();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedCategory.localizedName(l)}: ${l.architectZonePresetsResetCategory}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _currentPresets = _currentPresets.resetAll();
      _loadCategoryFields();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectZonePresetsResetAll),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _save() {
    _applyCurrentCategoryEdits();
    widget.onSave(_currentPresets);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    _wallController.dispose();
    _ceilingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 500;

    return architectAlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune_rounded, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.architectZonePresetsDialogTitle,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Tooltip(
            message: l.architectZonePresetsDialogSubtitle,
            child: Icon(
              Icons.help_outline,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in ArchitectZoneCategory.values) ...[
                      ChoiceChip(
                        selected: _selectedCategory == category,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 14,
                              color: _selectedCategory == category
                                  ? colors.onSecondaryContainer
                                  : category.color,
                            ),
                            const SizedBox(width: 4),
                            Text(category.localizedName(l)),
                          ],
                        ),
                        selectedColor: colors.secondaryContainer,
                        backgroundColor: colors.surfaceContainerHigh,
                        labelStyle: TextStyle(
                          color: _selectedCategory == category
                              ? colors.onSecondaryContainer
                              : colors.onSurface,
                          fontSize: 12,
                          fontWeight: _selectedCategory == category
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _switchCategory(category),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Active category badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _selectedCategory.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedCategory.color.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedCategory.icon,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedCategory.localizedName(l),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                      onPressed: _resetSelectedCategory,
                      icon: Icon(Icons.refresh_rounded, size: 14),
                      label: Text(
                        isCompact
                            ? l.commandUiReset
                            : l.architectZonePresetsResetCategory,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Default Name
              ArchitectZonePresetField(
                controller: _nameController,
                label: l.architectZoneName,
                presets: [
                  for (final cat in ArchitectZoneCategory.values)
                    cat.localizedName(l),
                ],
              ),

              const SizedBox(height: 10),

              // Default Floor Finish
              ArchitectZonePresetField(
                controller: _floorController,
                label: l.architectZoneFloorFinish,
                presets: _currentPresets.finishes('floor', l),
              ),

              const SizedBox(height: 10),

              // Default Wall Finish
              ArchitectZonePresetField(
                controller: _wallController,
                label: l.architectZoneWallFinish,
                presets: _currentPresets.finishes('wall', l),
              ),

              const SizedBox(height: 10),

              // Default Ceiling Finish
              ArchitectZonePresetField(
                controller: _ceilingController,
                label: l.architectZoneCeilingFinish,
                presets: _currentPresets.finishes('ceiling', l),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetAll,
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          child: Text(
            l.architectZonePresetsResetAll,
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
          ),
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
