// === SECTION: ARCHITECT STOREYS SCREEN ===
// Table of Contents:
// 1. STATE & CONTROLLER LIFECYCLE
// 2. MAIN APPBAR & ACTIONS
// 3. VERTICAL STOREY STACK LIST & CONTROLS
// 4. TYPICAL STOREY COPY PANEL & CATEGORIES
// 5. 2D STOREY PLAN MINI PREVIEW PAINTER
// 6. BATCH ADD DIALOG & COPY EXECUTION

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_command_controller.dart';

/// Full-scale screen for managing building storey levels, elevations, and
/// batch copying typical floor layouts across multi-storey buildings.
class ArchitectStoreysScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  final String? initialSelectedStoreyId;

  const ArchitectStoreysScreen({
    super.key,
    required this.controller,
    this.initialSelectedStoreyId,
  });

  @override
  State<ArchitectStoreysScreen> createState() => _ArchitectStoreysScreenState();
}

class _ArchitectStoreysScreenState extends State<ArchitectStoreysScreen> {
  ArchitectProject get project => widget.controller.project;

  late String _selectedSourceStoreyId;
  final Set<String> _targetStoreyIds = {};
  final Set<ArchitectStoreyElementType> _selectedCategories =
      Set.of(ArchitectStoreyElementType.defaultTypicalCategories);

