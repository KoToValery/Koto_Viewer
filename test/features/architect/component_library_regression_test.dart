import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/components/dsl/parametric_script_parser.dart';
import 'package:kotoview/src/features/architect/models/architect_component_definition.dart';
import 'package:kotoview/src/features/architect/models/component_dimensions.dart';
import 'package:kotoview/src/features/architect/services/component_geometry_cache.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';

String objectScript(String id, {double width = 1, String type = 'box'}) =>
    jsonEncode({
      'id': id,
      'name': 'Test object',
      'category': 'equipment',
      'defaultParams': {
        'width': width,
        'depth': .6,
        'height': .8,
        'panel': .04,
      },
      'solids': [
        {
          'type': type,
          'size': ['width', 'depth', 'height - (panel * 2)'],
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ComponentLibraryService.instance.init();
  });

  test(
    'Expressions preserve parentheses, associativity, signs and identifiers',
    () {
      const vars = {'width': 2.0, 'widthExtra': .4, 'depth': .8};
      final expressions = {
        '(width - .2) / 2': .9,
        'width/2 - .04': .96,
        'width * -depth': -1.6,
        '-(width + depth) / 2': -1.4,
        'widthExtra + width': 2.4,
        '8/2*2': 8.0,
        '1e-3 + .2': .201,
      };
      for (final entry in expressions.entries) {
        expect(
          SimpleMathEvaluator.evaluate(entry.key, vars),
          closeTo(entry.value, 1e-10),
          reason: entry.key,
        );
      }
      for (final invalid in [
        'width + typo',
        '(width',
        'width/0',
        'width junk',
        '',
        '1e999',
      ]) {
        expect(
          () => SimpleMathEvaluator.evaluate(invalid, vars),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test(
    'Imported code validates geometry and retains extra default parameters',
    () {
      final def = ParametricScriptParser.parse(objectScript('test_parser'));
      final geo = def.generateGeometry({'width': 1.4});
      expect(geo.mesh3d.bounds.min.x, closeTo(-.7, 1e-9));
      expect(geo.mesh3d.bounds.max.z, closeTo(.72, 1e-9));
      expect(def.defaultParameters['panel'], .04);
      expect(
        () => ParametricScriptParser.parse(
          objectScript('invalid', type: 'unsupported'),
        ),
        throwsFormatException,
      );
      expect(
        () => ParametricScriptParser.parse(objectScript('negative', width: -1)),
        throwsFormatException,
      );
    },
  );

  test('Cylinder normals face outward and its plan is a circle', () {
    final builder = ParametricSolidBuilder(width: 1, depth: 1, height: 1);
    builder.addCylinder(
      center: const Offset(0, .5),
      radius: .5,
      cylinderHeight: 1,
    );
    final geo = builder.build('Cylinder');
    for (final t in geo.mesh3d.triangles.where((t) => t.normal.z.abs() < .1)) {
      final c = t.centroid;
      expect(t.normal.x * c.x + t.normal.y * (c.y - .5), greaterThan(0));
    }
    expect(geo.block2d.boundsMask.contains(const Offset(.49, .01)), isFalse);
    expect(geo.block2d.boundsMask.contains(const Offset(0, .5)), isTrue);
  });

  test('Basin has an open cavity, watertight shell and real footprint', () {
    final builder = ParametricSolidBuilder(width: .6, depth: .45, height: .18);
    builder.addBasin(
      center: const Offset(0, .225),
      basinWidth: .6,
      basinDepth: .45,
      basinHeight: .18,
    );
    final geo = builder.build('Basin');
    // No horizontal top triangle spans the centre; only the rim is at the top.
    for (final t in geo.mesh3d.triangles.where(
      (t) =>
          (t.v0.z - .18).abs() < 1e-9 &&
          (t.v1.z - .18).abs() < 1e-9 &&
          (t.v2.z - .18).abs() < 1e-9,
    )) {
      final path = Path()
        ..addPolygon([
          Offset(t.v0.x, t.v0.y),
          Offset(t.v1.x, t.v1.y),
          Offset(t.v2.x, t.v2.y),
        ], true);
      expect(path.contains(const Offset(0, .225)), isFalse);
    }
    final edges = <String, int>{};
    String point(dynamic v) =>
        '${v.x.toStringAsFixed(8)},${v.y.toStringAsFixed(8)},${v.z.toStringAsFixed(8)}';
    for (final t in geo.mesh3d.triangles) {
      for (final pair in [(t.v0, t.v1), (t.v1, t.v2), (t.v2, t.v0)]) {
        final endpoints = [point(pair.$1), point(pair.$2)]..sort();
        final key = endpoints.join('|');
        edges.update(key, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    expect(edges.values.every((v) => v == 2), isTrue);
  });

  test('Typed resize preserves XYZ proportions and rejects invalid values', () {
    const original = {'width': 1.8, 'depth': 2.0, 'height': .95, 'panel': .04};
    final scaled = resizeComponentDimensions(
      original,
      'width',
      .9,
      lockRatio: true,
    );
    expect(scaled['depth'], 1.0);
    expect(scaled['height'], .475);
    expect(scaled['panel'], .04);
    final independent = resizeComponentDimensions(
      original,
      'depth',
      2.3,
      lockRatio: false,
    );
    expect(independent['width'], 1.8);
    expect(independent['depth'], 2.3);
    for (final value in [0.0, -1.0, double.nan, double.infinity, 101.0]) {
      expect(
        () => resizeComponentDimensions(
          original,
          'width',
          value,
          lockRatio: true,
        ),
        throwsFormatException,
      );
    }
    expect(original['width'], 1.8);
  });

  test(
    'Selection survives reads and unknown IDs never substitute another model',
    () {
      final library = ComponentLibraryService.instance;
      final bed = library.findDefinition('furniture_bed_double')!;
      library.setActiveDefinition(bed, parameters: {'width': 1.6});
      library.getAllDefinitions();
      expect(library.activeDefinition.id, bed.id);
      expect(library.activeParameters['width'], 1.6);
      expect(library.activeParameters['depth'], 2.0);
      expect(library.findDefinition('missing'), isNull);
      expect(
        () => library.activeParameters['width'] = 3,
        throwsUnsupportedError,
      );
      library.setActiveDefinition(bed);
      expect(library.activeParameters['width'], 1.8);
    },
  );

  test('Catalog geometry matches its declared overall dimensions', () {
    final mismatches = <String>[];
    for (final d in ComponentLibraryService.instance.getAllDefinitions()) {
      final p = d.defaultParameters;
      final mesh = d.generateGeometry(p).mesh3d.bounds;
      final spans = [
        mesh.max.x - mesh.min.x,
        mesh.max.y - mesh.min.y,
        mesh.max.z - mesh.min.z,
      ];
      const keys = ['width', 'depth', 'height'];
      for (var i = 0; i < keys.length; i++) {
        if ((spans[i] - (p[keys[i]] as num)).abs() > .001) {
          mismatches.add('${d.id} ${keys[i]}: ${spans[i]} vs ${p[keys[i]]}');
        }
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.join('\n'));
  });

  test(
    'Resized user objects retain their geometry through JSON export and import',
    () {
      final definition = ParametricScriptParser.parse(
        objectScript('scaled_json'),
      );
      final parameters = resizeComponentDimensions(
        definition.defaultParameters,
        'width',
        2,
        lockRatio: true,
      );
      final expected = definition.resolveGeometry(parameters);
      final data = jsonDecode(definition.rawSourceJson) as Map<String, dynamic>;
      data['defaultParams'] = parameters;
      final imported = ParametricScriptParser.parse(jsonEncode(data));
      final actual = imported.resolveGeometry(imported.defaultParameters);
      expect(actual.mesh3d.bounds.max.x, expected.mesh3d.bounds.max.x);
      expect(actual.mesh3d.bounds.max.z, expected.mesh3d.bounds.max.z);
      expect(actual.block2d.bounds, expected.block2d.bounds);
    },
  );

  test('Locked resizing scales every 3D vertex and the 2D block together', () {
    final bed = ComponentLibraryService.instance.findDefinition(
      'furniture_bed_double',
    )!;
    final original = bed.resolveGeometry(bed.defaultParameters);
    final resized = resizeComponentDimensions(
      bed.defaultParameters,
      'width',
      .9,
      lockRatio: true,
    );
    final result = bed.resolveGeometry(resized);
    for (var i = 0; i < original.mesh3d.triangles.length; i++) {
      final before = original.mesh3d.triangles[i];
      final after = result.mesh3d.triangles[i];
      expect(after.v0.x, closeTo(before.v0.x / 2, 1e-10));
      expect(after.v0.y, closeTo(before.v0.y / 2, 1e-10));
      expect(after.v0.z, closeTo(before.v0.z / 2, 1e-10));
    }
    expect(result.mesh3d.bounds.max.z, .475);
    expect(result.block2d.bounds.height, 1.0);
    final expanded = resizeComponentDimensions(
      resized,
      'height',
      .95,
      lockRatio: true,
    );
    expect(bed.resolveGeometry(expanded).mesh3d.bounds.max.z, .95);
  });

  test(
    'Legacy table and countertop IDs remain available outside the new catalog',
    () {
      final library = ComponentLibraryService.instance;
      for (final id in [
        'furniture_dining_table',
        'sanitary_washbasin_cabinet',
        'kitchen_sink_cabinet',
      ]) {
        expect(library.findDefinition(id), isNotNull);
        expect(library.getAllDefinitions().any((d) => d.id == id), isFalse);
      }
    },
  );

  test(
    'Saving edited code invalidates geometry and persists the same ID',
    () async {
      final library = ComponentLibraryService.instance;
      final cache = ComponentGeometryCache.instance;
      await library.saveCustomScript(objectScript('edit_test'));
      final first = library.findDefinition('edit_test')!;
      final geometry = cache.getOrCompute(first, first.defaultParameters);
      await library.saveCustomScript(objectScript('edit_test', width: 1.8));
      final edited = library.findDefinition('edit_test')!;
      final regenerated = cache.getOrCompute(edited, edited.defaultParameters);
      expect(identical(geometry, regenerated), isFalse);
      expect(
        regenerated.mesh3d.bounds.max.x - regenerated.mesh3d.bounds.min.x,
        closeTo(1.8, 1e-9),
      );
      final prefs = await SharedPreferences.getInstance();
      final scripts = prefs.getStringList(
        'architect_component_custom_scripts_v1',
      )!;
      expect(
        scripts
            .where((s) => (jsonDecode(s) as Map)['id'] == 'edit_test')
            .length,
        1,
      );
      await expectLater(
        library.saveCustomScript(objectScript('furniture_sofa')),
        throwsFormatException,
      );
      await library.deleteCustomScript('edit_test');
      expect(library.findDefinition('edit_test'), isNull);
    },
  );
}
