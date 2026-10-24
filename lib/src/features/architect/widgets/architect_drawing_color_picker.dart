import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_drawing_color.dart';

extension ArchitectColorLabels on ArchitectColorRole {
  String label(AppLocalizations l) => switch (this) {
    ArchitectColorRole.black => l.architectColorBlack,
    ArchitectColorRole.white => l.architectColorWhite,
    ArchitectColorRole.gray => l.architectColorGray,
    ArchitectColorRole.red => l.architectColorRed,
    ArchitectColorRole.blue => l.architectColorBlue,
    ArchitectColorRole.green => l.architectColorGreen,
    ArchitectColorRole.yellow => l.architectColorYellow,
    ArchitectColorRole.orange => l.architectColorOrange,
    ArchitectColorRole.residential => l.architectColorResidential,
    ArchitectColorRole.publicServices => l.architectColorPublicServices,
    ArchitectColorRole.industrial => l.architectColorIndustrial,
    ArchitectColorRole.storage => l.architectColorStorage,
    ArchitectColorRole.greenSpace => l.architectColorGreenSpace,
    ArchitectColorRole.arable => l.architectColorArable,
    ArchitectColorRole.perennial => l.architectColorPerennial,
    ArchitectColorRole.uncultivated => l.architectColorUncultivated,
    ArchitectColorRole.forest => l.architectColorForest,
    ArchitectColorRole.recreationalForest => l.architectColorRecreationalForest,
    ArchitectColorRole.water => l.architectColorWater,
    ArchitectColorRole.transport => l.architectColorTransport,
    ArchitectColorRole.utilities => l.architectColorUtilities,
    ArchitectColorRole.housingLowHigh => l.architectColorHousingLowHigh,
    ArchitectColorRole.housingMediumComplex =>
      l.architectColorHousingMediumComplex,
    ArchitectColorRole.villas => l.architectColorVillas,
    ArchitectColorRole.specialPurpose => l.architectColorSpecialPurpose,
    ArchitectColorRole.culturalLand => l.architectColorCulturalLand,
    ArchitectColorRole.primaryRoad => l.architectColorPrimaryRoad,
    ArchitectColorRole.secondaryRoad => l.architectColorSecondaryRoad,
    ArchitectColorRole.collectingRoad => l.architectColorCollectingRoad,
    ArchitectColorRole.servingRoad => l.architectColorServingRoad,
    ArchitectColorRole.pedestrian => l.architectColorPedestrian,
    ArchitectColorRole.housingExisting => l.architectColorHousingExisting,
    ArchitectColorRole.housingNew => l.architectColorHousingNew,
    ArchitectColorRole.publicExisting => l.architectColorPublicExisting,
    ArchitectColorRole.publicNew => l.architectColorPublicNew,
    ArchitectColorRole.heritageBuilding => l.architectColorHeritageBuilding,
    ArchitectColorRole.mixedUse => l.architectColorMixedUse,
    ArchitectColorRole.specialUse => l.architectColorSpecialUse,
    ArchitectColorRole.railway => l.architectColorRailway,
    ArchitectColorRole.agriculture => l.architectColorAgriculture,
  };
}

extension ArchitectPaletteLabel on ArchitectColorPalette {
  String label(AppLocalizations l) => switch (this) {
    ArchitectColorPalette.general => l.architectColorGeneral,
    ArchitectColorPalette.bgOup => l.architectColorBgOup,
    ArchitectColorPalette.bgPup => l.architectColorBgPup,
    ArchitectColorPalette.dePlanZV => l.architectColorGermany,
  };
}

class ArchitectColorSwatch extends StatelessWidget {
  final int argb;
  const ArchitectColorSwatch({super.key, required this.argb});
  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey),
    ),
    child: ColoredBox(color: Color(argb)),
  );
}

