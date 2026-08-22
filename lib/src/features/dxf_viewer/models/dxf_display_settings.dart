import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Style options for displaying CAD point entities (DxfPoint).
enum DxfPointStyle {
  none(
    label: 'Hidden / Off',
    labelBg: 'Скрити',
    symbol: '—',
  ),
  dot(
    label: 'Filled Dot',
    labelBg: 'Плътна точка',
    symbol: '●',
  ),
  cross(
    label: 'Plus Cross',
    labelBg: 'Кръстче (+)',
    symbol: '+',
  ),
  xCross(
    label: 'Diagonal Cross',
    labelBg: 'Хикс (×)',
    symbol: '×',
  ),
  circle(
    label: 'Circle',
    labelBg: 'Окръжност (○)',
    symbol: '○',
  ),
  circleDot(
    label: 'Target Dot',
    labelBg: 'Точка в окръжност (⊙)',
    symbol: '⊙',
  );

  final String label;
  final String labelBg;
  final String symbol;

  const DxfPointStyle({
    required this.label,
    required this.labelBg,
    required this.symbol,
  });

  static DxfPointStyle fromName(String? name) {
    if (name == null) return DxfPointStyle.none;
    for (final style in DxfPointStyle.values) {
      if (style.name == name) return style;
    }
    return DxfPointStyle.none;
  }
}

/// User configurable visual settings for the CAD/DXF viewer.
class DxfDisplaySettings {
  final double lineThicknessScale; // 0.3 to 3.5 (default 1.0)
  final double measurementScale; // 0.5 to 2.5 (default 1.0)
  final double pointSize; // 1.0 to 12.0 in screen pixels (default 2.0)
  final DxfPointStyle pointStyle; // point marker style

  const DxfDisplaySettings({
    this.lineThicknessScale = 1.0,
    this.measurementScale = 1.4,
    this.pointSize = 2.0,
    this.pointStyle = DxfPointStyle.none,
  });

  DxfDisplaySettings copyWith({
    double? lineThicknessScale,
    double? measurementScale,
    double? pointSize,
    DxfPointStyle? pointStyle,
  }) {
    return DxfDisplaySettings(
      lineThicknessScale: lineThicknessScale ?? this.lineThicknessScale,
      measurementScale: measurementScale ?? this.measurementScale,
      pointSize: pointSize ?? this.pointSize,
      pointStyle: pointStyle ?? this.pointStyle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineThicknessScale': lineThicknessScale,
      'measurementScale': measurementScale,
      'pointSize': pointSize,
      'pointStyle': pointStyle.name,
    };
  }

  factory DxfDisplaySettings.fromMap(Map<String, dynamic> map) {
    return DxfDisplaySettings(
      lineThicknessScale: (map['lineThicknessScale'] as num?)?.toDouble() ?? 1.0,
      measurementScale: (map['measurementScale'] as num?)?.toDouble() ?? 1.4,
      pointSize: (map['pointSize'] as num?)?.toDouble() ?? 4.0,
      pointStyle: DxfPointStyle.fromName(map['pointStyle'] as String?),
    );
  }

  String toJson() => json.encode(toMap());

  factory DxfDisplaySettings.fromJson(String source) =>
      DxfDisplaySettings.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Service to persist and reactively broadcast CAD display settings.
class DxfDisplaySettingsService {
  static const String _keySettings = 'koto_dxf_display_settings';

  static final ValueNotifier<DxfDisplaySettings> settingsNotifier =
      ValueNotifier<DxfDisplaySettings>(const DxfDisplaySettings());

  static Future<void> init() async {
    final settings = await getSettings();
    settingsNotifier.value = settings;
  }

  static Future<DxfDisplaySettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySettings);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return DxfDisplaySettings.fromJson(jsonStr);
      }
    } catch (_) {}
    return const DxfDisplaySettings();
  }

  static Future<void> updateSettings(DxfDisplaySettings settings) async {
    settingsNotifier.value = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySettings, settings.toJson());
    } catch (_) {}
  }

  static Future<void> resetToDefaults() async {
    await updateSettings(const DxfDisplaySettings());
  }
}
