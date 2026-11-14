import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

class SaveArchitectHatchPattern extends ArchitectModelCommand {
  final ArchitectHatchPattern pattern;
  const SaveArchitectHatchPattern(this.pattern);
  @override
  ArchitectProject apply(ArchitectProject project) {
    pattern.validate();
    if (pattern.isPreset) return project;
    return project.copyWith(
      hatchPatterns: [
        ...project.hatchPatterns.where((p) => p.id != pattern.id),
        pattern,
      ],
    );
  }
}

/// Removes a user-defined hatch pattern from a project; factory presets cannot be removed.
class DeleteArchitectHatchPattern extends ArchitectModelCommand {
  final String patternId;
  const DeleteArchitectHatchPattern(this.patternId);
  @override
  ArchitectProject apply(ArchitectProject project) {
    if (ArchitectHatchPattern.allPresets.any((p) => p.id == patternId)) {
      return project;
    }
    return project.copyWith(
      hatchPatterns: project.hatchPatterns
          .where((p) => p.id != patternId)
          .toList(),
    );
  }
}

/// Global storage for user custom hatch patterns across projects.
class ArchitectHatchPatternLibrary {
  static const storageKey = 'architect_hatch_patterns_v1';

  static Future<List<ArchitectHatchPattern>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(storageKey);
    if (data == null) return [];
    final result = <ArchitectHatchPattern>[];
    try {
      for (final entry in jsonDecode(data) as List) {
        try {
          final p = ArchitectHatchPattern.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          if (!p.isPreset) result.add(p);
        } on Object {
          /* Ignore damaged pattern. */
        }
      }
    } on Object {
      /* Ignore damaged pattern catalog. */
    }
    return result;
  }

  static Future<bool> save(ArchitectHatchPattern pattern) async {
    if (pattern.isPreset) return false;
    pattern.validate();
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode([
        ...entries.where((p) => p.id != pattern.id).map((p) => p.toJson()),
        pattern.toJson(),
      ]),
    );
  }

  static Future<bool> delete(String id) async {
    if (ArchitectHatchPattern.allPresets.any((p) => p.id == id)) return false;
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode(
        entries.where((p) => p.id != id).map((p) => p.toJson()).toList(),
      ),
    );
  }
}
