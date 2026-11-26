import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../bim_editing/properties/bim_numeric_rule.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../models/architect_project.dart';
import '../models/architect_site_parcel.dart';
import '../rendering/architect_snap_helper.dart';
import 'architect_transform_point_input.dart';

class ArchitectSiteParcelOverlay extends StatefulWidget {
  final ArchitectProject project;
  final bool editingSetbacks;
  final double scale;
  final Offset Function(Offset) toModel, toScreen;
  final ArchitectTransformSnap snap;
  final void Function(Offset, double, Offset) onNavigate;
  final ValueChanged<ArchitectSiteParcel> onCommit;
  final ValueChanged<List<ArchitectSiteSegment>?> onSetbackPreview;
  final VoidCallback onCancel;

  const ArchitectSiteParcelOverlay({
    super.key,
    required this.project,
    required this.editingSetbacks,
    required this.scale,
    required this.toModel,
    required this.toScreen,
    required this.snap,
    required this.onNavigate,
    required this.onCommit,
    required this.onSetbackPreview,
    required this.onCancel,
  });

  @override
  State<ArchitectSiteParcelOverlay> createState() => _ParcelOverlayState();
}

class _ParcelOverlayState extends State<ArchitectSiteParcelOverlay> {
  late final List<Offset> _vertices = [
    ...?widget.project.activeStorey.siteParcel?.vertices,
  ];
  ArchitectSiteParcel? get _parcel => widget.project.activeStorey.siteParcel;
  Offset? _aim;
  int? _vertex, _side;
  bool _dialogOpen = false, _invalid = false;

  double _tolerance(bool touch) => (touch ? 12 : 8) / widget.scale;

  ArchitectSnapResult _resolve(Offset raw, bool touch) {
    final tolerance = _tolerance(touch);
    if (widget.editingSetbacks) {
      final hit = BimLineGeometry.insertion(_vertices, raw, closed: true);
      _side = hit != null && hit.distance <= tolerance ? hit.edge : null;
      return ArchitectSnapResult(
        point: _side == null ? raw : hit!.point,
        isSnapped: _side != null,
      );
    }
    if (_parcel != null && _vertex == null) {
      final nearest = _nearestVertex(raw, tolerance);
      return ArchitectSnapResult(
        point: nearest == null ? raw : _vertices[nearest],
        isSnapped: nearest != null,
      );
    }
    if (_parcel == null &&
        _vertices.length >= 3 &&
        (_vertices.first - raw).distance <= tolerance) {
      return ArchitectSnapResult(point: _vertices.first, isSnapped: true);
    }
    return widget.snap(raw, touch);
  }

  int? _nearestVertex(Offset raw, double tolerance) {
    int? nearest;
    for (var i = 0; i < _vertices.length; i++) {
      final distance = (raw - _vertices[i]).distance;
      if (distance > tolerance) continue;
      nearest = i;
      tolerance = distance;
    }
    return nearest;
  }

  void _finish() {
    final parcel = ArchitectSiteParcel(
      _vertices,
      setbacks: _parcel?.setbacks ?? {},
    );
    if (!BimPolygonGeometry.valid(_vertices) ||
        (parcel.setbacks.isNotEmpty &&
            (parcel.trimmedSetbacks.isEmpty ||
                parcel.setbacks.entries.any(
                  (e) => parcel.setbackSegments(e.key, e.value).isEmpty,
                )))) {
      setState(() => _invalid = true);
      return;
    }
    widget.onCommit(parcel);
  }

  void _pick(Offset point) {
    if (widget.editingSetbacks) {
      if (_side != null && !_dialogOpen) _editSetback(_side!);
      return;
    }
    if (_parcel == null && _vertices.length >= 3 && point == _vertices.first) {
      _finish();
      return;
    }
    setState(() {
      _invalid = false;
      if (_parcel == null) {
        if (!_vertices.contains(point)) _vertices.add(point);
      } else if (_vertex != null) {
        _vertices[_vertex!] = point;
        _vertex = null;
      } else {
        _vertex = _nearestVertex(point, 1e-8);
      }
    });
  }

