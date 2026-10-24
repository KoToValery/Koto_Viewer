import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';
import '../services/ui_settings_service.dart';
import '../../features/bim_editing/models/bim_context_menu_settings.dart';
import '../../features/bim_editing/widgets/bim_edit_actions.dart';
import '../../features/architect/widgets/architect_radial_menu.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  BimContextMenuSettings _settings = UiSettingsService.contextMenu.value;
  bool _saving = false;
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UiSettingsService.save(_settings);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.uiSettingsSaveFailed)),
        );
      }
    }
  }

  Future<void> _edit({bool existing = false}) async {
    final preset = existing
        ? _settings.presets
              .where((p) => p.id == _settings.selectedPresetId)
              .firstOrNull
        : null;
    final result = await showDialog<BimContextMenuPreset>(
      context: context,
      builder: (_) =>
          ContextMenuPresetEditor(settings: _settings, preset: preset),
    );
    if (result != null && mounted) {
      setState(() => _settings = _settings.savePreset(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final custom = _settings.selectedPresetId != 'default';
    return Scaffold(
      appBar: AppBar(title: Text(l.appSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            key: const ValueKey('settings-ui-category'),
            initiallyExpanded: true,
            tilePadding: EdgeInsets.zero,
            title: Text(l.uiSettingsCategory),
            leading: const Icon(Icons.dashboard_customize_outlined),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.contextMenuTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BimContextMenuMode>(
                key: ValueKey('context-menu-mode-${_settings.mode.name}'),
                initialValue: _settings.mode,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.contextMenuLayout),
                items: [
                  for (final mode in BimContextMenuMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(
                        mode == BimContextMenuMode.circle
                            ? l.contextMenuCircle
                            : l.contextMenuGrid,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(
                            () => _settings = _settings.copyWith(mode: v),
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'context-menu-preset-${_settings.selectedPresetId}',
                ),
                initialValue: _settings.selectedPresetId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.contextMenuCombination,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'default',
                    child: Text(l.contextMenuDefault),
                  ),
                  for (final p in _settings.presets)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => _settings = _settings.select(v));
                        }
                      },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const ValueKey('context-menu-new'),
                    onPressed: _saving ? null : _edit,
                    icon: const Icon(Icons.add),
                    label: Text(l.contextMenuSaveAs),
                  ),
                  if (custom)
                    TextButton.icon(
                      key: const ValueKey('context-menu-edit'),
                      onPressed: _saving ? null : () => _edit(existing: true),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l.contextMenuEdit),
                    ),
                  if (custom)
                    IconButton(
                      key: const ValueKey('context-menu-delete-preset'),
                      tooltip: l.delete,
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _settings = _settings.deletePreset(
                                _settings.selectedPresetId,
                              ),
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              SizedBox(
                height: 280,
                child: LayoutBuilder(
                  builder: (_, c) => ArchitectRadialMenu(
                    key: ValueKey(
                      'settings-preview-${_settings.selectedPresetId}-${_settings.mode.name}',
                    ),
                    center: Offset(c.maxWidth / 2, 140),
                    settings: _settings,
                    items: _allItems(l),
                    onActionSelected: (_) {},
                    onDismiss: () {},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const ValueKey('app-settings-save'),
            onPressed: _saving ? null : _save,
            child: Text(l.save),
          ),
        ),
      ),
    );
  }
}

List<ArchitectRadialMenuItem> _allItems(AppLocalizations l) => [
  for (final a in BimEditAction.values)
    ArchitectRadialMenuItem(
      action: a,
      icon: BimEditActions.icon(a),
      label: BimEditActions.label(a, l),
      color: a == BimEditAction.delete
          ? Colors.redAccent
          : const Color(0xFF80CBC4),
    ),
];

class ContextMenuPresetEditor extends StatefulWidget {
  final BimContextMenuSettings settings;
  final BimContextMenuPreset? preset;
  const ContextMenuPresetEditor({
    super.key,
    required this.settings,
    this.preset,
  });
  @override
  State<ContextMenuPresetEditor> createState() =>
      _ContextMenuPresetEditorState();
}

class _ContextMenuPresetEditorState extends State<ContextMenuPresetEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.preset?.name ?? '',
  );
  late BimContextMenuMode _mode = widget.settings.mode;
  late final List<BimEditAction?> _slots = List.of(widget.settings.slots);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _assign(int slot) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .7,
          child: ListView(
            children: [
              ListTile(
                title: Text(l.contextMenuEmpty),
                leading: const Icon(Icons.remove),
                onTap: () => Navigator.pop(ctx, 'empty'),
              ),
              for (final a in BimEditAction.values)
                ListTile(
                  key: ValueKey('context-menu-choose-${a.name}'),
                  leading: BimEditingSymbol(a),
                  title: Text(BimEditActions.label(a, l)),
                  trailing: _slots[slot] == a ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, a.name),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final action = BimEditAction.values
        .where((a) => a.name == choice)
        .firstOrNull;
    setState(() {
      final previous = _slots[slot];
      final other = action == null ? -1 : _slots.indexOf(action);
      if (other >= 0 && other != slot) _slots[other] = previous;
      _slots[slot] = action;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final preview = BimContextMenuPreset(
      id: 'preview',
      name: '_',
      mode: _mode,
      slots: _slots,
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.contextMenuCombination,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('context-menu-preset-name'),
                  controller: _name,
                  maxLength: 60,
                  decoration: InputDecoration(labelText: l.contextMenuName),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<BimContextMenuMode>(
                  initialValue: _mode,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.contextMenuLayout),
                  items: [
                    DropdownMenuItem(
                      value: BimContextMenuMode.circle,
                      child: Text(l.contextMenuCircle),
                    ),
                    DropdownMenuItem(
                      value: BimContextMenuMode.grid,
                      child: Text(l.contextMenuGrid),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _mode = v);
                  },
                ),
                Tooltip(
                  message: l.contextMenuAssignHint,
                  child: SizedBox(
                    height: 270,
                    child: LayoutBuilder(
                      builder: (_, c) => ArchitectRadialMenu(
                        center: Offset(c.maxWidth / 2, 135),
                        settings: widget.settings.savePreset(preview),
                        items: _allItems(l),
                        onActionSelected: (_) {},
                        onDismiss: () {},
                        onSlotSelected: _assign,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('context-menu-preset-save'),
                      onPressed: _name.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              BimContextMenuPreset(
                                id:
                                    widget.preset?.id ??
                                    'custom_${DateTime.now().microsecondsSinceEpoch}',
                                name: _name.text.trim(),
                                mode: _mode,
                                slots: List.unmodifiable(_slots),
                              ),
                            ),
                      child: Text(l.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
