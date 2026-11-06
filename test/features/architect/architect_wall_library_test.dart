import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_bg.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_library.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_type_label.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart'
    show ArchitectUnit;

void main() {
  test(
    '17 complete generic templates validate and preserve exact build-ups',
    () {
      final expected = <String, double>{
        'factory_brick_120': .15,
        'factory_brick_250': .28,
        'factory_aerated_100': .13,
        'factory_aerated_150': .18,
        'factory_concrete_200': .23,
        'factory_concrete_250': .28,
        'factory_stud_100': .10,
        'factory_stud_150': .15,
        'factory_brick_250_eps_120': .39,
        'factory_brick_250_eps_150': .42,
        'factory_brick_250_wool_150': .42,
        'factory_aerated_250_wool_120': .39,
        'factory_concrete_200_wool_150': .37,
        'factory_sandwich_100': .20,
        'factory_sandwich_150': .25,
        'factory_logs_200': .20,
        'factory_logs_240': .24,
      };
      expect(ArchitectWallLibrary.presets, hasLength(17));
      expect(
        ArchitectWallLibrary.templates.map((t) => t.family).toSet(),
        hasLength(10),
      );
      for (final type in ArchitectWallLibrary.presets) {
        ArchitectMaterialLayer.validate(type.layers);
        type.system.validate(type.totalThickness);
        expect(type.name, isEmpty);
        expect(
          type.totalThickness,
          closeTo(expected[type.id]!, 1e-12),
          reason: type.id,
        );
        final restored = ArchitectWallType.fromJson(
          jsonDecode(jsonEncode(type.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), type.toJson());
        expect(
          () => type.layers.add(type.layers.first),
          throwsUnsupportedError,
        );
      }
      expect(
        () => ArchitectWallLibrary.presets.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'framing insulation occupies its core and sandwich depth includes supports',
    () {
      final stud = ArchitectWallLibrary.presets.firstWhere(
        (t) => t.id == 'factory_stud_150',
      );
      expect(
        stud.layers.where((l) => l.material == ArchitectMaterial.plasterboard),
        hasLength(4),
      );
      expect(stud.brickThickness, .10);
      expect(stud.system.insulationDepth, .10);
      expect(
        stud.layers.where((l) => l.role == ArchitectLayerRole.insulation),
        isEmpty,
      );
      final panel = ArchitectWallLibrary.presets.firstWhere(
        (t) => t.id == 'factory_sandwich_100',
      );
      expect(
        panel.layers.fold<double>(0, (sum, l) => sum + l.thickness),
        closeTo(.10, 1e-12),
      );
      expect(panel.system.supportDepth, .10);
      expect(panel.totalThickness, closeTo(.20, 1e-12));
    },
  );

  test(
    'saved project definitions win without mutation and all rail systems are available',
    () {
      final original = ArchitectWallLibrary.presets.first;
      final saved = original.copyWith(
        name: 'My wall',
        layers: [
          for (final layer in original.layers)
            layer.role == ArchitectLayerRole.core
                ? layer.copyWith(thickness: .18)
                : layer,
        ],
      );
      final before = jsonEncode(saved.toJson());
      final available = ArchitectWallLibrary.available([saved]);
      expect(available.where((t) => t.id == saved.id).single, same(saved));
      expect(jsonEncode(saved.toJson()), before);
      expect(available.where((t) => t.railing != null), hasLength(6));
      expect(available.any((t) => t.id == 'ext_25_brick'), isFalse);
      expect(
        ArchitectWallLibrary.available([]).any((t) => t.id == 'ext_25_brick'),
        isTrue,
      );
      expect(available.map((t) => t.id).toSet().length, available.length);
      expect(() => available.clear(), throwsUnsupportedError);
      final local = saved.copyWith(id: 'local-only', isCatalogType: false);
      expect(
        ArchitectWallLibrary.available([
          saved,
          local,
        ]).any((type) => type.id == local.id),
        isFalse,
      );
    },
  );

  test(
    'factory metadata does not misclassify repurposed IDs or translated labels',
    () {
      final factory = ArchitectWallLibrary.presets.first;
      final renamed = factory.copyWith(name: 'Different language');
      expect(
        ArchitectWallLibrary.descriptorFor(renamed)!.family,
        ArchitectWallFamily.brick,
      );
      final changedMaterial = factory.copyWith(
        layers: [
          for (final layer in factory.layers)
            layer.role == ArchitectLayerRole.core
                ? layer.copyWith(material: ArchitectMaterial.concrete)
                : layer,
        ],
      );
      expect(ArchitectWallLibrary.descriptorFor(changedMaterial), isNull);
      final bg = AppLocalizationsBg(), en = AppLocalizationsEn();
      expect(factory.catalogGroupLabel(bg, ArchitectUnit.centimeters), 'Тухла');
      expect(factory.catalogGroupLabel(en, ArchitectUnit.centimeters), 'Brick');
      expect(
        factory.catalogLabel(en, ArchitectUnit.centimeters),
        'Brick · 12 cm',
      );
      expect(
        renamed.catalogLabel(en, ArchitectUnit.centimeters),
        'Different language',
      );
      for (final type in ArchitectWallLibrary.available([])) {
        for (final l in [bg, en]) {
          expect(type.catalogLabel(l, ArchitectUnit.centimeters), isNotEmpty);
          expect(
            type.catalogGroupLabel(l, ArchitectUnit.centimeters),
            isNotEmpty,
          );
          expect(
            type.compositionLabel(l, ArchitectUnit.centimeters),
            isNotEmpty,
          );
          expect(type.compactLabel(l), isNotEmpty);
          expect(type.pickerHelp(l), isNotEmpty);
        }
      }
    },
  );
}
