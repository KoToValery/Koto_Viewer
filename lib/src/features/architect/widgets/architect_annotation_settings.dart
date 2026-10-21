import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_drawing_publisher.dart';

Future<void> showArchitectAnnotationSettings(
  BuildContext context,
  ArchitectCommandController controller,
  ArchitectSavedDrawing drawing,
  int scale,
) async {
  final l = context.l10n;
  var role = ArchitectAnnotationRole.dimension;
  String? element;
  final scene = ArchitectDrawingPublisher.build(
    controller.project,
    drawing,
    scale,
    l,
  );
  final annotations = <String, String>{};
  for (final op in scene.operations.whereType<ArchitectVectorText>()) {
    if (op.sources.length == 1) annotations[op.sources.single] = op.text;
  }
  final input = TextEditingController();
  bool invalid = false;
  void load() => input.text = controller.project.document
      .textMm(drawing.sourceKey, element ?? '', role, scale)
      .toStringAsFixed(2);
  load();
  String label(ArchitectAnnotationRole value) => switch (value) {
    ArchitectAnnotationRole.ordinary => l.architectAnnotationOrdinary,
    ArchitectAnnotationRole.dimension => l.architectAnnotationDimension,
    ArchitectAnnotationRole.area => l.architectAnnotationArea,
    ArchitectAnnotationRole.roomName => l.architectAnnotationRoomName,
    ArchitectAnnotationRole.title => l.architectAnnotationTitle,
    ArchitectAnnotationRole.table => l.architectAnnotationTable,
    ArchitectAnnotationRole.symbol => l.architectAnnotationSymbol,
  };
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) {
        void save({bool reset = false}) {
          final value = double.tryParse(input.text.replaceAll(',', '.'));
          if (!reset && (value == null || !value.isFinite || value <= 0)) {
            update(() => invalid = true);
            return;
          }
          final doc = controller.project.document;
          final sizes = Map<String, double>.from(
            element == null ? doc.profileMm : doc.overrideMm,
          );
          final key = element == null
              ? '$scale/${role.name}'
              : '${drawing.sourceKey}/$element/${role.name}/$scale';
          if (reset) {
            sizes.remove(key);
          } else {
            sizes[key] = value!;
          }
          controller.commit(
            controller.project.copyWith(
              document: element == null
                  ? doc.copyWith(profileMm: sizes)
                  : doc.copyWith(overrideMm: sizes),
            ),
          );
          update(() {
            invalid = false;
            load();
          });
        }

        return AlertDialog(
          title: Text('${l.architectAnnotationSettings} · 1:$scale'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: element ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.architectAnnotationElement,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l.architectAnnotationProfile),
                      ),
                      for (final e in annotations.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      element = v == '' ? null : v;
                      load();
                    }),
                  ),
                  DropdownButtonFormField<ArchitectAnnotationRole>(
                    initialValue: role,
                    items: [
                      for (final value in ArchitectAnnotationRole.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(label(value)),
                        ),
                    ],
                    onChanged: (v) => update(() {
                      role = v!;
                      load();
                    }),
                  ),
                  TextField(
                    controller: input,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.architectAnnotationSize,
                      errorText: invalid ? l.architectSheetInvalid : null,
                    ),
                  ),
                  TextButton(
                    onPressed: () => save(reset: true),
                    child: Text(l.architectAnnotationReset),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(l.architectSheetCancel),
            ),
            FilledButton(
              onPressed: () => save(),
              child: Text(l.architectSheetSave),
            ),
          ],
        );
      },
    ),
  );
  input.dispose();
}