  Future<void> _editSetback(int index) async {
    final parcel = _parcel!;
    final l = context.l10n;
    final unit = widget.project.units;
    final current = parcel.setbacks[index];
    final rule = BimNumericRule(unitToModel: unit.scaleToMeters);
    var input = current == null
        ? ''
        : (current / unit.scaleToMeters).toStringAsFixed(4);
    var starting = current != null;
    var valid =
        current != null &&
        parcel.trimmedSetbacks.isNotEmpty &&
        parcel.setbackSegments(index, current).isNotEmpty;
    setState(() => _dialogOpen = true);
    final result = await showDialog<double>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final distance = starting ? current : rule.parse(input);
          return AlertDialog(
            alignment: Alignment.bottomCenter,
            constraints: const BoxConstraints(maxWidth: 320),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(l.architectSiteSetback),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l.bimOffsetDistance,
                      suffixText: unit.symbol,
                      errorText: input.isNotEmpty && !valid
                          ? l.architectSiteInvalidSetback
                          : null,
                    ),
                    child: Text(
                      input.isEmpty ? ' ' : input,
                      key: const ValueKey('architect-site-setback-distance'),
                    ),
                  ),
                  BimNumericKeypad(
                    keyPrefix: 'architect-site-setback-key',
                    decimals: 4,
                    onKey: (key) {
                      refresh(() {
                        input = BimNumericKeypad.edit(
                          starting && key != '⌫' ? '' : input,
                          key,
                          decimals: 4,
                        );
                        starting = false;
                        final value = rule.parse(input);
                        valid =
                            value != null &&
                            parcel.setbackSegments(index, value).isNotEmpty;
                        final preview = valid
                            ? parcel.withSetback(index, value).trimmedSetbacks
                            : parcel.withSetback(index, null).trimmedSetbacks;
                        valid = valid && preview.isNotEmpty;
                        widget.onSetbackPreview(preview);
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 0.0),
                  child: Text(l.delete),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(dialogContext, distance)
                    : null,
                child: Text(l.applyAction),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    widget.onSetbackPreview(null);
    setState(() {
      _dialogOpen = false;
      _side = null;
    });
    if (result != null && identical(parcel, _parcel)) {
      widget.onCommit(parcel.withSetback(index, result == 0 ? null : result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final editing = _parcel != null;
    final draft = List<Offset>.of(_vertices);
    if (!widget.editingSetbacks && _aim != null) {
      if (_vertex != null) {
        draft[_vertex!] = _aim!;
      } else if (!editing && draft.isNotEmpty && draft.last != _aim) {
        draft.add(_aim!);
      }
    }
    final side = _side == null ? null : _parcel?.side(_side!);
    final hint = _invalid
        ? l.architectSiteParcelInvalid
        : widget.editingSetbacks
        ? l.architectSitePickBoundary
        : !editing
        ? l.architectSiteParcelTrace
        : _vertex == null
        ? l.architectSiteParcelEdit
        : l.architectSiteParcelMoveVertex;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ParcelPreview(
                widget.editingSetbacks
                    ? []
                    : draft.map(widget.toScreen).toList(),
                editing,
                side == null
                    ? null
                    : (widget.toScreen(side.$1), widget.toScreen(side.$2)),
                _invalid ? colors.error : colors.primary,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ArchitectTransformPointInput(
            key: const ValueKey('architect-site-parcel-input'),
            toModel: widget.toModel,
            toScreen: widget.toScreen,
            snap: _resolve,
            localizeSnap: (_) => null,
            onAim: (snap) => setState(() => _aim = snap.point),
            onPick: (snap) => _pick(snap.point),
            onNavigate: widget.onNavigate,
            pickingEnabled: !_dialogOpen,
            singlePointerPan: true,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(hint)),
                      if (!editing && !widget.editingSetbacks)
                        Tooltip(
                          message: l.architectSiteParcelCalibrationHint,
                          child: const Icon(Icons.help_outline, size: 18),
                        ),
                      IconButton(
                        tooltip: l.cancel,
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (!widget.editingSetbacks)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!editing && _vertices.isNotEmpty)
                          IconButton(
                            tooltip: l.undoPoint,
                            icon: const Icon(Icons.undo),
                            onPressed: () => setState(() {
                              _vertices.removeLast();
                              _aim = null;
                              _invalid = false;
                            }),
                          ),
                        FilledButton(
                          key: const ValueKey('architect-site-parcel-apply'),
                          onPressed: _vertices.length >= 3 && _vertex == null
                              ? _finish
                              : null,
                          child: Text(
                            editing
                                ? l.applyAction
                                : l.architectSiteParcelClose,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParcelPreview extends CustomPainter {
  final List<Offset> points;
  final bool closed;
  final ArchitectSiteSegment? side;
  final Color color;

  _ParcelPreview(this.points, this.closed, this.side, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (points.length > 1) {
      canvas.drawPath(Path()..addPolygon(points, closed), ink);
    }
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, ink);
    }
    if (side case final line?) {
      canvas.drawLine(line.$1, line.$2, ink..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(_ParcelPreview old) => true;
}
