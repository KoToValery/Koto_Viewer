import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared core cannot depend on native feature implementations', () {
    final root = Directory('lib/src/features/bim_editing');
    final directives = RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''');
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in directives.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:') ||
            (uri.startsWith('package:') &&
                !uri.startsWith('package:kotoview/'))) {
          continue;
        }
        final resolved = uri.startsWith('package:kotoview/')
            ? File(
                'lib/${uri.substring('package:kotoview/'.length)}',
              ).absolute.uri
            : file.absolute.uri.resolve(uri);
        final path = resolved.path;
        expect(
          path.contains('/features/') &&
              !path.contains('/features/bim_editing/'),
          isFalse,
          reason: '${file.path} imports a native feature: $uri',
        );
      }
    }
  });

  test(
    'shared edits and Undo preserve independent native model files',
    () async {
      final directory = await Directory.systemTemp.createTemp('bim_models_');
      addTearDown(() => directory.delete(recursive: true));
      final library = BimProjectLibraryService(customRootDir: directory);
      const structural = StructuralProject(
        title: 'Construction',
        storeys: [
          StoreyLevel(
            id: 'floor',
            name: 'Floor',
            elevation: 0,
            columns: [StructuralColumn(id: 'column', center: Offset(1, 2))],
          ),
        ],
      );
      final architect = ArchitectProject(
        id: 'separate',
        name: 'Architect',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        activeStoreyId: 'floor',
        storeys: const [
          ArchitectStorey(
            id: 'floor',
            name: 'Floor',
            columns: [ArchitectColumn(id: 'column', position: Offset(1, 2))],
          ),
        ],
      );
      expect(
        await library.saveStructuralProject('separate', structural),
        isTrue,
      );
      expect(await library.saveArchitectProject('separate', architect), isTrue);
      final projectDirectory = await library.getProjectDirectory('separate');
      final structuralFile = File('${projectDirectory.path}/structural.json');
      final architectFile = File('${projectDirectory.path}/architectural.json');
      final originalStructuralBytes = await structuralFile.readAsBytes();
      final commands = ArchitectCommandController(architect);
      addTearDown(commands.dispose);
      commands.execute(
        const MoveArchitectElement(
          storeyId: 'floor',
          elementId: 'column',
          delta: Offset(3, -1),
        ),
      );
      expect(
        commands.project.activeStorey.columns.single.position,
        const Offset(4, 1),
      );
      expect(
        await library.saveArchitectProject('separate', commands.project),
        isTrue,
      );
      expect(await structuralFile.readAsBytes(), originalStructuralBytes);
      commands.undo();
      expect(
        commands.project.activeStorey.columns.single.position,
        const Offset(1, 2),
      );
      final architectBytes = await architectFile.readAsBytes();
      expect(
        await library.saveStructuralProject(
          'separate',
          structural.copyWith(title: 'Changed construction'),
        ),
        isTrue,
      );
      expect(await architectFile.readAsBytes(), architectBytes);
      final restored = await library.loadArchitectProject('separate');
      expect(
        restored!.activeStorey.columns.single.position,
        const Offset(4, 1),
      );
      expect(
        jsonDecode(await structuralFile.readAsString())['title'],
        'Changed construction',
      );
    },
  );
}
