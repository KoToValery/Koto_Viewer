import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a language option in the application language picker.
class LanguageOption {
  final String? languageCode; // null indicates system default
  final String nativeName;
  final String englishName;
  final String flag;

  const LanguageOption({
    required this.languageCode,
    required this.nativeName,
    required this.englishName,
    required this.flag,
  });
}

/// Service for managing application localization state and persistence.
class LocaleService {
  LocaleService._();

  static const String _keySelectedLocale = 'koto_selected_locale';

  /// Supported languages registry for the UI picker.
  /// Adding a new language to the app only requires adding its ARB file and an entry here!
  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      languageCode: null,
      nativeName: 'Системен по подразбиране',
      englishName: 'System Default',
      flag: '🌐',
    ),
    LanguageOption(
      languageCode: 'bg',
      nativeName: 'Български',
      englishName: 'Bulgarian',
      flag: '🇧🇬',
    ),
    LanguageOption(
      languageCode: 'en',
      nativeName: 'English',
      englishName: 'English',
      flag: '🇬🇧',
    ),
  ];

  static final ValueNotifier<Locale?> currentLocaleNotifier = ValueNotifier<Locale?>(null);

  /// Initializes the locale service by reading saved preference.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_keySelectedLocale);

      if (savedCode != null && savedCode.isNotEmpty && savedCode != 'system') {
        currentLocaleNotifier.value = Locale(savedCode);
      } else {
        currentLocaleNotifier.value = null; // System default
      }
    } catch (_) {
      currentLocaleNotifier.value = null;
    }
  }

  /// Sets and persists the active locale (pass null for system default).
  static Future<void> setLocale(Locale? locale) async {
    currentLocaleNotifier.value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.setString(_keySelectedLocale, 'system');
      } else {
        await prefs.setString(_keySelectedLocale, locale.languageCode);
      }
    } catch (_) {}
  }

  /// Returns whether the specified language code is currently active.
  static bool isCurrentLocale(String? languageCode) {
    final current = currentLocaleNotifier.value;
    if (languageCode == null) {
      return current == null;
    }
    return current?.languageCode == languageCode;
  }
}
