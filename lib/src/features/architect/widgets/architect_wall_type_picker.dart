import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_wall_catalog.dart';
import 'architect_wall_layer_preview.dart';
import 'architect_wall_type_label.dart';

enum ArchitectWallPickerAction { select, variant, manage }

class ArchitectWallPickerResult {
  final ArchitectWallPickerAction action;
  final ArchitectWallType type;
  const ArchitectWallPickerResult(this.action, this.type);
}

Future<ArchitectWallPickerResult?> showArchitectWallTypePicker(
  BuildContext context, {
  required List<ArchitectWallType> types,
  required ArchitectWallType activeType,
  String projectId = '',
  ArchitectUnit unit = ArchitectUnit.centimeters,
  bool allowVariant = false,
  bool allowManage = false,
}) => showModalBottomSheet<ArchitectWallPickerResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .45,
      maxChildSize: .96,
      builder: (context, controller) => ArchitectWallCatalogBrowser(
        types: types,
        activeType: activeType,
        projectId: projectId,
        unit: unit,
        scrollController: controller,
        onSelect: (type) => Navigator.pop(
          context,
          ArchitectWallPickerResult(ArchitectWallPickerAction.select, type),
        ),
        onVariant: allowVariant
            ? (type) => Navigator.pop(
                context,
                ArchitectWallPickerResult(
                  ArchitectWallPickerAction.variant,
                  type,
                ),
              )
            : null,
        onManage: allowManage
            ? () => Navigator.pop(
                context,
                ArchitectWallPickerResult(
                  ArchitectWallPickerAction.manage,
                  activeType,
                ),
              )
            : null,
        onClose: () => Navigator.pop(context),
      ),
    ),
  ),
);

/// Shared browser for drafting and management; choosing and editing stay separate.
class ArchitectWallCatalogBrowser extends StatefulWidget {
  final List<ArchitectWallType> types;
  final ArchitectWallType activeType;
  final String projectId;
  final ArchitectUnit unit;
  final ScrollController? scrollController;
  final ValueChanged<ArchitectWallType> onSelect;
  final ValueChanged<ArchitectWallType>? onVariant, onCopy, onDelete;
  final VoidCallback? onManage, onClose, onNewType;
  final bool manage;
  final bool Function(ArchitectWallType)? canDelete;
  const ArchitectWallCatalogBrowser({
    super.key,
    required this.types,
    required this.activeType,
    required this.onSelect,
    this.projectId = '',
    this.unit = ArchitectUnit.centimeters,
    this.scrollController,
    this.onVariant,
    this.onCopy,
    this.onDelete,
    this.onManage,
    this.onClose,
    this.onNewType,
    this.manage = false,
    this.canDelete,
  });
  @override
  State<ArchitectWallCatalogBrowser> createState() => _BrowserState();
}

