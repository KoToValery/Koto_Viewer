import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_line_style.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

/// Adds a reusable project pattern without changing already drawn elements.
class SaveArchitectLineStyle extends ArchitectModelCommand {
  final ArchitectLineStyle style;
  const SaveArchitectLineStyle(this.style);
  @override
  ArchitectProject apply(ArchitectProject project) {
    style.validate();
    if (style.isPreset) return project;
    return project.copyWith(
      lineStyles: [...project.lineStyles.where((s) => s.id != style.id), style],
    );
  }
}

/// Removes a custom line style from the project patterns.
class DeleteArchitectLineStyle extends ArchitectModelCommand {
  final String styleId;
  const DeleteArchitectLineStyle(this.styleId);
  @override
  ArchitectProject apply(ArchitectProject project) {
    return project.copyWith(
      lineStyles: project.lineStyles.where((s) => s.id != styleId).toList(),
    );
  }
}

/// Global storage for user custom line patterns across projects.
class ArchitectLineStyleLibrary {
  static const storageKey = 'architect_line_styles_v1';

  static Future<List<ArchitectLineStyle>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(storageKey);
    if (data == null) return [];
    final result = <ArchitectLineStyle>[];
    try {
      for (final entry in jsonDecode(data) as List) {
        try {
          final s = ArchitectLineStyle.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          if (!s.isPreset) result.add(s);
        } on Object { /* Ignore damaged style */ }
      }
    } on Object { /* Ignore damaged style */ }
    return result;
  }

  static Future<bool> save(ArchitectLineStyle style) async {
    if (style.isPreset) return false;
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode([
        ...entries.where((s) => s.id != style.id).map((s) => s.toJson()),
        style.toJson(),
      ]),
    );
  }

  static Future<bool> delete(String id) async {
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode(
        entries.where((s) => s.id != id).map((s) => s.toJson()).toList(),
      ),
    );
  }
}
