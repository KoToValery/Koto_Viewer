import '../models/architect_wall_type.dart';

/// Generic editable balcony/terrace systems. A new selection is explicit;
/// legacy parapets never acquire one of these designs just by loading.
class ArchitectRailingCatalog {
  static final List<ArchitectWallType> presets = List.unmodifiable([
    for (final kind in ArchitectRailingKind.values)
      ArchitectWallType(
        id: 'factory_railing_${kind.name}',
        name: '',
        usage: WallUsage.parapet,
        totalThickness: switch (kind) {
          ArchitectRailingKind.solidCap ||
          ArchitectRailingKind.solidStainless => .12,
          ArchitectRailingKind.glassChannel => .06,
          ArchitectRailingKind.verticalSlats => .06,
          _ => .042,
        },
        customHeight: 1.05,
        railing: ArchitectRailingDesign.preset(kind),
        layers:
            kind == ArchitectRailingKind.solidCap ||
                kind == ArchitectRailingKind.solidStainless
            ? const [
                ArchitectMaterialLayer(
                  id: 'core',
                  material: ArchitectMaterial.concrete,
                  role: ArchitectLayerRole.core,
                  thickness: .12,
                ),
              ]
            : const [],
      ),
  ]);
}