class ArchitectDrawingColorPicker extends StatelessWidget {
  final ArchitectDrawingColor? value;
  final ValueChanged<ArchitectDrawingColor> onChanged;
  final bool compact;
  const ArchitectDrawingColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });
  Future<void> _choose(BuildContext context) async {
    final result = await showDialog<ArchitectDrawingColor>(
      context: context,
      builder: (_) => ArchitectDrawingColorDialog(
        initial: value ?? ArchitectDrawingColor.ink,
      ),
    );
    if (result != null && context.mounted) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final description = value?.preset?.code ?? value?.hex ?? '—';
    if (compact) {
      return Tooltip(
        message: '${l.architectDrawingColor}: $description',
        child: InkWell(
          onTap: () => _choose(context),
          child: SizedBox(
            width: 36,
            height: 40,
            child: Center(
              child: ArchitectColorSwatch(argb: value?.argb ?? 0xFF424242),
            ),
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(l.architectDrawingColor),
      subtitle: Text(description),
      trailing: value == null
          ? const Text('—')
          : ArchitectColorSwatch(argb: value!.argb),
      onTap: () => _choose(context),
    );
  }
}

class ArchitectDrawingColorDialog extends StatefulWidget {
  final ArchitectDrawingColor initial;
  const ArchitectDrawingColorDialog({super.key, required this.initial});
  @override
  State<ArchitectDrawingColorDialog> createState() =>
      _DrawingColorDialogState();
}

class _DrawingColorDialogState extends State<ArchitectDrawingColorDialog> {
  late ArchitectDrawingColor color = widget.initial;
  late ArchitectColorPalette palette =
      color.preset?.palette ?? ArchitectColorPalette.general;
  String search = '';
  Future<void> _custom() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showDialog<ArchitectDrawingColor>(
      context: context,
      builder: (_) => ArchitectCustomColorDialog(initial: color),
    );
    if (result != null && mounted) setState(() => color = result);
  }

  Future<void> _info() => showDialog<void>(
    context: context,
    builder: (ctx) {
      final l = context.l10n;
      final isBg =
          palette == ArchitectColorPalette.bgOup ||
          palette == ArchitectColorPalette.bgPup;
      return AlertDialog(
        title: Text(l.architectColorInfo),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBg) Text(l.architectColorBgInfo),
                if (palette == ArchitectColorPalette.dePlanZV)
                  Text(l.architectColorDeInfo),
                const SizedBox(height: 12),
                Text(l.architectColorApprox),
                const SizedBox(height: 12),
                if (isBg) const SelectableText(ArchitectDrawingColors.bgSource),
                if (palette == ArchitectColorPalette.dePlanZV)
                  const SelectableText(ArchitectDrawingColors.deSource),
                const SizedBox(height: 12),
                const SelectableText(ArchitectDrawingColors.ralSource),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final options = ArchitectDrawingColors.presets
        .where(
          (p) =>
              p.palette == palette &&
              ('${p.role.label(l)} ${p.code} ${p.reference}')
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l.architectDrawingColor)),
          IconButton(
            key: const ValueKey('drawing-color-info'),
            tooltip: l.architectColorInfo,
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: _info,
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: math.min(500, MediaQuery.sizeOf(context).height * .58),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<ArchitectColorPalette>(
              key: const ValueKey('drawing-color-palette'),
              value: palette,
              isExpanded: true,
              items: [
                for (final p in ArchitectColorPalette.values)
                  DropdownMenuItem(value: p, child: Text(p.label(l))),
              ],
              onChanged: (p) {
                if (p != null) setState(() => palette = p);
              },
            ),
            TextField(
              key: const ValueKey('drawing-color-search'),
              decoration: InputDecoration(
                hintText: l.architectColorSearch,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                children: [
                  for (final p in options)
                    ListTile(
                      key: ValueKey('drawing-color-${p.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: ArchitectColorSwatch(argb: p.argb),
                      title: Text(
                        p.role.label(l),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(p.code),
                      selected: color.presetId == p.id,
                      onTap: () => setState(
                        () => color = ArchitectDrawingColor(
                          p.argb,
                          presetId: p.id,
                        ).withOpacity(color.opacityPercent),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                ArchitectColorSwatch(argb: color.argb),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${color.preset?.code ?? color.hex} · ${color.opacityPercent}%',
                  ),
                ),
                IconButton(
                  key: const ValueKey('drawing-color-custom'),
                  tooltip: l.architectColorCustom,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _custom,
                ),
              ],
            ),
            Row(
              children: [
                Text(l.architectColorOpacity),
                Expanded(
                  child: Slider(
                    key: const ValueKey('drawing-color-opacity'),
                    value: color.opacityPercent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (v) =>
                        setState(() => color = color.withOpacity(v.round())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('drawing-color-save'),
          onPressed: () {
            color.validate();
            Navigator.pop(context, color);
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class ArchitectCustomColorDialog extends StatefulWidget {
  final ArchitectDrawingColor initial;
  const ArchitectCustomColorDialog({super.key, required this.initial});
  @override
  State<ArchitectCustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<ArchitectCustomColorDialog> {
  late final TextEditingController hex = TextEditingController(
    text: widget.initial.hex.substring(1),
  );
  int? get rgb => RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex.text)
      ? int.tryParse(hex.text, radix: 16)
      : null;
  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = rgb ?? (widget.initial.argb & 0xFFFFFF);
    return AlertDialog(
      title: Text(l.architectColorCustom),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArchitectColorSwatch(argb: 0xFF000000 | value),
              TextField(
                key: const ValueKey('drawing-color-hex'),
                controller: hex,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'HEX',
                  prefixText: '#',
                  errorText: rgb == null ? l.architectColorHexError : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              for (final entry in [(16, 'R'), (8, 'G'), (0, 'B')])
                Row(
                  children: [
                    Text(entry.$2),
                    Expanded(
                      child: Slider(
                        key: ValueKey('drawing-color-channel-${entry.$2}'),
                        value: ((value >> entry.$1) & 255).toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '${(value >> entry.$1) & 255}',
                        onChanged: (v) => setState(() {
                          final updated =
                              (value & ~(255 << entry.$1)) |
                              (v.round() << entry.$1);
                          hex.text = updated
                              .toRadixString(16)
                              .padLeft(6, '0')
                              .toUpperCase();
                        }),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('drawing-color-custom-save'),
          onPressed: rgb == null
              ? null
              : () => Navigator.pop(
                  context,
                  ArchitectDrawingColor(
                    (widget.initial.argb & 0xFF000000) | rgb!,
                  ),
                ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
