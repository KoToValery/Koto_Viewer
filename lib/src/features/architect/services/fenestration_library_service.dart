// === SECTION: ARCHITECTURAL FENESTRATION LIBRARY SERVICE ===
// Table of Contents:
// 1. SERVICE INITIALIZATION & SHARED PREFERENCES PERSISTENCE
// 2. QUERY & FILTER METHODS (Windows, Doors, Custom Styles)
// 3. MUTATION METHODS (Save, Update, Delete)
// 4. ACTIVE SELECTION STATE

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_fenestration_style.dart';

/// Central repository and library manager for standard and custom fenestration opening models.
class FenestrationLibraryService extends ChangeNotifier {
  static final FenestrationLibraryService instance =
      FenestrationLibraryService._internal();

  FenestrationLibraryService._internal();
  @visibleForTesting
  FenestrationLibraryService.forTesting();

  static const String _storageKey = 'architect_fenestration_custom_styles_v1';

  final List<ArchitectFenestrationStyle> _customStyles = [];
  bool _isLoaded = false;
  Future<void>? _loading;

  late ArchitectFenestrationStyle _activeWindowStyle;
  late ArchitectFenestrationStyle _activeDoorStyle;

  ArchitectFenestrationStyle get activeWindowStyle {
    if (!_isLoaded) _initDefaults();
    return _activeWindowStyle;
  }

  ArchitectFenestrationStyle get activeDoorStyle {
    if (!_isLoaded) _initDefaults();
    return _activeDoorStyle;
  }

  void _initDefaults() {
    final catalog = ArchitectFenestrationStyle.standardCatalog();
    _activeWindowStyle = catalog.firstWhere(
      (s) => s.id == 'win_double_casement',
      orElse: () => catalog.first,
    );
    _activeDoorStyle = catalog.firstWhere(
      (s) => s.id == 'door_interior_standard',
      orElse: () => catalog.last,
    );
  }

  /// Initializes the service and loads custom models from persistent storage.
  Future<void> init() =>
      _isLoaded ? SynchronousFuture<void>(null) : (_loading ??= _load());

  Future<void> _load() async {
    if (_isLoaded) return;
    _initDefaults();
    var repaired = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
        _customStyles.clear();
        for (final item in list) {
          try {
            var style = ArchitectFenestrationStyle.fromJson(
              item as Map<String, dynamic>,
            );
            if (style.isPreset || _customStyles.any((s) => s.id == style.id)) {
              style = style.copyWith(id: _newId());
              repaired = true;
            }
            _customStyles.add(style);
          } catch (e) {
            debugPrint('Failed to parse saved fenestration style: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('FenestrationLibraryService init error: $e');
    }

    _isLoaded = true;
    // Persist repaired identities so they remain stable across sessions.
    if (repaired) {
      try {
        await _persist();
      } catch (e) {
        debugPrint('Identity repair persistence failed: $e');
      }
    }
    notifyListeners();
  }

  /// All available styles (standard built-in presets followed by user custom styles).
  List<ArchitectFenestrationStyle> getAllStyles() {
    if (!_isLoaded) _initDefaults();
    return [...ArchitectFenestrationStyle.standardCatalog(), ..._customStyles];
  }

  /// Only window styles.
  List<ArchitectFenestrationStyle> getWindowStyles() {
    return getAllStyles()
        .where((s) => s.kind == FenestrationKind.window)
        .toList();
  }

  /// Only door styles.
  List<ArchitectFenestrationStyle> getDoorStyles() {
    return getAllStyles()
        .where((s) => s.kind == FenestrationKind.door)
        .toList();
  }

  /// Styles filtered by kind (doors or windows).
  List<ArchitectFenestrationStyle> getStylesForKind(FenestrationKind kind) {
    return kind == FenestrationKind.door ? getDoorStyles() : getWindowStyles();
  }

  /// Looks up a style by ID.
  ArchitectFenestrationStyle? getStyleById(String id) {
    return getAllStyles().where((s) => s.id == id).firstOrNull;
  }

  /// Saves or updates a custom style in the internal library and persists to storage.
  static int _serial = 0;
  static String _newId() =>
      'custom_${DateTime.now().microsecondsSinceEpoch}_${_serial++}';

  Future<ArchitectFenestrationStyle> saveStyle(
    ArchitectFenestrationStyle style,
  ) async {
    await init();
    if (style.isPreset) style = style.copyWith(id: _newId());
    final previous = List<ArchitectFenestrationStyle>.of(_customStyles);
    final idx = _customStyles.indexWhere((s) => s.id == style.id);
    if (idx >= 0) {
      _customStyles[idx] = style;
    } else {
      _customStyles.add(style);
    }

    try {
      await _persist();
    } catch (_) {
      _customStyles
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    if (style.kind == FenestrationKind.window) {
      _activeWindowStyle = style;
    } else {
      _activeDoorStyle = style;
    }

    notifyListeners();
    return style;
  }

  /// Deletes a custom style from the library.
  Future<bool> deleteStyle(String id) async {
    await init();
    if (ArchitectFenestrationStyle.standardCatalog().any((s) => s.id == id)) {
      return false;
    }
    _customStyles.removeWhere((s) => s.id == id);
    if (_activeWindowStyle.id == id) {
      _activeWindowStyle = getWindowStyles().first;
    }
    if (_activeDoorStyle.id == id) {
      _activeDoorStyle = getDoorStyles().first;
    }
    await _persist();
    notifyListeners();
    return true;
  }

  void setActiveWindowStyle(ArchitectFenestrationStyle style) {
    _activeWindowStyle = style;
    notifyListeners();
  }

  void setActiveDoorStyle(ArchitectFenestrationStyle style) {
    _activeDoorStyle = style;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customStyles.map((s) => s.toJson()).toList();
      if (!await prefs.setString(_storageKey, jsonEncode(list))) {
        throw StateError('Could not persist fenestration library');
      }
    } catch (e) {
      debugPrint('Failed to persist fenestration styles: $e');
      rethrow;
    }
  }
}
