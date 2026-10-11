// === SECTION: ARCHITECTURAL PROJECT STARTER WIZARD ===
// Table of Contents:
// 1. ArchitectProjectWizardDialog & State
// 2. Step 0: Units & Project Name (_buildStep0UnitsAndName)
// 3. Step 1: Storeys & Grid (_buildStep1StoreysAndGrid)
// 4. Step 2: Wall Types & Sizing (_buildStep2WallsAndSizing)
// 5. Wizard Helpers & UI Components (_buildWallConfigCard, _buildChoiceChip, _buildBottomBar)
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_preset.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';

/// Touch-first 3-step starter wizard dialog for configuring and instantiating
/// an architectural concept project without forced keyboard entry.
class ArchitectProjectWizardDialog extends StatefulWidget {
  final String? initialProjectName;

  const ArchitectProjectWizardDialog({super.key, this.initialProjectName});

  static Future<ArchitectProject?> show(
    BuildContext context, {
    String? initialProjectName,
  }) {
    return showDialog<ArchitectProject>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          ArchitectProjectWizardDialog(initialProjectName: initialProjectName),
    );
  }

  @override
  State<ArchitectProjectWizardDialog> createState() =>
      _ArchitectProjectWizardDialogState();
}

class _ArchitectProjectWizardDialogState
    extends State<ArchitectProjectWizardDialog> {
  late final TextEditingController _nameController;

  int _currentStep = 0;
  ArchitectUnit _unit = ArchitectUnit.meters;

  // Step 1: Storey Count & Heights
  int _storeyCount = 2;
  double _groundHeight = 3.00;
  double _typicalHeight = 2.80;

  // Step 1: Structural Grid
  ArchitectGridPreset _selectedGridPreset =
      ArchitectGridPreset.standardPresets().first;
  int _customAxesX = 4;
  int _customAxesY = 3;
  double _customSpacingX = 4.0;
  double _customSpacingY = 5.0;

  // Step 2: Parametric Wall Thicknesses (in meters)
  double _extBrickThickness = 0.25;
  double _extInsulationThickness = 0.12;
  double _partitionThickness = 0.12;
  double _brickThickness = 0.25;
  double _bearingThickness = 0.25;
  double _parapetThickness = 0.12;
  late double _parapetHeight;
  ParapetFinish _parapetFinish = ParapetFinish.cap;

  final Set<String> _enabledWallTypeIds = {
    'ext_25_12_eps',
    'int_12_partition',
    'ext_25_brick',
    'bearing_25_concrete',
    'parapet_12',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProjectName ?? '',
    );
    _parapetHeight = _computedParapetHeight;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _computedParapetHeight {
    final totalElevation = _groundHeight + (_storeyCount - 1) * _typicalHeight;
    return ArchitectWallType.resolveParapetHeight(
      storeyElevation: totalElevation,
      storeyIndex: _storeyCount,
    );
  }

  void _onStoreyCountChanged(int count) {
    setState(() {
      _storeyCount = count;
      _parapetHeight = _computedParapetHeight;
    });
  }

  void _onCreate() {
    final l10n = context.l10n;
    final defaultName = widget.initialProjectName?.isNotEmpty == true
        ? widget.initialProjectName!
        : l10n.architectDefaultProjectName;
    final name = _nameController.text.trim().isEmpty
        ? defaultName
        : _nameController.text.trim();

    final wallCatalog = <ArchitectWallType>[];

    if (_enabledWallTypeIds.contains('ext_25_12_eps')) {
      final total = _extBrickThickness + _extInsulationThickness;
      final baseTitle = l10n.wallTypeExt25Eps12.split('(').first.trim();
      wallCatalog.add(ArchitectWallType(
        id: 'ext_25_12_eps',
        name: '$baseTitle (${_unit.format(total)})',
        usage: WallUsage.exterior,
        totalThickness: total,
        brickThickness: _extBrickThickness,
        insulationThickness: _extInsulationThickness,
        colorValue: 0xFFEF5350,
      ));
    }

    if (_enabledWallTypeIds.contains('int_12_partition')) {
      final baseTitle = l10n.wallTypeInt12Partition.split(' ').first.trim();
      wallCatalog.add(ArchitectWallType(
        id: 'int_12_partition',
        name: '$baseTitle ${_unit.format(_partitionThickness)}',
        usage: WallUsage.interior,
        totalThickness: _partitionThickness,
        brickThickness: _partitionThickness,
        insulationThickness: 0.0,
        colorValue: 0xFFFFA726,
      ));
    }

    if (_enabledWallTypeIds.contains('ext_25_brick')) {
      final baseTitle = l10n.wallTypeExt25Brick.split('(').first.trim();
      wallCatalog.add(ArchitectWallType(
        id: 'ext_25_brick',
        name: '$baseTitle (${_unit.format(_brickThickness)})',
        usage: WallUsage.exterior,
        totalThickness: _brickThickness,
        brickThickness: _brickThickness,
        insulationThickness: 0.0,
        colorValue: 0xFFFF7043,
      ));
    }

    if (_enabledWallTypeIds.contains('bearing_25_concrete')) {
      final baseTitle = l10n.wallTypeBearing25.replaceAll('25 cm', '').trim();
      wallCatalog.add(ArchitectWallType(
        id: 'bearing_25_concrete',
        name: '$baseTitle ${_unit.format(_bearingThickness)}',
        usage: WallUsage.bearing,
        totalThickness: _bearingThickness,
        brickThickness: _bearingThickness,
        insulationThickness: 0.0,
        colorValue: 0xFF78909C,
      ));
    }

    if (_enabledWallTypeIds.contains('parapet_12')) {
      final baseTitle = l10n.wallTypeParapet12.replaceAll('12 cm', '').trim();
      wallCatalog.add(ArchitectWallType(
        id: 'parapet_12',
        name: '$baseTitle ${_unit.format(_parapetThickness)} (h=${_unit.format(_parapetHeight)})',
        usage: WallUsage.parapet,
        totalThickness: _parapetThickness,
        brickThickness: _parapetThickness,
        insulationThickness: 0.0,
        customHeight: _parapetHeight,
        parapetFinish: _parapetFinish,
        colorValue: 0xFF26A69A,
      ));
    }

    final project = ArchitectProject.starterWithCatalog(
      name: name,
      storeyCount: _storeyCount,
      groundHeight: _groundHeight,
      typicalHeight: _typicalHeight,
      gridPreset: _selectedGridPreset,
      customAxesX: _customAxesX,
      customAxesY: _customAxesY,
      customSpacingX: _customSpacingX,
      customSpacingY: _customSpacingY,
      wallTypes: wallCatalog.isNotEmpty
          ? wallCatalog
          : ArchitectWallType.standardCatalog(
              parapetHeight: _parapetHeight,
              parapetFinish: _parapetFinish,
            ),
      units: _unit,
    );

    Navigator.of(context).pop(project);
  }

  String _getStepSubtitle(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return l10n.architectWizardStep1Subtitle;
      case 1:
        return l10n.architectWizardStep2Subtitle;
      case 2:
        return l10n.architectWizardStep3Subtitle;
      default:
        return l10n.architectWizardSubtitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF1E1E26),
            primary: Color(0xFF00E5FF),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF262632),
            selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
            disabledColor: const Color(0xFF1E1E24),
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
            secondaryLabelStyle: const TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            checkmarkColor: const Color(0xFF00E5FF),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 730),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.architecture_rounded,
                        color: Color(0xFF00E5FF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.architectWizardTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getStepSubtitle(l10n),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Top Step Navigation Bar
                _buildStepIndicator(l10n),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),

                // Active Step Scrollable View
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildCurrentStepContent(l10n),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),

                // Bottom Action Bar
                _buildBottomBar(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    final steps = [
      (0, l10n.architectWizardStep1, Icons.straighten_rounded),
      (1, l10n.architectWizardStep2, Icons.grid_on_rounded),
      (2, l10n.architectWizardStep3, Icons.line_weight_rounded),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 8,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: i <= _currentStep
                  ? const Color(0xFF00E5FF)
                  : Colors.white12,
            ),
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentStep = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: _currentStep == i
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                      : const Color(0xFF262632),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentStep == i
                        ? const Color(0xFF00E5FF)
                        : (i < _currentStep
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                            : Colors.white12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      steps[i].$3,
                      size: 13,
                      color: _currentStep == i
                          ? const Color(0xFF00E5FF)
                          : (i < _currentStep
                              ? const Color(0xFF00E5FF)
                              : Colors.white54),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        steps[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _currentStep == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _currentStep == i
                              ? const Color(0xFF00E5FF)
                              : (i < _currentStep ? Colors.white : Colors.white60),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentStepContent(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildStep0UnitsAndName(l10n);
      case 1:
        return _buildStep1StoreysAndGrid(l10n);
      case 2:
      default:
        return _buildStep2WallsAndSizing(l10n);
    }
  }

  // === SECTION: STEP 0 - UNITS & PROJECT NAME ===
  Widget _buildStep0UnitsAndName(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Project Name
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: l10n.bimProjectName,
            hintText: l10n.architectDefaultProjectName,
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            filled: true,
            fillColor: const Color(0xFF262632),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white12),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Dimensions System Choice
        _buildSectionHeader(
          icon: Icons.language_rounded,
          title: l10n.architectUnitSystem,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildChoiceChip(
              avatar: const Icon(Icons.architecture_rounded, size: 16),
              label: l10n.architectUnitSystemMetric,
              selected: _unit.isMetric,
              onSelected: () {
                if (_unit.isImperial) {
                  setState(() => _unit = ArchitectUnit.meters);
                }
              },
            ),
            _buildChoiceChip(
              avatar: const Icon(Icons.straighten_rounded, size: 16),
              label: l10n.architectUnitSystemImperial,
              selected: _unit.isImperial,
              onSelected: () {
                if (_unit.isMetric) {
                  setState(() => _unit = ArchitectUnit.feet);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Specific Measurement Unit Choice
        _buildSectionHeader(
          icon: Icons.straighten_rounded,
          title: l10n.architectUnits,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (_unit.isMetric) ...[
              _buildChoiceChip(
                label: l10n.architectUnitMeters,
                selected: _unit == ArchitectUnit.meters,
                onSelected: () =>
                    setState(() => _unit = ArchitectUnit.meters),
              ),
              _buildChoiceChip(
                label: l10n.architectUnitCm,
                selected: _unit == ArchitectUnit.centimeters,
                onSelected: () =>
                    setState(() => _unit = ArchitectUnit.centimeters),
              ),
              _buildChoiceChip(
                label: l10n.architectUnitMm,
                selected: _unit == ArchitectUnit.millimeters,
                onSelected: () =>
                    setState(() => _unit = ArchitectUnit.millimeters),
              ),
            ] else ...[
              _buildChoiceChip(
                label: l10n.architectUnitFeet,
                selected: _unit == ArchitectUnit.feet,
                onSelected: () =>
                    setState(() => _unit = ArchitectUnit.feet),
              ),
              _buildChoiceChip(
                label: l10n.architectUnitInches,
                selected: _unit == ArchitectUnit.inches,
                onSelected: () =>
                    setState(() => _unit = ArchitectUnit.inches),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Preview Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF262632),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1.00 m = ${_unit.format(1.0)} | 0.25 m = ${_unit.format(0.25)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === SECTION: STEP 1 - STOREYS & STRUCTURAL GRID ===
  Widget _buildStep1StoreysAndGrid(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Storeys & Heights
        _buildSectionHeader(
          icon: Icons.layers_outlined,
          title: l10n.architectWizardSectionStoreys,
        ),
        const SizedBox(height: 8),

        // Storey Count (Touch chips)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final count in [1, 2, 3, 4, 5, 6, 8, 10])
              _buildChoiceChip(
                label: l10n.architectStoreyCountChip(count),
                selected: _storeyCount == count,
                onSelected: () => _onStoreyCountChanged(count),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Ground Height
        Text(
          l10n.architectGroundHeight,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final h in [3.00, 3.20, 3.40])
              _buildChoiceChip(
                label: _unit.format(h),
                selected: (_groundHeight - h).abs() < 1e-3,
                onSelected: () => setState(() => _groundHeight = h),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Typical Height
        Text(
          l10n.architectStoreyHeight,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final h in [2.80, 2.90, 3.00])
              _buildChoiceChip(
                label: _unit.format(h),
                selected: (_typicalHeight - h).abs() < 1e-3,
                onSelected: () => setState(() => _typicalHeight = h),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // Structural Grid Presets
        _buildSectionHeader(
          icon: Icons.grid_on_rounded,
          title: l10n.architectWizardSectionGrid,
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final preset in ArchitectGridPreset.standardPresets())
              _buildChoiceChip(
                avatar: Icon(
                  preset.type == GridPresetType.none
                      ? Icons.crop_portrait_rounded
                      : Icons.grid_4x4_rounded,
                  size: 16,
                  color: _selectedGridPreset.id == preset.id
                      ? const Color(0xFF00E5FF)
                      : Colors.white54,
                ),
                label: preset.name,
                selected: _selectedGridPreset.id == preset.id,
                onSelected: () => setState(() => _selectedGridPreset = preset),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            _selectedGridPreset.description,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),

        // Custom Grid Configuration
        if (_selectedGridPreset.type == GridPresetType.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.architectGridAxesX,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final count in [2, 3, 4, 5, 6])
                          _buildChoiceChip(
                            label: '$count',
                            selected: _customAxesX == count,
                            onSelected: () => setState(() => _customAxesX = count),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.architectGridAxesY,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final count in [2, 3, 4, 5, 6])
                          _buildChoiceChip(
                            label: '$count',
                            selected: _customAxesY == count,
                            onSelected: () => setState(() => _customAxesY = count),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.architectGridSpacingX,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final s in [3.0, 4.0, 5.0, 6.0])
                          _buildChoiceChip(
                            label: _unit.format(s, decimals: 0),
                            selected: (_customSpacingX - s).abs() < 1e-3,
                            onSelected: () => setState(() => _customSpacingX = s),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.architectGridSpacingY,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final s in [3.0, 4.0, 5.0, 6.0])
                          _buildChoiceChip(
                            label: _unit.format(s, decimals: 0),
                            selected: (_customSpacingY - s).abs() < 1e-3,
                            onSelected: () => setState(() => _customSpacingY = s),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // === SECTION: STEP 2 - WALL TYPES & SIZING ===
  Widget _buildStep2WallsAndSizing(AppLocalizations l10n) {
    final isOver5 = _storeyCount >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.line_weight_rounded,
          title: l10n.architectWizardSectionWalls,
        ),
        const SizedBox(height: 10),

        // 1. Exterior 25+12 EPS Wall
        _buildWallConfigCard(
          id: 'ext_25_12_eps',
          title: l10n.wallTypeExt25Eps12,
          color: const Color(0xFFEF5350),
          badge: _buildPillBadge(
            l10n.architectWallTotalThickness(
              _unit.format(_extBrickThickness + _extInsulationThickness),
            ),
            const Color(0xFFEF5350),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.architectWallCore,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in [0.20, 0.25, 0.30, 0.38])
                    _buildChoiceChip(
                      label: _unit.format(w),
                      selected: (_extBrickThickness - w).abs() < 1e-3,
                      onSelected: () => setState(() => _extBrickThickness = w),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.architectWallInsulation,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final ins in [0.08, 0.10, 0.12, 0.15, 0.20])
                    _buildChoiceChip(
                      label: _unit.format(ins),
                      selected: (_extInsulationThickness - ins).abs() < 1e-3,
                      onSelected: () =>
                          setState(() => _extInsulationThickness = ins),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 2. Interior 12 cm Partition Wall
        _buildWallConfigCard(
          id: 'int_12_partition',
          title: l10n.wallTypeInt12Partition,
          color: const Color(0xFFFFA726),
          badge: _buildPillBadge(
            _unit.format(_partitionThickness),
            const Color(0xFFFFA726),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.architectWallCore,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in [0.08, 0.10, 0.12, 0.15])
                    _buildChoiceChip(
                      label: _unit.format(w),
                      selected: (_partitionThickness - w).abs() < 1e-3,
                      onSelected: () => setState(() => _partitionThickness = w),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 3. Exterior 25 cm Brick Wall (uninsulated)
        _buildWallConfigCard(
          id: 'ext_25_brick',
          title: l10n.wallTypeExt25Brick,
          color: const Color(0xFFFF7043),
          badge: _buildPillBadge(
            _unit.format(_brickThickness),
            const Color(0xFFFF7043),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.architectWallCore,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in [0.12, 0.20, 0.25, 0.38])
                    _buildChoiceChip(
                      label: _unit.format(w),
                      selected: (_brickThickness - w).abs() < 1e-3,
                      onSelected: () => setState(() => _brickThickness = w),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 4. Concrete Shear Wall 25 cm
        _buildWallConfigCard(
          id: 'bearing_25_concrete',
          title: l10n.wallTypeBearing25,
          color: const Color(0xFF78909C),
          badge: _buildPillBadge(
            _unit.format(_bearingThickness),
            const Color(0xFF78909C),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.architectWallCore,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in [0.15, 0.20, 0.25, 0.30])
                    _buildChoiceChip(
                      label: _unit.format(w),
                      selected: (_bearingThickness - w).abs() < 1e-3,
                      onSelected: () => setState(() => _bearingThickness = w),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 5. Balcony Parapet Wall
        _buildWallConfigCard(
          id: 'parapet_12',
          title: l10n.architectWizardParapetTitle,
          color: const Color(0xFF26A69A),
          badge: _buildPillBadge(
            l10n.architectWizardParapetHeightInfo(
              _unit.format(_parapetHeight),
              isOver5
                  ? l10n.architectWizardParapetOver5
                  : l10n.architectWizardParapetUnder5,
            ),
            const Color(0xFF26A69A),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.architectParapetCurb,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in [0.10, 0.12, 0.15, 0.20])
                    _buildChoiceChip(
                      label: _unit.format(w),
                      selected: (_parapetThickness - w).abs() < 1e-3,
                      onSelected: () => setState(() => _parapetThickness = w),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.architectParapetHeightLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final h in [1.00, 1.05, 1.10, 1.20])
                    _buildChoiceChip(
                      label: _unit.format(h),
                      selected: (_parapetHeight - h).abs() < 1e-3,
                      onSelected: () => setState(() => _parapetHeight = h),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildChoiceChip(
                    label: l10n.architectWizardParapetFinishCap,
                    selected: _parapetFinish == ParapetFinish.cap,
                    onSelected: () => setState(
                      () => _parapetFinish = ParapetFinish.cap,
                    ),
                  ),
                  _buildChoiceChip(
                    label: l10n.architectWizardParapetFinishPipe,
                    selected: _parapetFinish == ParapetFinish.handrailPipes,
                    onSelected: () => setState(
                      () => _parapetFinish = ParapetFinish.handrailPipes,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === SECTION: WIZARD HELPERS & UI COMPONENTS ===
  Widget _buildWallConfigCard({
    required String id,
    required String title,
    required Color color,
    required Widget badge,
    required Widget content,
  }) {
    final isEnabled = _enabledWallTypeIds.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262632),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled ? color.withValues(alpha: 0.35) : Colors.white10,
          width: isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: badge),
              const SizedBox(width: 4),
              Checkbox(
                value: isEnabled,
                activeColor: color,
                checkColor: Colors.black,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    if (val) {
                      _enabledWallTypeIds.add(id);
                    } else if (_enabledWallTypeIds.length > 1) {
                      _enabledWallTypeIds.remove(id);
                    }
                  });
                },
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            content,
          ],
        ],
      ),
    );
  }

  Widget _buildPillBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Row(
      children: [
        if (_currentStep == 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
            ),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(l10n.architectWizardBack),
            onPressed: () => setState(() => _currentStep--),
          ),
        const Spacer(),
        if (_currentStep < 2)
          Flexible(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.architectWizardNext,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              onPressed: () => setState(() => _currentStep++),
            ),
          )
        else
          Flexible(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.architectWizardCreateAction,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              onPressed: _onCreate,
            ),
          ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Widget? avatar,
  }) {
    return ChoiceChip(
      avatar: avatar,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: const Color(0xFF262632),
      selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
      side: BorderSide(
        color: selected
            ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
            : Colors.white12,
      ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF00E5FF) : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      checkmarkColor: const Color(0xFF00E5FF),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
