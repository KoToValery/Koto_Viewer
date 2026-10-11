// === SECTION: ARCHITECTURAL PROJECT STARTER WIZARD ===
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_preset.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';

/// Touch-first starter wizard dialog for configuring and instantiating
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

  final ArchitectUnit _unit = ArchitectUnit.meters;
  int _storeyCount = 2;
  double _groundHeight = 3.00;
  double _typicalHeight = 2.80;

  ArchitectGridPreset _selectedGridPreset =
      ArchitectGridPreset.standardPresets().first;
  int _customAxesX = 4;
  int _customAxesY = 3;
  double _customSpacingX = 4.0;
  double _customSpacingY = 5.0;

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

  void _onCreate() {
    final defaultName = widget.initialProjectName?.isNotEmpty == true
        ? widget.initialProjectName!
        : context.l10n.architectDefaultProjectName;
    final name = _nameController.text.trim().isEmpty
        ? defaultName
        : _nameController.text.trim();

    final wallCatalog = ArchitectWallType.standardCatalog(
      parapetHeight: _computedParapetHeight,
      parapetFinish: _parapetFinish,
    ).where((w) => _enabledWallTypeIds.contains(w.id)).toList();

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
      wallTypes: wallCatalog,
      units: _unit,
    );

    Navigator.of(context).pop(project);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOver5 = _storeyCount >= 5;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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
                          l10n.architectWizardSubtitle,
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
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Project Name (Optional input)
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: l10n.bimProjectName,
                          hintText: l10n.architectDefaultProjectName,
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFF262632),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const SizedBox(height: 16),

                      // SECTION 1: STOREYS & HEIGHTS
                      _buildSectionHeader(
                        icon: Icons.layers_outlined,
                        title: l10n.architectWizardSectionStoreys,
                      ),
                      const SizedBox(height: 8),

                      // Storey Count (Touch-first chips)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final count in [1, 2, 3, 4, 5, 6, 8, 10])
                            ChoiceChip(
                              label: Text(l10n.architectStoreyCountChip(count)),
                              selected: _storeyCount == count,
                              onSelected: (_) =>
                                  setState(() => _storeyCount = count),
                              selectedColor:
                                  const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: _storeyCount == count
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white70,
                                fontWeight: _storeyCount == count
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Ground and Typical Heights
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.architectGroundHeight,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final h in [3.00, 3.20, 3.40])
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            label: Text(
                                              '${h.toStringAsFixed(2)} m',
                                            ),
                                            selected:
                                                (_groundHeight - h).abs() <
                                                1e-3,
                                            onSelected: (_) => setState(
                                              () => _groundHeight = h,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.architectStoreyHeight,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final h in [2.80, 2.90, 3.00])
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            label: Text(
                                              '${h.toStringAsFixed(2)} m',
                                            ),
                                            selected:
                                                (_typicalHeight - h).abs() <
                                                1e-3,
                                            onSelected: (_) => setState(
                                              () => _typicalHeight = h,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // SECTION 2: STRUCTURAL GRID (AXES)
                      _buildSectionHeader(
                        icon: Icons.grid_on_rounded,
                        title: l10n.architectWizardSectionGrid,
                      ),
                      const SizedBox(height: 8),

                      // Grid Preset Cards
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset
                              in ArchitectGridPreset.standardPresets())
                            ChoiceChip(
                              avatar: Icon(
                                preset.type == GridPresetType.none
                                    ? Icons.crop_portrait_rounded
                                    : Icons.grid_4x4_rounded,
                                size: 16,
                                color: _selectedGridPreset.id == preset.id
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white54,
                              ),
                              label: Text(preset.name),
                              selected: _selectedGridPreset.id == preset.id,
                              onSelected: (_) => setState(
                                () => _selectedGridPreset = preset,
                              ),
                              selectedColor:
                                  const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: _selectedGridPreset.id == preset.id
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white70,
                                fontWeight: _selectedGridPreset.id == preset.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Text(
                          _selectedGridPreset.description,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
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
                                    children: [
                                      for (final count in [2, 3, 4, 5, 6])
                                        ChoiceChip(
                                          label: Text('$count'),
                                          selected: _customAxesX == count,
                                          onSelected: (_) => setState(() => _customAxesX = count),
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
                                    children: [
                                      for (final count in [2, 3, 4, 5, 6])
                                        ChoiceChip(
                                          label: Text('$count'),
                                          selected: _customAxesY == count,
                                          onSelected: (_) => setState(() => _customAxesY = count),
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
                                    children: [
                                      for (final s in [3.0, 4.0, 5.0, 6.0])
                                        ChoiceChip(
                                          label: Text('${s.toInt()} m'),
                                          selected: (_customSpacingX - s).abs() < 1e-3,
                                          onSelected: (_) => setState(() => _customSpacingX = s),
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
                                    children: [
                                      for (final s in [3.0, 4.0, 5.0, 6.0])
                                        ChoiceChip(
                                          label: Text('${s.toInt()} m'),
                                          selected: (_customSpacingY - s).abs() < 1e-3,
                                          onSelected: (_) => setState(() => _customSpacingY = s),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // SECTION 3: WALL TYPES & PARAPETS
                      _buildSectionHeader(
                        icon: Icons.line_weight_rounded,
                        title: l10n.architectWizardSectionWalls,
                      ),
                      const SizedBox(height: 8),

                      // Wall types selection chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildWallTypeFilterChip(
                            id: 'ext_25_12_eps',
                            label: l10n.wallTypeExt25Eps12,
                            color: const Color(0xFFEF5350),
                          ),
                          _buildWallTypeFilterChip(
                            id: 'int_12_partition',
                            label: l10n.wallTypeInt12Partition,
                            color: const Color(0xFFFFA726),
                          ),
                          _buildWallTypeFilterChip(
                            id: 'ext_25_brick',
                            label: l10n.wallTypeExt25Brick,
                            color: const Color(0xFFFF7043),
                          ),
                          _buildWallTypeFilterChip(
                            id: 'bearing_25_concrete',
                            label: l10n.wallTypeBearing25,
                            color: const Color(0xFF78909C),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Balcony Parapet Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262632),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.balcony_rounded,
                                  color: Color(0xFF26A69A),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.architectWizardParapetTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF26A69A,
                                    ).withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.architectWizardParapetHeightInfo(
                                      _computedParapetHeight.toStringAsFixed(2),
                                      isOver5
                                          ? l10n.architectWizardParapetOver5
                                          : l10n.architectWizardParapetUnder5,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF80CBC4),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: Text(l10n.architectWizardParapetFinishCap),
                                  selected:
                                      _parapetFinish == ParapetFinish.cap,
                                  onSelected: (_) => setState(
                                    () => _parapetFinish = ParapetFinish.cap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(l10n.architectWizardParapetFinishPipe),
                                  selected:
                                      _parapetFinish ==
                                      ParapetFinish.handrailPipes,
                                  onSelected: (_) => setState(
                                    () => _parapetFinish =
                                        ParapetFinish.handrailPipes,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(
                      l10n.architectWizardCreateAction,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _onCreate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildWallTypeFilterChip({
    required String id,
    required String label,
    required Color color,
  }) {
    final isSelected = _enabledWallTypeIds.contains(id);
    return FilterChip(
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _enabledWallTypeIds.add(id);
          } else if (_enabledWallTypeIds.length > 1) {
            _enabledWallTypeIds.remove(id);
          }
        });
      },
      selectedColor: color.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white60,
        fontSize: 12,
      ),
    );
  }
}
