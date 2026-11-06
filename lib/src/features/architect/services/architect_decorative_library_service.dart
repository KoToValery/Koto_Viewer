// ============================================================================
// TABLE OF CONTENTS (grep: "=== SECTION:")
// 1. === SECTION: SERVICE INITIALIZATION & PERSISTENCE ===
// 2. === SECTION: CATALOG QUERIES & MUTATIONS ===
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_decorative_element.dart';

// === SECTION: SERVICE INITIALIZATION & PERSISTENCE ===

/// Central repository and library manager for standard and custom 3D decorative elements.
class ArchitectDecorativeLibraryService extends ChangeNotifier {
  static final ArchitectDecorativeLibraryService instance =
      ArchitectDecorativeLibraryService._internal();

  ArchitectDecorativeLibraryService._internal();
  @visibleForTesting
  ArchitectDecorativeLibraryService.forTesting();

  static const String _storageKey = 'architect_decorative_custom_elements_v1';

  final List<ArchitectDecorativeElement> _customElements = [];
  bool _isLoaded = false;
  Future<void>? _loading;

  late ArchitectDecorativeElement _activeTemplate =
      ArchitectDecorativeElement.standardCatalog().first;

  ArchitectDecorativeElement get activeTemplate => _activeTemplate;

  set activeTemplate(ArchitectDecorativeElement value) {
    _activeTemplate = value;
    notifyListeners();
  }

  Future<void> init() =>
      _isLoaded ? SynchronousFuture<void>(null) : (_loading ??= _load());

  Future<void> _load() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final list = jsonDecode(rawJson) as List<dynamic>;
        _customElements.clear();
        for (final item in list) {
          if (item is Map) {
            try {
              final el = ArchitectDecorativeElement.fromJson(
                Map<String, dynamic>.from(item),
              ).copyWith(isPreset: false);
              _customElements.add(el);
            } catch (e) {
              debugPrint('Failed to parse custom decorative element: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ArchitectDecorativeLibraryService init error: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  // === SECTION: CATALOG QUERIES & MUTATIONS ===

  List<ArchitectDecorativeElement> getAllTemplates() => [
    ...ArchitectDecorativeElement.standardCatalog(),
    ..._customElements,
  ];

  List<ArchitectDecorativeElement> get customTemplates =>
      List.unmodifiable(_customElements);

  Future<ArchitectDecorativeElement> saveTemplate(
    ArchitectDecorativeElement element,
  ) async {
    await init();
    final saved = element.copyWith(
      id: element.isPreset || element.id.startsWith('preset_')
          ? 'custom_decor_${DateTime.now().microsecondsSinceEpoch}'
          : element.id,
      isPreset: false,
    );
    final idx = _customElements.indexWhere((e) => e.id == saved.id);
    if (idx >= 0) {
      _customElements[idx] = saved;
    } else {
      _customElements.add(saved);
    }
    _activeTemplate = saved;
    await _persist();
    notifyListeners();
    return saved;
  }

  Future<void> deleteTemplate(String id) async {
    await init();
    _customElements.removeWhere((e) => e.id == id);
    if (_activeTemplate.id == id) {
      _activeTemplate = ArchitectDecorativeElement.standardCatalog().first;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_customElements.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
