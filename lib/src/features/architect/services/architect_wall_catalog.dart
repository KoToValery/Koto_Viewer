import '../models/architect_wall_type.dart';

enum ArchitectWallCategory {
  exterior,
  interior,
  parapet;

  static ArchitectWallCategory of(ArchitectWallType type) => type.isParapet
      ? parapet
      : type.resolvedLocation == ArchitectWallLocation.exterior
      ? exterior
      : interior;
}

/// Groups are derived from physical properties, never IDs or translated names.
/// Each member remains an independent type with its original identity.
class ArchitectWallCatalogGroup {
  final String key;
  final List<ArchitectWallType> types;
  ArchitectWallCatalogGroup(this.key, this.types);

  static String keyOf(ArchitectWallType type) {
    final core = type.resolvedLayers.where(
      (l) => l.role == ArchitectLayerRole.core,
    );
    final signature = core
        .map(
          (l) =>
              '${l.material.name}:${type.isParapet ? '' : l.thickness.toStringAsPrecision(12)}',
        )
        .join('|');
    return '${ArchitectWallCategory.of(type).name}/${type.isLoadBearing}/'
        '${type.isParapet ? (type.parapetFinish ?? ParapetFinish.cap).name : ''}/$signature';
  }

  static List<ArchitectWallCatalogGroup> build(
    Iterable<ArchitectWallType> types,
  ) {
    final groups = <String, List<ArchitectWallType>>{};
    for (final type in types) {
      (groups[keyOf(type)] ??= []).add(type);
    }
    return [
      for (final entry in groups.entries)
        ArchitectWallCatalogGroup(entry.key, entry.value),
    ];
  }
}
