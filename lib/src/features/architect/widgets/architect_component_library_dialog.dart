// === SECTION: ARCHITECTURAL COMPONENT LIBRARY DIALOG & BROWSER ===
// Table of Contents:
// 1. DIALOG CONTAINER & CATEGORY TABS
// 2. COMPONENT GRID & PREVIEW CARDS
// 3. 2D SYMBOL MINI THUMBNAIL PAINTER

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';
import '../models/architect_fenestration_style.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';
import '../services/fenestration_library_service.dart';
import 'component_studio_dialog.dart';

/// Interactive modal browser for architectural 3D/2D symbols, furniture, sanitary items,
/// and fenestration styles (doors & windows).
class ArchitectComponentLibraryDialog extends StatefulWidget {
  final ValueChanged<ArchitectComponentDefinition>? onSelectComponent;
  final ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration;

  const ArchitectComponentLibraryDialog({
    super.key,
    this.onSelectComponent,
    this.onSelectFenestration,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<ArchitectComponentDefinition>? onSelectComponent,
    ValueChanged<ArchitectFenestrationStyle>? onSelectFenestration,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ArchitectComponentLibraryDialog(
        onSelectComponent: onSelectComponent,
        onSelectFenestration: onSelectFenestration,
      ),
    );
  }

  @override
  State<ArchitectComponentLibraryDialog> createState() =>
      _ArchitectComponentLibraryDialogState();
}

class _ArchitectComponentLibraryDialogState
    extends State<ArchitectComponentLibraryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  

  final _categories = const [
    ArchitectComponentCategory.sanitary,
    ArchitectComponentCategory.furniture,
    ArchitectComponentCategory.kitchen,
    ArchitectComponentCategory.storage,
    ArchitectComponentCategory.office,
    ArchitectComponentCategory.doors,
    ArchitectComponentCategory.windows,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _categoryLabel(BuildContext context, ArchitectComponentCategory cat) {
    final l = context.l10n;
    return switch (cat) {
      ArchitectComponentCategory.sanitary => l.architectCategorySanitary,
      ArchitectComponentCategory.furniture => l.architectCategoryFurniture,
      ArchitectComponentCategory.kitchen => l.architectCategoryKitchen,
      ArchitectComponentCategory.storage => l.architectCategoryStorage,
      ArchitectComponentCategory.office => l.architectCategoryOffice,
      ArchitectComponentCategory.doors => l.architectToolDoor,
      ArchitectComponentCategory.windows => l.architectToolWindow,
      _ => cat.name,
    };
  }

  IconData _categoryIcon(ArchitectComponentCategory cat) {
    return switch (cat) {
      ArchitectComponentCategory.sanitary => Icons.bathtub_outlined,
      ArchitectComponentCategory.furniture => Icons.chair_outlined,
      ArchitectComponentCategory.kitchen => Icons.kitchen_outlined,
      ArchitectComponentCategory.storage => Icons.inventory_2_outlined,
      ArchitectComponentCategory.office => Icons.desk_outlined,
      ArchitectComponentCategory.doors => Icons.meeting_room_outlined,
      ArchitectComponentCategory.windows => Icons.window_outlined,
      _ => Icons.category_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    
    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 680),
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.widgets_outlined, color: Color(0xFF00E5FF), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.architectComponentLibraryTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.code, size: 18),
                    label: Text(l.architectComponentStudioBtn),
                    onPressed: () {
                      ComponentStudioDialog.show(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF37474F)),

            // Tabs Bar
            Container(
              color: const Color(0xFF262633),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFF00E5FF),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white60,
                tabs: [
                  for (final cat in _categories)
                    Tab(
                      icon: Icon(_categoryIcon(cat), size: 18),
                      text: _categoryLabel(context, cat),
                    ),
                ],
              ),
            ),

            // Tab Views Grid
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final cat in _categories)
                    _buildCategoryGrid(context, cat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, ArchitectComponentCategory cat) {
    if (cat == ArchitectComponentCategory.doors || cat == ArchitectComponentCategory.windows) {
      return _buildFenestrationGrid(context, cat);
    }

    final allDefs = ComponentLibraryService.instance.getByCategory(cat);
    if (allDefs.isEmpty) {
      return Center(
        child: Text(
          context.l10n.architectComponentNoItems,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allDefs.length,
      itemBuilder: (ctx, idx) {
        final def = allDefs[idx];
        final geo = ComponentGeometryCache.instance.getOrCompute(def, def.defaultParameters);
        final w = (def.defaultParameters['width'] as num?)?.toDouble() ?? 0.60;
        final d = (def.defaultParameters['depth'] as num?)?.toDouble() ?? 0.60;
        final h = (def.defaultParameters['height'] as num?)?.toDouble() ?? 0.80;

        return Card(
          color: const Color(0xFF2A2A38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF3F3F54)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ComponentLibraryService.instance.setActiveDefinition(def);
              widget.onSelectComponent?.call(def);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 2D Thumbnail
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _ComponentThumbnailPainter(geo.block2d),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    def.defaultName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(w * 100).round()}×${(d * 100).round()}×${(h * 100).round()} cm',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFenestrationGrid(BuildContext context, ArchitectComponentCategory cat) {
    final isDoor = cat == ArchitectComponentCategory.doors;
    final styles = isDoor
        ? FenestrationLibraryService.instance.getDoorStyles()
        : FenestrationLibraryService.instance.getWindowStyles();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: styles.length,
      itemBuilder: (ctx, idx) {
        final style = styles[idx];
        return Card(
          color: const Color(0xFF2A2A38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF3F3F54)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              widget.onSelectFenestration?.call(style);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isDoor ? Icons.meeting_room : Icons.window,
                        color: const Color(0xFF00E5FF),
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    style.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(style.defaultWidth * 100).round()}×${(style.defaultHeight * 100).round()} cm',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// 3. 2D SYMBOL MINI THUMBNAIL PAINTER
// ===========================================================================

class _ComponentThumbnailPainter extends CustomPainter {
  final ArchitectComponentBlock2D block;

  const _ComponentThumbnailPainter(this.block);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final b = block.bounds;
    final bw = b.width > 1e-4 ? b.width : 0.60;
    final bd = b.height > 1e-4 ? b.height : 0.60;

    final scaleX = (size.width * 0.75) / bw;
    final scaleY = (size.height * 0.75) / bd;
    final scale = math.min(scaleX, scaleY);

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(scale, scale);
    canvas.translate(-b.center.dx, -b.center.dy);

    // Draw whiteout background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(block.boundsMask, bgPaint);

    // Draw outline
    final strokePaint = Paint()
      ..color = const Color(0xFF263238)
      ..strokeWidth = 1.2 / scale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(block.outline, strokePaint);

    // Draw details
    final detailPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 0.8 / scale
      ..style = PaintingStyle.stroke;
    for (final p in block.detailPaths) {
      canvas.drawPath(p, detailPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ComponentThumbnailPainter oldDelegate) =>
      oldDelegate.block != block;
}