class _BrowserState extends State<ArchitectWallCatalogBrowser> {
  late ArchitectWallCategory category = ArchitectWallCategory.of(
    widget.activeType,
  );
  late final expanded = <ArchitectWallCategory, String>{
    category: ArchitectWallCatalogGroup.keyOf(widget.activeType),
  };
  final favorites = <String>{};
  final query = TextEditingController();
  bool search = false,
      favoritesOnly = false,
      bearingOnly = false,
      dirty = false;
  Future<void> writes = Future.value();
  String get preferenceKey => 'architect_wall_catalog_${widget.projectId}';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ArchitectWallCatalogBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.manage &&
        (oldWidget.activeType.id != widget.activeType.id ||
            ArchitectWallCatalogGroup.keyOf(oldWidget.activeType) !=
                ArchitectWallCatalogGroup.keyOf(widget.activeType))) {
      category = ArchitectWallCategory.of(widget.activeType);
      expanded[category] = ArchitectWallCatalogGroup.keyOf(widget.activeType);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || dirty) return;
    try {
      final data =
          jsonDecode(prefs.getString(preferenceKey) ?? '{}')
              as Map<String, dynamic>;
      setState(() {
        favorites.addAll(
          (data['favorites'] as List? ?? []).whereType<String>(),
        );
        final groups = data['groups'] as Map? ?? {};
        for (final c in ArchitectWallCategory.values) {
          if (c != category && groups[c.name] is String) {
            expanded[c] = groups[c.name] as String;
          }
        }
      });
    } on FormatException {
      /* A damaged preference must not block the catalog. */
    } on TypeError {
      /* Old or malformed preference shapes are ignored. */
    }
  }

  void _persist() {
    dirty = true;
    final snapshot = jsonEncode({
      'favorites': favorites.toList(),
      'groups': {for (final e in expanded.entries) e.key.name: e.value},
    });
    writes = writes
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(preferenceKey, snapshot);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  List<ArchitectWallType> get visible {
    final l = context.l10n, q = query.text.trim().toLowerCase();
    return widget.types
        .where(
          (t) =>
              (q.isNotEmpty || ArchitectWallCategory.of(t) == category) &&
              (!favoritesOnly || favorites.contains(t.id)) &&
              (!bearingOnly || t.isLoadBearing) &&
              (q.isEmpty ||
                  '${t.name} ${t.catalogGroupLabel(l, widget.unit)} ${t.compositionLabel(l, widget.unit)} ${architectWallLength(t.totalThickness, widget.unit)} ${ArchitectWallCategory.of(t).label(l)}'
                      .toLowerCase()
                      .contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _body(context, scrollAll: constraints.maxHeight < 340),
  );

  Widget _body(BuildContext context, {required bool scrollAll}) {
    final l = context.l10n,
        types = visible,
        groups = ArchitectWallCatalogGroup.build(types);
    final base =
        widget.types
            .where(
              (t) =>
                  t.id == widget.activeType.id &&
                  ArchitectWallCategory.of(t) == category,
            )
            .firstOrNull ??
        widget.types
            .where((t) => ArchitectWallCategory.of(t) == category)
            .firstOrNull ??
        widget.activeType;
    final rows = <Widget>[];
    for (final group in groups) {
      final first = group.types.first;
      if (group.types.length == 1 || query.text.isNotEmpty || favoritesOnly) {
        rows.addAll(group.types.map((t) => _type(t, grouped: false)));
      } else {
        final open = expanded[category] == group.key;
        rows.add(
          ListTile(
            key: ValueKey('wall-family-${group.key}'),
            leading: SizedBox(
              width: 28,
              height: 32,
              child: ArchitectWallLayerPreview(layers: first.resolvedLayers),
            ),
            title: Text(first.catalogGroupLabel(l, widget.unit)),
            subtitle: Text(
              '${l.wallVariantCount(group.types.length)}${first.isLoadBearing ? ' · ${l.wallBearing}' : ''}',
            ),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() => expanded[category] = open ? '' : group.key);
              _persist();
            },
          ),
        );
        if (open) rows.addAll(group.types.map((t) => _type(t, grouped: true)));
      }
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.manage ? l.wallTypesTitle : l.wallPickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l.search,
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  search = !search;
                  if (!search) query.clear();
                }),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: l.close,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        if (search)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              key: const ValueKey('wall-catalog-search'),
              controller: query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.wallPickerSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (final c in ArchitectWallCategory.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      key: ValueKey('wall-category-${c.name}'),
                      style: TextButton.styleFrom(
                        backgroundColor: category == c
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                      ),
                      onPressed: () => setState(() {
                        category = c;
                        bearingOnly = false;
                        expanded.putIfAbsent(
                          c,
                          () =>
                              widget.types
                                  .where(
                                    (t) => ArchitectWallCategory.of(t) == c,
                                  )
                                  .map(ArchitectWallCatalogGroup.keyOf)
                                  .firstOrNull ??
                              '',
                        );
                      }),
                      child: Text(c.label(l), maxLines: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('wall-favorites-filter'),
                label: Text(l.wallFavorites),
                avatar: const Icon(Icons.star_border, size: 18),
                selected: favoritesOnly,
                onSelected: (v) => setState(() => favoritesOnly = v),
              ),
              if (category != ArchitectWallCategory.parapet)
                FilterChip(
                  label: Text(l.wallBearing),
                  selected: bearingOnly,
                  onSelected: (v) => setState(() => bearingOnly = v),
                ),
            ],
          ),
        ),
        if (scrollAll) ...[
          if (types.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.wallPickerEmpty),
            ),
          ...rows,
        ] else
          Expanded(
            child: types.isEmpty
                ? Center(child: Text(l.wallPickerEmpty))
                : ListView(
                    key: const ValueKey('wall-catalog-list'),
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: rows,
                  ),
          ),
        if (widget.onVariant != null ||
            widget.onManage != null ||
            widget.onNewType != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (widget.onNewType != null)
                  TextButton.icon(
                    key: const ValueKey('wall-type-add'),
                    onPressed: widget.onNewType,
                    icon: const Icon(Icons.add),
                    label: Text(l.wallNewType),
                  )
                else if (widget.onVariant != null)
                  TextButton.icon(
                    key: const ValueKey('wall-new-variant'),
                    onPressed: () => widget.onVariant!(base),
                    icon: const Icon(Icons.add),
                    label: Text(l.wallVariant),
                  ),
                const Spacer(),
                if (widget.onManage != null)
                  TextButton.icon(
                    onPressed: widget.onManage,
                    icon: const Icon(Icons.tune),
                    label: Text(l.wallTypesShort),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
    return SafeArea(
      top: false,
      child: scrollAll
          ? SingleChildScrollView(
              controller: widget.scrollController,
              child: content,
            )
          : content,
    );
  }

  Widget _type(ArchitectWallType type, {required bool grouped}) {
    final l = context.l10n, selected = type.id == widget.activeType.id;
    final showTotal =
        type.resolvedLayers.length > 1 ||
        (!type.isFactoryPreset && type.name.isNotEmpty) ||
        (grouped && !type.isParapet);
    return Padding(
      padding: EdgeInsets.only(left: grouped ? 28 : 8, right: 8),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey(
                  widget.manage
                      ? 'wall-type-row-${type.id}'
                      : 'architect-wall-type-${type.id}',
                ),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  expanded[ArchitectWallCategory.of(type)] =
                      ArchitectWallCatalogGroup.keyOf(type);
                  _persist();
                  widget.onSelect(type);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      if (!grouped) ...[
                        SizedBox(
                          width: 24,
                          height: 30,
                          child: ArchitectWallLayerPreview(
                            layers: type.resolvedLayers,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.catalogLabel(
                                l,
                                widget.unit,
                                grouped: grouped,
                              ),
                            ),
                            if (query.text.isNotEmpty)
                              Text(
                                ArchitectWallCategory.of(type).label(l),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (type.isLoadBearing)
                              Text(
                                l.wallBearing,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (showTotal)
                        Flexible(
                          child: Text(
                            architectWallLength(
                              type.totalThickness,
                              widget.unit,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      if (selected) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (widget.manage)
              PopupMenuButton<String>(
                tooltip: l.wallTypeDetails,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'copy', child: Text(l.wallTypeCopy)),
                  if (widget.onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      enabled: widget.canDelete?.call(type) ?? true,
                      child: Text(l.delete),
                    ),
                ],
                onSelected: (action) => action == 'copy'
                    ? widget.onCopy?.call(type)
                    : widget.onDelete?.call(type),
              )
            else
              IconButton(
                key: ValueKey('wall-favorite-${type.id}'),
                tooltip: l.wallFavoriteToggle,
                isSelected: favorites.contains(type.id),
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star),
                onPressed: () {
                  setState(() {
                    favorites.contains(type.id)
                        ? favorites.remove(type.id)
                        : favorites.add(type.id);
                  });
                  _persist();
                },
              ),
          ],
        ),
      ),
    );
  }
}
