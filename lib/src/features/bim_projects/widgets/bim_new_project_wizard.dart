import 'dart:async';
import '../services/bim_underlay_conversion_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/bim_work_project.dart';
import '../services/bim_project_library_service.dart';
import '../services/bim_underlay_picker_helper.dart';
import 'bim_elevation_dialog.dart';

class _StoreyDraft {
  String storeyId;
  String name;
  double elevation;
  double height;
  File? pickedFile;
  int request = 0;
  Future<void>? pending;
  BimConversionResult? converted;
  BimConversionStage? stage;
  Object? error;

  _StoreyDraft({
    required this.storeyId,
    required this.name,
    required this.elevation,
    this.height = 2.80,
  });

  String get elevationLabel => BimStoreyUnderlay.formatElevation(elevation);
}

/// Modal / screen wizard for configuring and creating a new standalone BiM Project.
class BimNewProjectWizard extends StatefulWidget {
  final Future<File?> Function(BuildContext)? underlayPicker;
  final Future<BimConversionResult> Function(
    File,
    void Function(BimConversionStage),
    bool Function(),
  )?
  underlayConverter;
  final VoidCallback? onProjectCreated;
  final ValueChanged<BimWorkProject>? onProjectCreatedWithProject;

  const BimNewProjectWizard({
    super.key,
    this.onProjectCreated,
    this.underlayPicker,
    this.underlayConverter,
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

  final double _floorHeight = 2.80;
  bool _isCreating = false;
  int _nextStoreyId = 0;

  final List<_StoreyDraft> _storeys = [];

  @override
  void initState() {
    super.initState();
    _generateDefaultStoreys();
  }

  @override
  void dispose() {
    for (final draft in _storeys) {
      _release(draft);
    }
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _release(_StoreyDraft draft) {
    draft.request++;
    final result = draft.converted;
    draft.converted = null;
    if (result != null) unawaited(result.dispose());
  }

  void _generateDefaultStoreys() {
    for (final draft in _storeys) {
      _release(draft);
    }
    _storeys.clear();

    _storeys.add(
      _StoreyDraft(
        storeyId: 'storey_${++_nextStoreyId}',
        name: '±0.00',
        elevation: 0,
      ),
    );
  }

  bool get _canCreate =>
      !_isCreating &&
      _storeys.isNotEmpty &&
      _storeys.every(
        (d) =>
            d.converted != null &&
            d.error == null &&
            d.stage == BimConversionStage.ready,
      );

  String _getStoreyDisplayName(_StoreyDraft draft, int index) {
    return draft.elevationLabel;
  }

  Future<void> _editElevation(_StoreyDraft? draft) async {
    var suggested = 0.0;
    if (_storeys.isNotEmpty) {
      suggested =
          _storeys.map((s) => s.elevation).reduce((a, b) => a > b ? a : b) +
          _floorHeight;
    }
    final elevation = await showBimElevationDialog(
      context: context,
      initialElevation: draft?.elevation ?? suggested,
      occupiedElevations: _storeys
          .where((s) => s != draft)
          .map((s) => s.elevation),
    );
    if (!mounted || elevation == null || _isCreating) return;
    setState(() {
      if (draft != null) {
        draft.elevation = elevation;
        draft.name = draft.elevationLabel;
      } else {
        _storeys.add(
          _StoreyDraft(
            storeyId: 'storey_${++_nextStoreyId}',
            name: BimStoreyUnderlay.formatElevation(elevation),
            elevation: elevation,
            height: _floorHeight,
          ),
        );
      }
      _storeys.sort((a, b) => a.elevation.compareTo(b.elevation));
    });
  }

  Future<void> _pickUnderlayForStorey(_StoreyDraft draft) async {
    final file =
        await (widget.underlayPicker ??
            BimUnderlayPickerHelper.pickCadUnderlayFile)(context);
    if (mounted && file != null && !_isCreating && _storeys.contains(draft)) {
      setState(() {
        draft.pickedFile = file;
      });
      _startConversion(draft);
    }
  }

  void _startConversion(_StoreyDraft draft) {
    _release(draft);
    final request = draft.request;
    draft.error = null;
    draft.stage = BimConversionStage.converting;
    bool cancelled() =>
        !mounted || !_storeys.contains(draft) || request != draft.request;
    draft.pending = () async {
      try {
        void progress(BimConversionStage stage) {
          if (!cancelled()) setState(() => draft.stage = stage);
        }

        final result = widget.underlayConverter != null
            ? await widget.underlayConverter!(
                draft.pickedFile!,
                progress,
                cancelled,
              )
            : await BimUnderlayConversionService.convert(
                draft.pickedFile!,
                isCancelled: cancelled,
                onProgress: progress,
              );
        if (cancelled()) {
          await result.dispose();
          return;
        }
        setState(() => draft.converted = result);
      } catch (error) {
        if (!cancelled()) setState(() => draft.error = error);
      }
    }();
  }

  Future<void> _submit() async {
    if (!_canCreate || !_formKey.currentState!.validate()) return;
    if (_storeys.isEmpty) return;

    setState(() => _isCreating = true);
    String? pendingProjectId;

    try {
      await Future.wait(_storeys.map((d) => d.pending ?? Future<void>.value()));
      if (!mounted) return;
      if (_storeys.any((d) => d.pickedFile != null && d.converted == null)) {
        throw StateError(context.l10n.bimProjectConversionFailed);
      }
      if (!mounted) return;
      _storeys.sort((a, b) => a.elevation.compareTo(b.elevation));
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

      pendingProjectId = project.id;
      // Attach any picked underlays
      for (final draft in _storeys) {
        if (draft.pickedFile != null) {
          await BimProjectLibraryService.instance.attachUnderlayFile(
            project.id,
            draft.storeyId,
            draft.pickedFile!,
            prepared: draft.converted,
          );
        }
      }

      final latestProject =
          await BimProjectLibraryService.instance.loadProject(project.id) ??
          project;

      pendingProjectId = null;
      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onProjectCreatedWithProject != null) {
          widget.onProjectCreatedWithProject!(latestProject);
        } else {
          widget.onProjectCreated?.call();
        }
      }
    } catch (e) {
      if (pendingProjectId != null) {
        await BimProjectLibraryService.instance.deleteProject(pendingProjectId);
      }
      debugPrint('Error creating project: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.l10n.error}: $e')));
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

    return PopScope(
      canPop: !_isCreating,
      child: Container(
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.apartment_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.bimProjectNew,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _isCreating
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content Body
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _isCreating,
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Storeys & Underlays Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.bimProjectStoreysSection,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n.bimProjectAddStorey),
                              onPressed: () => _editElevation(null),
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
                            key: ValueKey(draft.storeyId),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
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
                                            : const Color(
                                                0xFF00E5FF,
                                              ).withValues(alpha: 0.8),
                                        child: Text(
                                          '${idx + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${l10n.bimProjectElevation}: ${draft.elevation >= 0 ? "+" : ""}${draft.elevation.toStringAsFixed(2)} m',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.hintColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        tooltip: l10n.bimProjectEditElevation,
                                        onPressed: () => _editElevation(draft),
                                      ),
                                      if (_storeys.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
                                          tooltip: l10n.bimProjectDeleteStorey,
                                          onPressed: () {
                                            setState(() {
                                              _release(draft);
                                              _storeys.removeAt(idx);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (draft.stage != null) ...[
                                    if (draft.converted == null &&
                                        draft.error == null)
                                      const LinearProgressIndicator(),
                                    Text(
                                      draft.error != null
                                          ? '${l10n.bimProjectConversionFailed}: ${draft.error}'
                                          : draft.stage ==
                                                BimConversionStage.ready
                                          ? l10n.bimProjectKcadReady
                                          : draft.stage ==
                                                BimConversionStage.analysing
                                          ? l10n.bimProjectDetectingWallsAndSlabs
                                          : l10n.bimProjectConvertingUnderlay,
                                    ),
                                    if (draft.error != null)
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _startConversion(draft),
                                        ),
                                        child: Text(l10n.retry),
                                      ),
                                  ],
                                  // Underlay Attachment Button
                                  Row(
                                    children: [
                                      Expanded(
                                        child: draft.pickedFile != null
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF00E676,
                                                  ).withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF00E676,
                                                    ).withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 16,
                                                      color: Color(0xFF00E676),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        draft.pickedFile!.path
                                                            .split(
                                                              Platform
                                                                  .pathSeparator,
                                                            )
                                                            .last,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Text(
                                                l10n.bimProjectNoUnderlay,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.hintColor,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.upload_file_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          draft.pickedFile != null
                                              ? l10n.bimProjectReplaceUnderlay
                                              : l10n.bimProjectAddUnderlay,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () =>
                                            _pickUnderlayForStorey(draft),
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
                ),

                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    icon: _isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isCreating
                          ? l10n.bimProjectSaving
                          : l10n.bimProjectCreateButton,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    key: const ValueKey('create-bim-project'),
                    onPressed: _canCreate ? _submit : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
