import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_fenestration_style.dart';

class FenestrationPropertiesPanel extends StatelessWidget {
  final ArchitectFenestrationStyle style;
  final String? selectedPaneId;
  final ValueChanged<String> onSelectPane;
  final ValueChanged<ArchitectFenestrationStyle> onChanged;
  final GlobalKey<FormState> formKey;
  const FenestrationPropertiesPanel({
    super.key,
    required this.style,
    required this.selectedPaneId,
    required this.onSelectPane,
    required this.onChanged,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pane =
        style.panes.where((p) => p.id == selectedPaneId).firstOrNull ??
        style.panes.firstOrNull;
    final isDoor = style.kind == FenestrationKind.door;
    final upper =
        pane != null && style.transom?.subdivision.findPane(pane.id) != null;
    Widget number(
      String id,
      String label,
      double value,
      ValueChanged<double> changed, {
      double min = 0,
      double max = 4,
      double scale = 100,
      String unit = 'cm',
      bool integer = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FenestrationNumberField(
        key: ValueKey(id),
        label: label,
        value: value,
        scale: scale,
        min: min,
        max: max,
        unit: unit,
        integer: integer,
        onChanged: changed,
      ),
    );
    Widget group(
      String id,
      String title,
      List<Widget> children, {
      bool open = true,
    }) => ExpansionTile(
      key: PageStorageKey(id),
      initiallyExpanded: open,
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: children,
    );
    String typeLabel(PaneType type) => switch (type) {
      PaneType.fixedGlazing ||
      PaneType.solidPanel => l.architectFenestrationPaneFixed,
      PaneType.casementLeft => l.architectFenestrationPaneTurnLeft,
      PaneType.casementRight => l.architectFenestrationPaneTurnRight,
      PaneType.tiltAndTurn => l.architectFenestrationPaneTiltTurn,
      PaneType.topHopper => l.architectFenestrationPaneTopHopper,
      PaneType.doorLeaf => l.architectFenestrationPaneDoorLeaf,
    };
    final types = upper
        ? [PaneType.fixedGlazing, PaneType.topHopper]
        : [
            if (isDoor) PaneType.doorLeaf,
            PaneType.fixedGlazing,
            PaneType.casementLeft,
            PaneType.casementRight,
            PaneType.tiltAndTurn,
            PaneType.topHopper,
          ];
    return Form(
      key: formKey,
      child: ListView(
        key: const PageStorageKey('fenestration-properties'),
        padding: EdgeInsets.zero,
        children: [
          group('dimensions', l.architectFenestrationDimensions, [
            number(
              'fenestration-width',
              l.architectShapeWidth,
              style.defaultWidth,
              (v) => onChanged(style.copyWith(defaultWidth: v)),
              min: math.max(.4, 2 * style.frameFaceWidth + .1),
              max: 5,
            ),
            number(
              'fenestration-height',
              isDoor
                  ? l.architectFenestrationDoorBodyHeight
                  : l.architectShapeHeight,
              isDoor ? style.doorBodyHeight : style.defaultHeight,
              (v) => onChanged(
                style.copyWith(defaultHeight: v + (style.transom?.height ?? 0)),
              ),
              min: math.max(.4, 2 * style.frameFaceWidth + .1),
              max: 4 - (style.transom?.height ?? 0),
            ),
            number(
              'fenestration-sill',
              l.architectWindowSill,
              style.defaultSillHeight,
              (v) => onChanged(style.copyWith(defaultSillHeight: v)),
              max: 1.5,
            ),
            if (isDoor) ...[
              SwitchListTile.adaptive(
                key: const ValueKey('fenestration-transom'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectFenestrationTransom),
                value: style.transom != null,
                onChanged: (v) => onChanged(
                  style.withTransom(v ? const FenestrationTransom() : null),
                ),
              ),
              if (style.transom != null) ...[
                number(
                  'fenestration-transom-height',
                  l.architectFenestrationTransomHeight,
                  style.transom!.height,
                  (v) => onChanged(
                    style.withTransom(style.transom!.copyWith(height: v)),
                  ),
                  min: math.max(.2, style.frameFaceWidth * 1.5 + .02),
                  max: 4 - style.doorBodyHeight,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(l.architectFenestrationTotalHeight)),
                      Text(
                        '${(style.defaultHeight * 100).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")} cm',
                        key: const ValueKey('fenestration-total-height'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ]),
          group('divisions', l.architectFenestrationDivisions, [
            if (style.panes.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('pane-selector-$selectedPaneId'),
                  initialValue: pane?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.architectFenestrationLeafShort,
                  ),
                  items: [
                    for (var i = 0; i < style.panes.length; i++)
                      DropdownMenuItem(
                        value: style.panes[i].id,
                        child: Text('${i + 1}'),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) onSelectPane(id);
                  },
                ),
              ),
            if (pane != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: l.architectFenestrationAddMullion,
                    icon: const Icon(Icons.vertical_split_outlined),
                    onPressed: () =>
                        onChanged(style.splitPane(pane.id, vertical: true)),
                  ),
                  IconButton(
                    tooltip: l.architectFenestrationAddTransom,
                    icon: const Icon(Icons.horizontal_split_outlined),
                    onPressed: upper
                        ? null
                        : () => onChanged(
                            style.splitPane(pane.id, vertical: false),
                          ),
                  ),
                  IconButton(
                    tooltip: l.architectFenestrationRemoveSplit,
                    icon: const Icon(Icons.merge_outlined),
                    onPressed: style.panes.length < 2
                        ? null
                        : () => onChanged(style.collapsePane(pane.id)),
                  ),
                ],
              ),
              if (style.panes.length > 1) ...[
                number(
                  'pane-width-${pane.id}',
                  l.architectFenestrationLeafWidth,
                  style.getPaneRect(pane.id)!.width,
                  (v) =>
                      onChanged(style.setPaneMetricDimension(pane.id, v, true)),
                  min: .2,
                  max: style.defaultWidth,
                ),
                if (!upper)
                  number(
                    'pane-height-${pane.id}',
                    l.architectFenestrationLeafHeight,
                    style.getPaneRect(pane.id)!.height,
                    (v) => onChanged(
                      style.setPaneMetricDimension(pane.id, v, false),
                    ),
                    min: .2,
                    max: style.doorBodyHeight,
                  ),
              ],
            ],
          ]),
          if (pane != null)
            group('leaf', l.architectFenestrationLeafShort, [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<PaneType>(
                  key: ValueKey('pane-operation-${pane.id}-${pane.paneType}'),
                  initialValue: types.contains(pane.paneType)
                      ? pane.paneType
                      : PaneType.fixedGlazing,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.architectFenestrationPaneType,
                  ),
                  items: [
                    for (final type in types)
                      DropdownMenuItem(
                        value: type,
                        child: Text(typeLabel(type)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      onChanged(
                        style.updatePane(
                          pane.copyWith(
                            paneType: v,
                            infill: pane.isGlazed
                                ? FenestrationInfill.glazing
                                : FenestrationInfill.solid,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              if (!upper)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SegmentedButton<FenestrationInfill>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: FenestrationInfill.glazing,
                        label: Text(l.architectFenestrationInfillGlazing),
                      ),
                      ButtonSegment(
                        value: FenestrationInfill.solid,
                        label: Text(l.architectFenestrationInfillSolid),
                      ),
                    ],
                    selected: {
                      pane.isGlazed
                          ? FenestrationInfill.glazing
                          : FenestrationInfill.solid,
                    },
                    onSelectionChanged: (v) => onChanged(
                      style.updatePane(pane.copyWith(infill: v.first)),
                    ),
                  ),
                ),
              if (pane.isGlazed) ...[
                number(
                  'muntin-cols-${pane.id}',
                  l.architectFenestrationMuntinCols,
                  pane.muntinCols.toDouble(),
                  (v) => onChanged(
                    style.updatePane(pane.copyWith(muntinCols: v.toInt())),
                  ),
                  scale: 1,
                  unit: '',
                  max: 6,
                  integer: true,
                ),
                number(
                  'muntin-rows-${pane.id}',
                  l.architectFenestrationMuntinRows,
                  pane.muntinRows.toDouble(),
                  (v) => onChanged(
                    style.updatePane(pane.copyWith(muntinRows: v.toInt())),
                  ),
                  scale: 1,
                  unit: '',
                  max: 6,
                  integer: true,
                ),
              ],
            ]),
          group('details', l.architectFenestrationDetailsShort, [
            number(
              'frame-depth',
              l.architectFenestrationProfileDepth,
              style.frameDepth,
              (v) => onChanged(style.copyWith(frameDepth: v)),
              scale: 1000,
              unit: 'mm',
              min: .02,
              max: .2,
            ),
            number(
              'frame-face',
              l.architectFenestrationProfileFace,
              style.frameFaceWidth,
              (v) => onChanged(style.copyWith(frameFaceWidth: v)),
              scale: 1000,
              unit: 'mm',
              min: .02,
              max: math.min(
                .15,
                math.min(style.defaultWidth, style.doorBodyHeight) / 4,
              ),
            ),
            if (pane != null && pane.isOpenable)
              number(
                'sash-profile-${pane.id}',
                l.architectFenestrationSashProfile,
                pane.sashProfileWidth,
                (v) => onChanged(
                  style.updatePane(pane.copyWith(sashProfileWidth: v)),
                ),
                scale: 1000,
                unit: 'mm',
                min: .02,
                max: math.min(
                  .085,
                  math.min(
                        style.getPaneRect(pane.id)!.width,
                        style.getPaneRect(pane.id)!.height,
                      ) /
                      4,
                ),
              ),
            number(
              'glazing-thickness',
              l.architectFenestrationGlazingThickness,
              style.glazingThickness,
              (v) => onChanged(style.copyWith(glazingThickness: v)),
              scale: 1000,
              unit: 'mm',
              min: .004,
              max: .06,
            ),
            if (pane != null && pane.hasMuntins)
              number(
                'muntin-width-${pane.id}',
                l.architectFenestrationMuntinWidth,
                pane.muntinWidth,
                (v) =>
                    onChanged(style.updatePane(pane.copyWith(muntinWidth: v))),
                scale: 1000,
                unit: 'mm',
                min: .01,
                max: .04,
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectFenestrationCasing),
              value: style.hasCasing,
              onChanged: (v) => onChanged(style.copyWith(hasCasing: v)),
            ),
            if (style.hasCasing) ...[
              number(
                'casing-width',
                l.architectFenestrationCasingWidth,
                style.casingWidth,
                (v) => onChanged(style.copyWith(casingWidth: v)),
                min: .02,
                max: .3,
              ),
              number(
                'casing-projection',
                l.architectFenestrationCasingProjection,
                style.casingProjection,
                (v) => onChanged(style.copyWith(casingProjection: v)),
                min: .005,
                max: .15,
              ),
              DropdownButtonFormField<CasingPlacement>(
                key: ValueKey(style.casingPlacement),
                initialValue: style.casingPlacement,
                decoration: InputDecoration(
                  labelText: l.architectFenestrationCasingPlacement,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: CasingPlacement.exterior,
                    child: Text(l.architectFenestrationCasingExterior),
                  ),
                  DropdownMenuItem(
                    value: CasingPlacement.interior,
                    child: Text(l.architectFenestrationCasingInterior),
                  ),
                  DropdownMenuItem(
                    value: CasingPlacement.both,
                    child: Text(l.architectFenestrationCasingBoth),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(style.copyWith(casingPlacement: v));
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectFenestrationIncludeBottomCasing),
                value: style.includeBottomCasing,
                onChanged: (v) =>
                    onChanged(style.copyWith(includeBottomCasing: v)),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in const [
                    0xFFECEFF1,
                    0xFFCFD8DC,
                    0xFF546E7A,
                    0xFF263238,
                    0xFF8D6E63,
                    0xFF4E342E,
                  ])
                    Tooltip(
                      message: '#${color.toRadixString(16).toUpperCase()}',
                      child: InkWell(
                        onTap: () =>
                            onChanged(style.copyWith(casingColorValue: color)),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: style.casingColorValue == color ? 3 : 1,
                              color: style.casingColorValue == color
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ], open: false),
        ],
      ),
    );
  }
}

/// Commits a complete number on submit, focus loss, or Form.save.
class FenestrationNumberField extends StatefulWidget {
  final String label, unit;
  final double value, scale, min, max;
  final bool integer;
  final ValueChanged<double> onChanged;
  const FenestrationNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.scale,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.integer = false,
  });
  @override
  State<FenestrationNumberField> createState() => _NumberState();
}

class _NumberState extends State<FenestrationNumberField> {
  late final controller = TextEditingController(text: _text());
  final focus = FocusNode();
  String _text() => (widget.value * widget.scale)
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  double? parse(String text) {
    final n = double.tryParse(text.trim().replaceAll(',', '.'));
    if (n == null || !n.isFinite || (widget.integer && n != n.roundToDouble())) {
      return null;
    }
    final value = n / widget.scale;
    return value >= widget.min - 1e-9 && value <= widget.max + 1e-9
        ? value
        : null;
  }

  void commit() {
    final n = parse(controller.text);
    if (n != null && (n - widget.value).abs() > 1e-9) widget.onChanged(n);
  }

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) commit();
    });
  }

  @override
  void didUpdateWidget(covariant FenestrationNumberField old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus && old.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !focus.hasFocus && controller.text != _text()) {
          controller.text = _text();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focus,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: widget.unit,
      isDense: true,
    ),
    keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
    textInputAction: TextInputAction.next,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (s) => parse(s ?? '') == null
        ? context.l10n.architectFenestrationInvalidSize
        : null,
    onSaved: (_) => commit(),
    onFieldSubmitted: (_) => commit(),
  );
}
