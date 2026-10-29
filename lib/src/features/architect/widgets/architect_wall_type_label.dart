import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_wall_type.dart';
import 'architect_material_layer_label.dart';
import '../models/architect_project.dart' show ArchitectUnit;
import '../services/architect_wall_catalog.dart';

extension ArchitectWallSystemLabel on ArchitectWallSystemKind {
  String label(AppLocalizations l) => switch (this) {
    ArchitectWallSystemKind.layered => l.wallSystemLayered,
    ArchitectWallSystemKind.roundLogs => l.wallSystemLogs,
    ArchitectWallSystemKind.studFrame => l.wallSystemFrame,
    ArchitectWallSystemKind.sandwichPanels => l.wallSystemPanels,
  };
}

String architectWallLength(double value, ArchitectUnit unit) =>
    '${ArchitectUnit.trimZeros(unit.toUnit(value).toStringAsFixed(6))} ${unit.symbol}';

extension ArchitectWallCategoryLabel on ArchitectWallCategory {
  String label(AppLocalizations l) => switch (this) {
    ArchitectWallCategory.exterior => l.wallCategoryExterior,
    ArchitectWallCategory.interior => l.wallCategoryInterior,
    ArchitectWallCategory.parapet => l.wallCategoryParapet,
  };
}

extension ArchitectWallTypeLabel on ArchitectWallType {
  String parapetFinishLabel(AppLocalizations l) =>
      (parapetFinish ?? ParapetFinish.cap) == ParapetFinish.cap
      ? l.wallParapetCap
      : l.wallParapetHandrail;

  String catalogGroupLabel(AppLocalizations l, ArchitectUnit unit) {
    if (system.isSpecial) {
      return l.wallMaterialThickness(
        system.kind.label(l),
        architectWallLength(totalThickness, unit),
      );
    }
    if (isParapet) {
      final materials = resolvedLayers
          .where((layer) => layer.role == ArchitectLayerRole.core)
          .map((layer) => layer.material.label(l))
          .toSet()
          .join(' + ');
      return l.wallParapetGroup(parapetFinishLabel(l), materials);
    }
    return resolvedLayers
        .where((layer) => layer.role == ArchitectLayerRole.core)
        .map(
          (layer) => l.wallMaterialThickness(
            layer.material.label(l),
            architectWallLength(layer.thickness, unit),
          ),
        )
        .join(' + ');
  }

  /// Complete physical description keeps equal-total compositions distinguishable.
  String compositionLabel(
    AppLocalizations l,
    ArchitectUnit unit, {
    bool includeCore = true,
  }) {
    if (system.isLog) {
      return '${system.kind.label(l)} · ${l.wallLogSize(architectWallLength(totalThickness, unit))}';
    }
    if (system.isSpecial) {
      return '${system.kind.label(l)} · ${resolvedLayers.map((layer) => l.wallMaterialThickness(layer.material.label(l), architectWallLength(layer.thickness, unit))).join(' + ')}'
          '${system.isPanel ? ' + ${l.wallMaterialThickness(l.wallSupportDepth, architectWallLength(system.supportDepth, unit))}' : ''}';
    }
    final layers = resolvedLayers.where(
      (layer) => includeCore || layer.role != ArchitectLayerRole.core,
    );
    if (layers.isEmpty) return l.wallNoInsulation;
    return layers
        .map(
          (layer) => l.wallMaterialThickness(
            layer.material.label(l),
            architectWallLength(layer.thickness, unit),
          ),
        )
        .join(' · ');
  }

  String catalogLabel(
    AppLocalizations l,
    ArchitectUnit unit, {
    bool grouped = false,
  }) {
    if (!isFactoryPreset && name.isNotEmpty) return name;
    if (isParapet) {
      final composition = compositionLabel(l, unit);
      return grouped ? composition : '${parapetFinishLabel(l)} · $composition';
    }
    return compositionLabel(l, unit, includeCore: !grouped);
  }

  String get _composition {
    String number(double value) => (value * 100)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    if (layers.any((l) => l.role == ArchitectLayerRole.finish)) {
      return number(totalThickness);
    }
    final core = number(brickThickness);
    return hasInsulation ? '$core+${number(insulationThickness)}' : core;
  }

  String compactLabel(AppLocalizations l10n) {
    if (system.isLog) return '${system.kind.label(l10n)} Ø$_composition';
    if (system.isSpecial) return '${system.kind.label(l10n)} $_composition';
    if (!isFactoryPreset && name.isNotEmpty) return name;
    if (layers.isNotEmpty) {
      if (isParapet) return l10n.architectWallParapetCode(_composition);
      if (layers
          .where((l) => l.role == ArchitectLayerRole.core)
          .every((l) => l.material == ArchitectMaterial.aeratedConcrete)) {
        return l10n.wallMaterialThickness(
          l10n.wallMaterialAeratedConcrete,
          _composition,
        );
      }
      if (layers
          .where((l) => l.role == ArchitectLayerRole.core)
          .every((l) => l.material == ArchitectMaterial.concrete)) {
        return l10n.architectWallConcreteCode(_composition);
      }
      return _composition;
    }
    return switch (labelId ?? id) {
      'ext_25_12_eps' || 'int_12_partition' || 'ext_25_brick' => _composition,
      'bearing_25_concrete' => l10n.architectWallConcreteCode(_composition),
      'parapet_12' => l10n.architectWallParapetCode(_composition),
      _ => name.isEmpty ? l10n.wallNewType : name,
    };
  }

  String pickerHelp(AppLocalizations l10n) {
    if (system.isSpecial) {
      return switch (system.kind) {
        ArchitectWallSystemKind.roundLogs => l10n.wallLogHelp,
        ArchitectWallSystemKind.studFrame => l10n.wallFrameHelp,
        _ => l10n.wallPanelHelp,
      };
    }
    final title = layers.isNotEmpty
        ? layers
              .firstWhere((l) => l.role == ArchitectLayerRole.core)
              .material
              .label(l10n)
        : switch (labelId ?? id) {
            'ext_25_12_eps' => l10n.architectWallExterior,
            'int_12_partition' => l10n.architectWallPartition,
            'ext_25_brick' => l10n.architectWallBrick,
            'bearing_25_concrete' => l10n.architectWallConcrete,
            'parapet_12' => l10n.architectWallParapet,
            _ => name.isEmpty ? l10n.wallNewType : name,
          };
    return l10n.architectWallTypeThicknessHint(title, _composition);
  }
}
