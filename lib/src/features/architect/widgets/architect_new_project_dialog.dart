import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';

/// Modal Wizard Dialog for creating a new architectural concept design project.
class ArchitectNewProjectDialog extends StatefulWidget {
  const ArchitectNewProjectDialog({super.key});

  @override
  State<ArchitectNewProjectDialog> createState() =>
      _ArchitectNewProjectDialogState();
}

class _ArchitectNewProjectDialogState extends State<ArchitectNewProjectDialog> {
  late final TextEditingController _nameController;
  ArchitectUnit _unit = ArchitectUnit.meters;
  int _storeyCount = 2;
  double _groundHeight = 3.00;
  double _typicalHeight = 2.80;

  bool _enableGridAxes = true;
  int _axesX = 4;
  int _axesY = 3;
  double _spacingX = 4.0;
  double _spacingY = 5.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameController.text.isEmpty) {
      _nameController.text = '${context.l10n.architectDefaultProjectName} 1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onCreate() {
    final name = _nameController.text.trim().isEmpty
        ? '${context.l10n.architectDefaultProjectName} 1'
        : _nameController.text.trim();


    final project = ArchitectProject.starter(
      name: name,
      storeyCount: _storeyCount,
      groundHeight: _groundHeight,
      typicalHeight: _typicalHeight,
      axesX: _enableGridAxes ? _axesX : 0,
      axesY: _enableGridAxes ? _axesY : 0,
      spacingX: _spacingX,
      spacingY: _spacingY,
    ).copyWith(units: _unit);

    Navigator.of(context).pop(project);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(

      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
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
                          l10n.architectNewProject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.architectStudioSubtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white10),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Project Name
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.architectProjectName,
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: l10n.architectProjectNameHint,
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF262630),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Units
                      Text(
                        l10n.architectUnits,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<ArchitectUnit>(
                        segments: [
                          ButtonSegment(
                            value: ArchitectUnit.meters,
                            label: Text(l10n.architectUnitMeters),
                          ),
                          ButtonSegment(
                            value: ArchitectUnit.centimeters,
                            label: Text(l10n.architectUnitCm),
                          ),
                        ],
                        selected: {_unit},
                        onSelectionChanged: (set) =>
                            setState(() => _unit = set.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                                : const Color(0xFF262630),
                          ),
                          foregroundColor: WidgetStateProperty.all(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Storeys Section
                      Text(
                        l10n.architectStoreys,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberCounter(
                              label: l10n.architectStoreyCount,
                              value: _storeyCount,
                              min: 1,
                              max: 10,
                              onChanged: (v) => setState(() => _storeyCount = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDoubleInput(
                              label: l10n.architectGroundHeight,
                              value: _groundHeight,
                              step: 0.10,
                              onChanged: (v) => setState(() => _groundHeight = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDoubleInput(
                              label: l10n.architectStoreyHeight,
                              value: _typicalHeight,
                              step: 0.10,
                              onChanged: (v) => setState(() => _typicalHeight = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Dynamic Grid Axes Option
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.architectDynamicGridAxes,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        activeThumbColor: const Color(0xFF00E5FF),
                        value: _enableGridAxes,

                        onChanged: (v) => setState(() => _enableGridAxes = v),
                      ),
                      if (_enableGridAxes) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildNumberCounter(
                                label: l10n.architectGridAxesX,
                                value: _axesX,
                                min: 2,
                                max: 12,
                                onChanged: (v) => setState(() => _axesX = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildNumberCounter(
                                label: l10n.architectGridAxesY,
                                value: _axesY,
                                min: 2,
                                max: 12,
                                onChanged: (v) => setState(() => _axesY = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDoubleInput(
                                label: l10n.architectGridSpacingX,
                                value: _spacingX,
                                step: 0.50,
                                onChanged: (v) => setState(() => _spacingX = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDoubleInput(
                                label: l10n.architectGridSpacingY,
                                value: _spacingY,
                                step: 0.50,
                                onChanged: (v) => setState(() => _spacingY = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _onCreate,
                    child: Text(
                      l10n.architectCreateProject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCounter({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262630),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                onPressed: value > min ? () => onChanged(value - 1) : null,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                onPressed: value < max ? () => onChanged(value + 1) : null,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleInput({
    required String label,
    required double value,
    required double step,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262630),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                onPressed: value > step
                    ? () => onChanged((value - step).clamp(0.5, 20.0))
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${value.toStringAsFixed(2)} m',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                onPressed: () =>
                    onChanged((value + step).clamp(0.5, 20.0)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
