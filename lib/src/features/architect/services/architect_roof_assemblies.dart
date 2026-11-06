// === SECTION: ARCHITECT ROOF ASSEMBLIES & LIBRARY ===
// Table of Contents:
// 1. ARCHITECT ROOF LIBRARY PERSISTENCE (load, save, delete)

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_roof.dart';
import 'architect_element_id.dart';

/// Persistent user library for custom roof build-ups and layer assemblies.
class ArchitectRoofLibrary {
  static const storageKey = 'architect_roof_assemblies_v1';

  /// Loads custom roof build-ups from local storage.
  static Future<List<ArchitectRoofAssembly>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(storageKey);
    if (data == null) return [];
    final result = <ArchitectRoofAssembly>[];
    try {
      for (final entry in jsonDecode(data) as List) {
        try {
          final a = ArchitectRoofAssembly.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          result.add(a);
        } on Object {
          /* A corrupt library entry must not hide valid entries. */
        }
      }
    } on Object {
      return [];
    }
    return result;
  }

  /// Saves a custom roof build-up to the library.
  static Future<bool> save(ArchitectRoofAssembly assembly) async {
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    final id = assembly.id.isNotEmpty
        ? assembly.id
        : ArchitectElementId.next('roof_assembly');
    final toSave = assembly.copyWith(id: id);
    return prefs.setString(
      storageKey,
      jsonEncode([
        ...entries.where((a) => a.id != toSave.id).map((a) => a.toJson()),
        toSave.toJson(),
      ]),
    );
  }

  /// Deletes a custom roof build-up from the library by ID.
  static Future<bool> delete(String id) async {
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode(
        entries.where((a) => a.id != id).map((a) => a.toJson()).toList(),
      ),
    );
  }
}
