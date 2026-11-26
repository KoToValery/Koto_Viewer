import '../../dxf_viewer/models/dxf_models.dart';

/// Read-only views of an immutable source revision. Filtering before indexing
/// keeps renderers, intersection snapping and direct snaps on the same geometry.
abstract final class ArchitectCadEntityVisibility {
  static final _views = Expando<_CadVisibilityViews>();

  static _CadVisibilityViews _of(DxfDocument source) =>
      _views[source] ??= _CadVisibilityViews(source);

  static int? indexOf(DxfDocument source, DxfEntity entity) =>
      _of(source).indices[entity];

  static DxfDocument visible(DxfDocument source, Set<int> hidden) =>
      hidden.isEmpty ? source : _of(source).filtered(hidden, include: false);

  static DxfDocument hidden(DxfDocument source, Set<int> hidden) =>
      _of(source).filtered(hidden, include: true);

  static DxfDocument selected(DxfDocument source, Set<DxfEntity> entities) =>
      _of(source).select(entities);

  static DxfDocument _view(DxfDocument source, List<DxfEntity> entities) =>
      DxfDocument(
        layers: source.layers,
        blocks: source.blocks,
        entities: entities,
        headerVars: source.headerVars,
        bounds: source.bounds,
        entityStats: source.entityStats,
        textStyles: source.textStyles,
        lineTypes: source.lineTypes,
        dimStyles: source.dimStyles,
        layouts: const ['Model'],
        layoutEntities: {'Model': entities},
        layoutBounds: {'Model': source.bounds},
        inferLayerLineweights: false,
      );
}

class _CadVisibilityViews {
  final DxfDocument source;
  late final indices = Map<DxfEntity, int>.identity()
    ..addEntries(source.entities.indexed.map((e) => MapEntry(e.$2, e.$1)));
  Set<int>? _previous;
  DxfDocument? _visible, _hidden, _selection;

  _CadVisibilityViews(this.source);

  DxfDocument select(Set<DxfEntity> entities) {
    final previous = _selection;
    if (previous != null &&
        previous.entities.length == entities.length &&
        previous.entities.every(entities.contains)) {
      return previous;
    }
    final ordered = entities.toList()
      ..sort((a, b) => indices[a]!.compareTo(indices[b]!));
    return _selection = ArchitectCadEntityVisibility._view(source, ordered);
  }

  DxfDocument filtered(Set<int> hidden, {required bool include}) {
    if (!identical(_previous, hidden)) {
      _previous = hidden;
      _visible = _hidden = null;
    }
    final cached = include ? _hidden : _visible;
    if (cached != null) return cached;
    final filtered = ArchitectCadEntityVisibility._view(
      source,
      include
          ? [
              for (final index in hidden.toList()..sort())
                if (index >= 0 &&
                    index < source.entities.length &&
                    !source.entities[index].isPaperSpace)
                  source.entities[index],
            ]
          : [
              for (final (index, entity) in source.entities.indexed)
                if (!entity.isPaperSpace && !hidden.contains(index)) entity,
            ],
    );
    if (include) {
      _hidden = filtered;
    } else {
      _visible = filtered;
    }
    return filtered;
  }
}
