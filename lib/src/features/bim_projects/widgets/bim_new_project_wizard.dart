import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/bim_work_project.dart';
import '../services/bim_project_library_service.dart';
import '../services/bim_underlay_picker_helper.dart';

class _StoreyDraft {
  String storeyId;
  String name;
  double elevation;
  double height;
  File? pickedFile;

  _StoreyDraft({
    required this.storeyId,
    required this.name,
    required this.elevation,
    this.height = 2.80,
  });
}

/// Modal / screen wizard for configuring and creating a new standalone BiM Project.
class BimNewProjectWizard extends StatefulWidget {
  final VoidCallback? onProjectCreated;
  final ValueChanged<BimWorkProject>? onProjectCreatedWithProject;

  const BimNewProjectWizard({
    super.key,
    this.onProjectCreated,
    this.onProjectCreatedWithProject,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onProjectCreated,
    ValueChanged<BimWorkProject>? onProjectCreatedWithProject,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BimNewProjectWizard(
        onProjectCreated: onProjectCreated,
        onProjectCreatedWithProject: onProjectCreatedWithProject,
      ),
    );
  }

  @override
  State<BimNewProjectWizard> createState() => _BimNewProjectWizardState();
}

class _BimNewProjectWizardState extends State<BimNewProjectWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  int _basementCount = 0;
  int _aboveGroundCount = 3;
  final double _floorHeight = 2.80;
  bool _isCreating = false;

  final List<_StoreyDraft> _storeys = [];

  @override
  void initState() {
    super.initState();
    _generateDefaultStoreys();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _generateDefaultStoreys() {
    _storeys.clear();
    int idx = 1;

    // 1. Basements (from bottom-most up to -floorHeight)
    for (int b = _basementCount; b >= 1; b--) {
      final elev = -b * _floorHeight;
      _storeys.add(
        _StoreyDraft(
          storeyId: 'storey_$idx',
          name: 'Basement $b', // will be localized in UI
          elevation: elev,
          height: _floorHeight,
        ),
      );
      idx++;
    }

    // 2. Ground floor (0.00)
    _storeys.add(
      _StoreyDraft(
        storeyId: 'storey_$idx',
        name: 'Ground Floor',
        elevation: 0.0,
        height: _floorHeight,
      ),
    );
    idx++;

    // 3. Above-ground floors (from +1 to aboveGroundCount - 1)
    for (int f = 1; f < _aboveGroundCount; f++) {
      final elev = f * _floorHeight;
      _storeys.add(
        _StoreyDraft(
          storeyId: 'storey_$idx',
          name: 'Floor $f',
          elevation: elev,
          height: _floorHeight,
        ),
      );
      idx++;
    }
  }

  String _getStoreyDisplayName(_StoreyDraft draft, int index) {
    if (draft.elevation < -0.01) {
      final bNum = (-draft.elevation / draft.height).round();
      return '${context.l10n.bimProjectBasement(bNum)} (${draft.elevation.toStringAsFixed(2)} m)';
    } else if (draft.elevation.abs() <= 0.01) {
      return '${context.l10n.bimProjectGroundFloor} (±0.00 m)';
    } else {
      final fNum = (draft.elevation / draft.height).round();
      return '${context.l10n.bimProjectFloor(fNum)} (+${draft.elevation.toStringAsFixed(2)} m)';
    }
  }

  Future<void> _pickUnderlayForStorey(_StoreyDraft draft) async {
    final file = await BimUnderlayPickerHelper.pickCadUnderlayFile(context);
    if (file != null) {
      setState(() {
        draft.pickedFile = file;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_storeys.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final storeyUnderlays = _storeys.asMap().entries.map((entry) {
        final d = entry.value;
        return BimStoreyUnderlay(
          storeyId: d.storeyId,
          name: _getStoreyDisplayName(d, entry.key),
          elevation: d.elevation,
          height: d.height,
        );
      }).toList();

      final project = await BimProjectLibraryService.instance.createProject(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        storeys: storeyUnderlays,
      );

      // Attach any picked underlays
      for (final draft in _storeys) {
        if (draft.pickedFile != null) {
          await BimProjectLibraryService.instance.attachUnderlayFile(
            project.id,
            draft.storeyId,
            draft.pickedFile!,
          );
        }
      }

      final latestProject = await BimProjectLibraryService.instance.loadProject(project.id) ?? project;

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onProjectCreatedWithProject != null) {
          widget.onProjectCreatedWithProject!(latestProject);
        } else {
          widget.onProjectCreated?.call();
        }
      }
    } catch (e) {
      debugPrint('Error creating project: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.apartment_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.bimProjectNew,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content Body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Project Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.bimProjectName,
                        hintText: l10n.bimProjectNameHint,
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.bimProjectName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Location / City
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: l10n.bimProjectLocation,
                        hintText: l10n.bimProjectLocationHint,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Storey Setup Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.bimProjectQuickSetup,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCounterField(
                                  label: l10n.bimProjectBasementCount,
                                  value: _basementCount,
                                  onChanged: (val) => setState(() => _basementCount = val.clamp(0, 5)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCounterField(
                                  label: l10n.bimProjectAboveGroundCount,
                                  value: _aboveGroundCount,
                                  onChanged: (val) => setState(() => _aboveGroundCount = val.clamp(1, 20)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: Text(l10n.bimProjectGenerateStoreys),
                                onPressed: () {
                                  setState(() => _generateDefaultStoreys());
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Storeys & Underlays Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.bimProjectStoreysSection,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.bimProjectAddStorey),
                          onPressed: () {
                            setState(() {
                              final lastElev = _storeys.isNotEmpty ? _storeys.last.elevation : 0.0;
                              final newElev = lastElev + _floorHeight;
                              final nextIdx = _storeys.length + 1;
                              _storeys.add(
                                _StoreyDraft(
                                  storeyId: 'storey_$nextIdx',
                                  name: 'Floor $nextIdx',
                                  elevation: newElev,
                                  height: _floorHeight,
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Storey Cards List
                    ..._storeys.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final draft = entry.value;
                      final displayName = _getStoreyDisplayName(draft, idx);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: draft.elevation < 0
                                        ? const Color(0xFF5C6BC0)
                                        : const Color(0xFF00E5FF).withValues(alpha: 0.8),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          '${l10n.bimProjectElevation}: ${draft.elevation >= 0 ? "+" : ""}${draft.elevation.toStringAsFixed(2)} m',
                                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_storeys.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      tooltip: l10n.bimProjectDeleteStorey,
                                      onPressed: () {
                                        setState(() => _storeys.removeAt(idx));
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Underlay Attachment Button
                              Row(
                                children: [
                                  Expanded(
                                    child: draft.pickedFile != null
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E676).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF00E676)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    draft.pickedFile!.path.split(Platform.pathSeparator).last,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Text(
                                            l10n.bimProjectNoUnderlay,
                                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                                    label: Text(
                                      draft.pickedFile != null
                                          ? l10n.bimProjectReplaceUnderlay
                                          : l10n.bimProjectAddUnderlay,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _pickUnderlayForStorey(draft),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Bottom Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isCreating ? l10n.bimProjectSaving : l10n.bimProjectCreateButton,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isCreating ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounterField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => onChanged(value - 1),
            ),
            Expanded(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}
