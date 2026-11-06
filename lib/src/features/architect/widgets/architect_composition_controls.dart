import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';

String architectCompositionNumber(double metres, ArchitectUnit unit) =>
    ArchitectUnit.trimZeros(unit.toUnit(metres).toStringAsFixed(6));

String architectCompositionLength(double metres, ArchitectUnit unit) =>
    '${architectCompositionNumber(metres, unit)} ${unit.symbol}';

/// Shared presentation only: each element keeps its own model and apply scope.
class ArchitectCompositionHeader extends StatelessWidget {
  final String title, summary;
  final Widget? scope, preview, trailing;
  final VoidCallback? onChoose;
  const ArchitectCompositionHeader({
    super.key,
    required this.title,
    required this.summary,
    this.scope,
    this.preview,
    this.trailing,
    this.onChoose,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: onChoose == null
                ? Text(title, style: Theme.of(context).textTheme.titleSmall)
                : OutlinedButton(
                    onPressed: onChoose,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
          ),
          ?trailing,
        ],
      ),
      if (scope != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: scope!),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(summary, style: Theme.of(context).textTheme.bodySmall),
      ),
      ?preview,
    ],
  );
}

class ArchitectCompositionLayerRow extends StatelessWidget {
  final String title, thickness;
  final String? detail;
  final Widget? marker, actions, thicknessEditor;
  final VoidCallback onEdit;
  const ArchitectCompositionLayerRow({
    super.key,
    required this.title,
    required this.thickness,
    required this.onEdit,
    this.detail,
    this.marker,
    this.actions,
    this.thicknessEditor,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 380 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final description = [
        if (compact && thicknessEditor == null) thickness,
        ?detail,
      ].join(' · ');
      return Column(
        children: [
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: marker,
            title: compact || thicknessEditor == null
                ? Text(title)
                : Row(
                    children: [
                      Expanded(child: Text(title)),
                      const SizedBox(width: 8),
                      SizedBox(width: 116, child: thicknessEditor),
                    ],
                  ),
            subtitle: compact && thicknessEditor != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(width: 160, child: thicknessEditor),
                      ),
                    ],
                  )
                : description.isEmpty
                ? null
                : Text(description),
            onTap: onEdit,
            trailing: compact || thicknessEditor != null
                ? actions
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        thickness,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      ?actions,
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

/// Keeps the user's numeric text while accepting external updates from dialogs.
/// Unchanged formatted values never round-trip through a different distance unit.
class ArchitectCompositionThicknessField extends StatefulWidget {
  final double value;
  final ArchitectUnit unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool>? onValidityChanged;
  const ArchitectCompositionThicknessField({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.onValidityChanged,
  });
  @override
  State<ArchitectCompositionThicknessField> createState() =>
      _ThicknessFieldState();
}

class _ThicknessFieldState extends State<ArchitectCompositionThicknessField> {
  late final text = TextEditingController(
    text: architectCompositionNumber(widget.value, widget.unit),
  );
  late double lastValue = widget.value;
  double? parse(String value) {
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    return number != null && number.isFinite && number > 0
        ? widget.unit.fromUnit(number)
        : null;
  }

  @override
  void initState() {
    super.initState();
    widget.onValidityChanged?.call(true);
  }

  @override
  void didUpdateWidget(covariant ArchitectCompositionThicknessField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != lastValue || oldWidget.unit != widget.unit) {
      lastValue = widget.value;
      final expectedValue = widget.value, expectedUnit = widget.unit;
      final wanted = architectCompositionNumber(expectedValue, expectedUnit);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.value != expectedValue ||
            widget.unit != expectedUnit) {
          return;
        }
        if (text.text != wanted) {
          text.value = TextEditingValue(
            text: wanted,
            selection: TextSelection.collapsed(offset: wanted.length),
          );
        }
        widget.onValidityChanged?.call(true);
      });
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.architectPropertyThickness,
    child: TextFormField(
      controller: text,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.end,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        suffixText: widget.unit.symbol,
        errorMaxLines: 3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
      validator: (value) => parse(value ?? '') == null
          ? context.l10n.architectWallInvalidThickness
          : null,
      onChanged: (value) {
        final parsed = parse(value);
        widget.onValidityChanged?.call(parsed != null);
        if (parsed != null &&
            value != architectCompositionNumber(widget.value, widget.unit)) {
          lastValue = parsed;
          widget.onChanged(parsed);
        }
      },
    ),
  );
}

class ArchitectCompositionChoice<T> {
  final String id, label;
  final String? detail;
  final T value;
  const ArchitectCompositionChoice({
    required this.id,
    required this.label,
    required this.value,
    this.detail,
  });
}

Future<T?> showArchitectCompositionPicker<T>(
  BuildContext context, {
  required List<ArchitectCompositionChoice<T>> choices,
  required String selectedId,
  required String preferenceKey,
  required String title,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (_) => _CompositionPicker<T>(
    choices: choices,
    selectedId: selectedId,
    preferenceKey: preferenceKey,
    title: title,
  ),
);

class _CompositionPicker<T> extends StatefulWidget {
  final List<ArchitectCompositionChoice<T>> choices;
  final String selectedId, preferenceKey, title;
  const _CompositionPicker({
    required this.choices,
    required this.selectedId,
    required this.preferenceKey,
    required this.title,
  });
  @override
  State<_CompositionPicker<T>> createState() => _CompositionPickerState<T>();
}

class _CompositionPickerState<T> extends State<_CompositionPicker<T>> {
  final query = TextEditingController();
  final favorites = <String>{};
  bool favoritesOnly = false, changed = false;
  Future<void> writes = Future.value();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(widget.preferenceKey) ?? [];
      if (mounted && !changed) setState(() => favorites.addAll(saved));
    } catch (_) {
      // Local preferences must never prevent choosing a building assembly.
    }
  }

  void _favorite(String id) {
    setState(() {
      changed = true;
      if (!favorites.remove(id)) favorites.add(id);
    });
    final snapshot = favorites.toList();
    writes = writes
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(widget.preferenceKey, snapshot);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, q = query.text.trim().toLowerCase();
    final choices = widget.choices
        .where(
          (choice) =>
              (!favoritesOnly || favorites.contains(choice.id)) &&
              (q.isEmpty ||
                  '${choice.label} ${choice.detail ?? ''}'
                      .toLowerCase()
                      .contains(q)),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('composition-search'),
                controller: query,
                decoration: InputDecoration(
                  hintText: l.search,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: Text(l.compositionFavorites),
                  avatar: const Icon(Icons.star_border, size: 18),
                  selected: favoritesOnly,
                  onSelected: (v) => setState(() => favoritesOnly = v),
                ),
              ),
            ),
            Expanded(
              child: choices.isEmpty
                  ? Center(child: Text(l.compositionNoMatches))
                  : ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (_, i) {
                        final choice = choices[i];
                        return ListTile(
                          key: ValueKey('composition-choice-${choice.id}'),
                          selected: choice.id == widget.selectedId,
                          title: Text(choice.label),
                          subtitle: choice.detail == null
                              ? null
                              : Text(
                                  choice.detail!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.pop(context, choice.value),
                          trailing: IconButton(
                            tooltip: l.compositionFavorites,
                            onPressed: () => _favorite(choice.id),
                            icon: Icon(
                              favorites.contains(choice.id)
                                  ? Icons.star
                                  : Icons.star_border,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
