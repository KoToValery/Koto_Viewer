import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dxf_models.dart';

/// Style options for displaying CAD point entities (DxfPoint).
enum DxfPointStyle {
  none(
    label: 'Hidden / Off',
    symbol: '—',
  ),
  dot(
    label: 'Filled Dot',
    symbol: '●',
  ),
  cross(
    label: 'Plus Cross',
    symbol: '+',
  ),
  xCross(
    label: 'Diagonal Cross',
    symbol: '×',
  ),
  circle(
    label: 'Circle',
    symbol: '○',
  ),
  circleDot(
    label: 'Target Dot',
    symbol: '⊙',
  );

  final String label;
  final String symbol;

  const DxfPointStyle({
    required this.label,
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
  final double linetypeScale; // 0.3 to 3.0 (default 1.0)
  final double measurementScale; // 0.5 to 2.5 (default 1.0)
  final double pointSize; // 1.0 to 12.0 in screen pixels (default 2.0)
  final DxfPointStyle pointStyle; // point marker style
  final DxfUnit? unitOverride; // null = Auto from DXF $INSUNITS

  const DxfDisplaySettings({
    this.lineThicknessScale = 1.0,
    this.linetypeScale = 1.0,
    this.measurementScale = 1.4,
    this.pointSize = 2.0,
    this.pointStyle = DxfPointStyle.none,
    this.unitOverride,
  });

  DxfDisplaySettings copyWith({
    double? lineThicknessScale,
    double? linetypeScale,
    double? measurementScale,
    double? pointSize,
    DxfPointStyle? pointStyle,
    DxfUnit? unitOverride,
    bool clearUnitOverride = false,
  }) {
    return DxfDisplaySettings(
      lineThicknessScale: lineThicknessScale ?? this.lineThicknessScale,
      linetypeScale: linetypeScale ?? this.linetypeScale,
      measurementScale: measurementScale ?? this.measurementScale,
      pointSize: pointSize ?? this.pointSize,
      pointStyle: pointStyle ?? this.pointStyle,
      unitOverride: clearUnitOverride ? null : (unitOverride ?? this.unitOverride),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineThicknessScale': lineThicknessScale,
      'linetypeScale': linetypeScale,
      'measurementScale': measurementScale,
      'pointSize': pointSize,
      'pointStyle': pointStyle.name,
      if (unitOverride != null) 'unitOverride': unitOverride!.name,
    };
  }

  factory DxfDisplaySettings.fromMap(Map<String, dynamic> map) {
    return DxfDisplaySettings(
      lineThicknessScale: (map['lineThicknessScale'] as num?)?.toDouble() ?? 1.0,
      linetypeScale: (map['linetypeScale'] as num?)?.toDouble() ?? 1.0,
      measurementScale: (map['measurementScale'] as num?)?.toDouble() ?? 1.4,
      pointSize: (map['pointSize'] as num?)?.toDouble() ?? 4.0,
      pointStyle: DxfPointStyle.fromName(map['pointStyle'] as String?),
      unitOverride: map['unitOverride'] != null ? DxfUnit.fromName(map['unitOverride'] as String?) : null,
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
