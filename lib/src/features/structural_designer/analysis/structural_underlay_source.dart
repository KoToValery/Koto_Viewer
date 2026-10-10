import 'dart:convert';

import '../../dxf_viewer/models/dxf_models.dart';

/// Read-only view of the architecture preserved by BIM underlay conversion.
/// Generated layers/blocks are named explicitly by complete processing metadata;
/// a user layer that merely has a BIM-looking name is still source geometry.
class StructuralUnderlaySource {
  static DxfDocument original(
    DxfDocument document, {
    Map<String, dynamic>? metadata,
  }) {
    if (metadata == null) {
      try {
        final raw = document.headerVars[r'$KOTO_BIM_UNDERLAY'];
        if (raw == null) return document;
        final value = jsonDecode(raw);
        if (value is! Map<String, dynamic> ||
            value['complete'] != true ||
            !const [1, 2, 3].contains(value['version'])) {
          return document;
        }
        metadata = value;
      } catch (_) {
        return document;
      }
    }
    final owned = (metadata['layers'] as List? ?? [])
        .whereType<String>()
        .toSet();
    final blocks = (metadata['blocks'] as List? ?? [])
        .whereType<String>()
        .toSet();
    final visibility = metadata['visibility'] as Map? ?? {};
    if (owned.isEmpty && blocks.isEmpty) return document;
    return DxfDocument(
      entities: document.entities
          .where(
            (e) =>
                !owned.contains(e.layer) &&
                !(e is DxfInsert && blocks.contains(e.blockName)),
          )
          .toList(),
      blocks: {
        for (final b in document.blocks.values)
          if (!blocks.contains(b.name)) b.name: b,
      },
      layers: {
        for (final entry in document.layers.entries)
          if (!owned.contains(entry.key))
            entry.key: entry.value.copyWith(
              isVisible: visibility[entry.key] is bool
                  ? visibility[entry.key] as bool
                  : entry.value.isVisible,
            ),
      },
      headerVars: {
        for (final entry in document.headerVars.entries)
          if (entry.key != r'$KOTO_BIM_UNDERLAY') entry.key: entry.value,
      },
      bounds: document.bounds,
      entityStats: document.entityStats,
    );
  }
}
