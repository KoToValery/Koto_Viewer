import '../widgets/bim_edit_actions.dart';

enum BimContextMenuMode { circle, grid }

class BimContextMenuPreset {
  final String id, name;
  final BimContextMenuMode mode;
  final List<BimEditAction?> slots;
  const BimContextMenuPreset({
    required this.id,
    required this.name,
    required this.mode,
    required this.slots,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode.name,
    'slots': slots.map((a) => a?.name).toList(),
  };
  static BimContextMenuPreset? read(dynamic json) {
    if (json is! Map ||
        json['id'] is! String ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        (json['id'] as String).isEmpty ||
        json['id'] == 'default') {
      return null;
    }
    return BimContextMenuPreset(
      id: json['id'],
      name: (json['name'] as String).trim(),
      mode: BimContextMenuSettings.readMode(json['mode']),
      slots: BimContextMenuSettings.readSlots(json['slots']),
    );
  }
}

/// Eight stable command slots and a centre button for fixed additional pages.
/// Unavailable commands keep their slots; no action can become unreachable.
class BimContextMenuSettings {
  static const defaultSlots = <BimEditAction?>[
    BimEditAction.move,
    BimEditAction.rotate,
    BimEditAction.mirrorMove,
    BimEditAction.delete,
    BimEditAction.properties,
    BimEditAction.duplicate,
    BimEditAction.newPoint,
    BimEditAction.cutOpening,
  ];
  final BimContextMenuMode mode;
  final String selectedPresetId;
  final List<BimContextMenuPreset> presets;
  const BimContextMenuSettings({
    this.mode = BimContextMenuMode.circle,
    this.selectedPresetId = 'default',
    this.presets = const [],
  });
  List<BimEditAction?> get slots =>
      presets.where((p) => p.id == selectedPresetId).firstOrNull?.slots ??
      defaultSlots;
  List<List<BimEditAction?>> get pages {
    final first = readSlots(slots.map((a) => a?.name).toList());
    final remaining = BimEditAction.values
        .where((a) => !first.contains(a))
        .toList();
    return [
      first,
      for (var i = 0; i < remaining.length; i += 8)
        List<BimEditAction?>.generate(
          8,
          (j) => i + j < remaining.length ? remaining[i + j] : null,
        ),
    ];
  }

  BimContextMenuSettings copyWith({
    BimContextMenuMode? mode,
    String? selectedPresetId,
    List<BimContextMenuPreset>? presets,
  }) => BimContextMenuSettings(
    mode: mode ?? this.mode,
    selectedPresetId: selectedPresetId ?? this.selectedPresetId,
    presets: presets ?? this.presets,
  );
  BimContextMenuSettings select(String id) {
    final preset = presets.where((p) => p.id == id).firstOrNull;
    return copyWith(
      selectedPresetId: preset?.id ?? 'default',
      mode: preset?.mode ?? BimContextMenuMode.circle,
    );
  }

  BimContextMenuSettings savePreset(BimContextMenuPreset preset) => copyWith(
    mode: preset.mode,
    selectedPresetId: preset.id,
    presets: [
      for (final p in presets)
        if (p.id != preset.id) p,
      preset,
    ],
  );
  BimContextMenuSettings deletePreset(String id) => copyWith(
    selectedPresetId: selectedPresetId == id ? 'default' : selectedPresetId,
    presets: presets.where((p) => p.id != id).toList(),
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.name,
    'selectedPresetId': selectedPresetId,
    'presets': presets.map((p) => p.toJson()).toList(),
  };
  factory BimContextMenuSettings.fromJson(Map<String, dynamic> json) {
    final presets = <BimContextMenuPreset>[];
    for (final raw
        in json['presets'] is List ? json['presets'] as List : const []) {
      final p = BimContextMenuPreset.read(raw);
      if (p != null && !presets.any((e) => e.id == p.id)) presets.add(p);
    }
    final id = json['selectedPresetId'];
    return BimContextMenuSettings(
      mode: readMode(json['mode']),
      selectedPresetId: presets.any((p) => p.id == id) ? id : 'default',
      presets: presets,
    );
  }
  static BimContextMenuMode readMode(dynamic value) =>
      value == 'grid' ? BimContextMenuMode.grid : BimContextMenuMode.circle;
  static List<BimEditAction?> readSlots(dynamic value) {
    final raw = value is List
        ? value
        : defaultSlots.map((a) => a?.name).toList();
    final used = <BimEditAction>{};
    return List.unmodifiable(
      List<BimEditAction?>.generate(8, (i) {
        final action = i < raw.length
            ? BimEditAction.values.where((a) => a.name == raw[i]).firstOrNull
            : null;
        return action != null && used.add(action) ? action : null;
      }),
    );
  }
}
