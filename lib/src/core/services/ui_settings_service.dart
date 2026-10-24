import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/bim_editing/models/bim_context_menu_settings.dart';

class UiSettingsService {
  static const preferenceKey = 'koto_ui_context_menu_v1';
  static final contextMenu = ValueNotifier<BimContextMenuSettings>(
    const BimContextMenuSettings(),
  );
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(preferenceKey);
      contextMenu.value = raw == null
          ? const BimContextMenuSettings()
          : BimContextMenuSettings.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
    } catch (_) {
      contextMenu.value = const BimContextMenuSettings();
    }
  }

  static Future<void> save(BimContextMenuSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(preferenceKey, jsonEncode(settings.toJson()))) {
      throw StateError('UI settings could not be saved');
    }
    contextMenu.value = settings;
  }
}