  StoreyCopyMode _mode = StoreyCopyMode.replace;
  bool _adjustWallHeights = true;
  bool _adjustLevelMarkers = true;
  bool _preserveGroups = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onProjectChanged);
    _initStoreys();
  }

  void _initStoreys() {
    final validIds = project.storeys.where((s) => !s.isRoof).map((s) => s.id);
    if (widget.initialSelectedStoreyId != null &&
        validIds.contains(widget.initialSelectedStoreyId)) {
      _selectedSourceStoreyId = widget.initialSelectedStoreyId!;
    } else if (validIds.contains(project.activeStoreyId)) {
      _selectedSourceStoreyId = project.activeStoreyId;
    } else {
      _selectedSourceStoreyId = validIds.firstOrNull ?? 'default';
    }
    _defaultSelectTargetsAbove();
  }

  void _defaultSelectTargetsAbove() {
    final source = project.storeys
        .where((s) => s.id == _selectedSourceStoreyId)
        .firstOrNull;
    if (source == null) return;

    _targetStoreyIds.clear();
    final above = project.storeys
        .where((s) => !s.isRoof && s.elevation > source.elevation)
        .map((s) => s.id);
    _targetStoreyIds.addAll(above);
  }

  void _onProjectChanged() {
    if (!mounted) return;
    setState(() {
      final normal = project.storeys.where((s) => !s.isRoof);
      if (!normal.any((s) => s.id == _selectedSourceStoreyId)) {
        _selectedSourceStoreyId = normal.firstOrNull?.id ?? 'default';
      }
      _targetStoreyIds.removeWhere(
        (id) => !project.storeys.any((s) => s.id == id),
      );
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onProjectChanged);
    super.dispose();
  }

  ArchitectStorey? get _sourceStorey => project.storeys
      .where((s) => s.id == _selectedSourceStoreyId)
      .firstOrNull;

  void _addNewStoreyAbove() {
    widget.controller.commit(project.addStoreyAbove());
    _onProjectChanged();
  }

  Future<void> _showBatchAddDialog() async {
    final l = context.l10n;
    var count = 3;
    var height = 2.80;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: Text(
          l.architectBatchAddStoreys,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: count.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l.architectBatchAddCount,
                labelStyle: const TextStyle(color: Colors.white70),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => count = int.tryParse(v) ?? 1,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: height.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l.architectBatchAddHeight,
                labelStyle: const TextStyle(color: Colors.white70),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => height = double.tryParse(v) ?? 2.80,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              MaterialLocalizations.of(ctx).cancelButtonLabel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.architectBatchAddButton),
          ),
        ],
      ),
    );

    if (confirmed == true && count > 0) {
      widget.controller.execute(
        AddArchitectStoreysBatch(count: count, typicalHeight: height),
      );
      _defaultSelectTargetsAbove();
    }
  }

  void _executeCopy() {
    final l = context.l10n;
    if (_targetStoreyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.architectNoTargetStoreysSelected),
          backgroundColor: Colors.amber[900],
        ),
      );
      return;
    }

    final options = StoreyCopyOptions(
      sourceStoreyId: _selectedSourceStoreyId,
      targetStoreyIds: _targetStoreyIds,
      elementTypes: _selectedCategories,
      mode: _mode,
      adjustWallHeights: _adjustWallHeights,
      adjustLevelMarkers: _adjustLevelMarkers,
      preserveGroups: _preserveGroups,
    );

    final (_, result) =
        ArchitectStoreyCopyService.copyElements(project, options);

    widget.controller.execute(CopyArchitectElementsAcrossStoreys(options));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.architectCopySuccess(
            result.totalCopied,
            result.targetStoreyCount,
          ),
        ),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 850;

    return Scaffold(
      backgroundColor: const Color(0xFF16161D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        elevation: 0,
        title: Text(
          l.architectStoreysScreenTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (width >= 700) ...[
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l.architectAddStoreyAbove),
              onPressed: _addNewStoreyAbove,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const AppIcon(
                AppIconId.duplicate,
                size: 16,
                color: Colors.black,
              ),
              label: Text(l.architectBatchAddStoreys),
              onPressed: _showBatchAddDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF00E5FF)),
              tooltip: l.architectAddStoreyAbove,
              onPressed: _addNewStoreyAbove,
            ),
            IconButton(
              icon: const AppIcon(
                AppIconId.duplicate,
                size: 18,
                color: Color(0xFF00E5FF),
              ),
              tooltip: l.architectBatchAddStoreys,
              onPressed: _showBatchAddDialog,
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: isCompact ? _buildCompactLayout() : _buildWideLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel: Storey Stack & Properties
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: _buildStoreyStackList(),
          ),
        ),

        // Right Panel: Typical Floor Transfer & Preview
        Expanded(
          flex: 6,
          child: _buildCopyControlPanel(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1E1E26),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  icon: const Icon(Icons.layers_rounded),
                  text: l.architectStoreyStackTab,
                ),
                Tab(
                  icon: const Icon(Icons.copy_all_rounded),
                  text: l.architectCopyStoreyTab,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStoreyStackList(),
                _buildCopyControlPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreyStackList() {
    final l = context.l10n;
    // Sorted from highest down to lowest
    final normalStoreys = project.storeys
        .where((s) => !s.isRoof)
        .toList()
      ..sort((a, b) => b.elevation.compareTo(a.elevation));

    final roof = project.roofStorey;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Roof Storey Indicator
        if (roof != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF242430),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const AppIcon(
                  AppIconId.roof,
                  size: 20,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l.architectRoofPlan} · ${roof.elevationLabel}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Storey Cards
        for (final s in normalStoreys) _buildStoreyCard(s),
      ],
    );
  }

  Widget _buildStoreyCard(ArchitectStorey s) {
    final l = context.l10n;
    final isSource = s.id == _selectedSourceStoreyId;
    final isTarget = _targetStoreyIds.contains(s.id);

    final elementCount = s.walls.length +
        s.columns.length +
        s.beams.length +
        s.slabs.length +
        s.zones.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSource
            ? const Color(0xFF282F38)
            : (isTarget ? const Color(0xFF21252C) : const Color(0xFF1E1E26)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSource
              ? const Color(0xFF00E5FF)
              : (isTarget ? Colors.cyan.withValues(alpha: 0.3) : Colors.white12),
          width: isSource ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSource ? const Color(0xFF00E5FF) : const Color(0xFF2A2A38),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.apartment_rounded,
              color: isSource ? Colors.black : Colors.white70,
              size: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                s.name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSource ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF16161D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.elevationLabel,
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'H = ${s.height.toStringAsFixed(2)} m',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                '•  ${l.architectStoreyElementsCount(elementCount)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (isSource)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.architectCopySourceStorey,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
          color: const Color(0xFF282834),
          onSelected: (action) {
            if (action == 'make_source') {
              setState(() {
                _selectedSourceStoreyId = s.id;
                _defaultSelectTargetsAbove();
              });
            } else if (action == 'delete') {
              _confirmDeleteStorey(s);
            } else if (action == 'edit_height') {
              _editStoreyHeight(s);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'make_source',
              child: Text(l.architectCopySourceStorey),
            ),
            PopupMenuItem(
              value: 'edit_height',
              child: Text(l.architectStoreyHeightLabel),
            ),
            if (project.storeys.where((st) => !st.isRoof).length > 1)
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l.deleteStorey,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedSourceStoreyId = s.id;
            _defaultSelectTargetsAbove();
          });
        },
      ),
      ),
    );
  }

  Future<void> _editStoreyHeight(ArchitectStorey storey) async {
    final l = context.l10n;
    var newHeight = storey.height;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: Text(
          '${l.architectStoreyHeightLabel}: ${storey.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextFormField(
          initialValue: storey.height.toStringAsFixed(2),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            suffixText: 'm',
          ),
          onChanged: (v) => newHeight = double.tryParse(v) ?? storey.height,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && newHeight > 0) {
      widget.controller.commit(
        project.updateStorey(
          storey.copyWith(height: newHeight),
          recalculateAbove: true,
        ),
      );
    }
  }

  Future<void> _confirmDeleteStorey(ArchitectStorey storey) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: Text(
          l.deleteStorey,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l.architectDeleteStoreyConfirm(storey.name),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.controller.commit(project.deleteStorey(storey.id));
      _onProjectChanged();
    }
  }

  Widget _buildCopyControlPanel() {
    final l = context.l10n;
    final source = _sourceStorey;
    final normalStoreys = project.storeys
        .where((s) => !s.isRoof)
        .toList()
      ..sort((a, b) => b.elevation.compareTo(a.elevation));

    return ListView(
      key: const ValueKey('architect-storeys-copy-panel'),
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Template Storey & 2D Mini Preview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.architectCopySourceStorey}: ${source?.name ?? ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    source?.elevationLabel ?? "",
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mini 2D Preview Canvas
              if (source != null)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121218),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: _StoreyMiniPlanPainter(
                        storey: source,
                        emptyMessage: l.architectNoDrawnElements,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Categories
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              l.architectCopyCategoriesTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedCategories.addAll(
                        ArchitectStoreyElementType.defaultTypicalCategories,
                      );
                    }),
                    child: Text(l.architectSelectAllStoreys),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedCategories.clear()),
                    child: Text(l.architectClearStoreySelection),
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat
                in ArchitectStoreyElementType.defaultTypicalCategories)
              _buildCategoryChip(cat, source),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Target Storeys Selection
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              l.architectCopyTargetStoreys,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      if (source == null) return;
                      setState(() {
                        _targetStoreyIds.clear();
                        _targetStoreyIds.addAll(
                          project.storeys
                              .where(
                                (s) =>
                                    !s.isRoof && s.elevation > source.elevation,
                              )
                              .map((s) => s.id),
                        );
                      });
                    },
                    child: Text(l.architectSelectAllAbove),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _targetStoreyIds.clear();
                        _targetStoreyIds.addAll(
                          project.storeys
                              .where((s) => !s.isRoof && s.id != source?.id)
                              .map((s) => s.id),
                        );
                      });
                    },
                    child: Text(l.architectSelectAllStoreys),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _targetStoreyIds.clear()),
                    child: Text(l.architectClearStoreySelection),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [
              for (final s in normalStoreys)
                if (s.id != _selectedSourceStoreyId)
                  CheckboxListTile(
                    dense: true,
                    activeColor: const Color(0xFF00E5FF),
                    checkColor: Colors.black,
                    value: _targetStoreyIds.contains(s.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _targetStoreyIds.add(s.id);
                        } else {
                          _targetStoreyIds.remove(s.id);
                        }
                      });
                    },
                    title: Text(
                      '${s.name} · ${s.elevationLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'H = ${s.height.toStringAsFixed(2)} m',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
            ],
          ),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Mode & Adaptation Settings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [
              RadioListTile<StoreyCopyMode>(
                dense: true,
                activeColor: const Color(0xFF00E5FF),
                value: StoreyCopyMode.replace,
                groupValue: _mode,
                onChanged: (m) => setState(() => _mode = m!),
                title: Text(
                  l.architectCopyModeReplace,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l.architectCopyModeReplaceHelp,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              RadioListTile<StoreyCopyMode>(
                dense: true,
                activeColor: const Color(0xFF00E5FF),
                value: StoreyCopyMode.merge,
                groupValue: _mode,
                onChanged: (m) => setState(() => _mode = m!),
                title: Text(
                  l.architectCopyModeMerge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l.architectCopyModeMergeHelp,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              const Divider(color: Colors.white12),
              SwitchListTile(
                dense: true,
                activeColor: const Color(0xFF00E5FF),
                value: _adjustWallHeights,
                onChanged: (v) => setState(() => _adjustWallHeights = v),
                title: Text(
                  l.architectAdjustWallHeightsToStorey,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              SwitchListTile(
                dense: true,
                activeColor: const Color(0xFF00E5FF),
                value: _adjustLevelMarkers,
                onChanged: (v) => setState(() => _adjustLevelMarkers = v),
                title: Text(
                  l.architectAdjustElevationMarkers,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              SwitchListTile(
                dense: true,
                activeColor: const Color(0xFF00E5FF),
                value: _preserveGroups,
                onChanged: (v) => setState(() => _preserveGroups = v),
                title: Text(
                  l.architectPreserveGroups,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          ),
        ),
        const SizedBox(height: 24),

        // 5. Submit Action Button
        ElevatedButton.icon(
          key: const ValueKey('architect-storeys-execute-copy'),
          onPressed: _targetStoreyIds.isNotEmpty && _selectedCategories.isNotEmpty
              ? _executeCopy
              : null,
          icon: const AppIcon(
            AppIconId.duplicate,
            size: 18,
            color: Colors.black,
          ),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${l.architectCopyElementsButton} (${_targetStoreyIds.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
    ArchitectStoreyElementType cat,
    ArchitectStorey? source,
  ) {
    final count = source != null ? cat.countInStorey(source) : 0;
    final isSelected = _selectedCategories.contains(cat);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.black)
          : null,
      label: Text('${cat.localizedLabel(context.l10n)} ($count)'),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFF1E1E26),
      selectedColor: const Color(0xFF00E5FF),
      side: BorderSide(
        color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCategories.add(cat);
          } else {
            _selectedCategories.remove(cat);
          }
        });
      },
    );
  }
}

/// Lightweight preview painter rendering walls, columns, and slabs for a storey.
class _StoreyMiniPlanPainter extends CustomPainter {
  final ArchitectStorey storey;
  final String emptyMessage;

  const _StoreyMiniPlanPainter({
    required this.storey,
    required this.emptyMessage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = <Offset>[
      for (final w in storey.walls) ...[w.startPoint, w.endPoint],
      for (final c in storey.columns) c.position,
      for (final s in storey.slabs) ...s.polygon,
    ];

    if (allPoints.isEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: emptyMessage,
          style: const TextStyle(color: Colors.white30, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    var minX = allPoints.first.dx;
    var maxX = allPoints.first.dx;
    var minY = allPoints.first.dy;
    var maxY = allPoints.first.dy;

    for (final p in allPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final modelWidth = math.max(1.0, maxX - minX);
    final modelHeight = math.max(1.0, maxY - minY);

    final scaleX = (size.width - 24) / modelWidth;
    final scaleY = (size.height - 24) / modelHeight;
    final scale = math.min(scaleX, scaleY);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final modelCenterX = (minX + maxX) / 2;
    final modelCenterY = (minY + maxY) / 2;

    Offset toScreen(Offset p) {
      return Offset(
        centerX + (p.dx - modelCenterX) * scale,
        centerY - (p.dy - modelCenterY) * scale,
      );
    }

    // Draw Slabs
    final slabPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    for (final slab in storey.slabs) {
      if (slab.polygon.length >= 3) {
        final path = Path()
          ..moveTo(
            toScreen(slab.polygon.first).dx,
            toScreen(slab.polygon.first).dy,
          );
        for (var i = 1; i < slab.polygon.length; i++) {
          final pt = toScreen(slab.polygon[i]);
          path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, slabPaint);
      }
    }

    // Draw Walls
    final wallPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 0.25 * scale)
      ..strokeCap = StrokeCap.round;

    for (final wall in storey.walls) {
      canvas.drawLine(
        toScreen(wall.startPoint),
        toScreen(wall.endPoint),
        wallPaint,
      );
    }

    // Draw Columns
    final colPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final col in storey.columns) {
      final pt = toScreen(col.position);
      final radius = math.max(2.0, (col.width / 2) * scale);
      canvas.drawCircle(pt, radius, colPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StoreyMiniPlanPainter oldDelegate) =>
      oldDelegate.storey != storey || oldDelegate.emptyMessage != emptyMessage;
}
