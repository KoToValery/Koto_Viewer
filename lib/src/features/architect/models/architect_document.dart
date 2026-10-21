import 'dart:ui';

enum ArchitectAnnotationRole {
  ordinary,
  dimension,
  area,
  roomName,
  title,
  table,
  symbol,
}

enum ArchitectDrawingKind { plan, section, elevation }

enum ArchitectTitleField { text, project, drawing, number, scale, author, date }

double _number(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
Offset _point(Object? value) {
  final p = value as List? ?? const [0, 0];
  return Offset(_number(p[0], 0), _number(p[1], 0));
}

List<double> _xy(Offset p) => [p.dx, p.dy];
Rect _rect(Object? value) {
  final r = value as List? ?? const [0, 0, 100, 100];
  return Rect.fromLTWH(
    _number(r[0], 0),
    _number(r[1], 0),
    _number(r[2], 100),
    _number(r[3], 100),
  );
}

List<double> _rectJson(Rect r) => [r.left, r.top, r.width, r.height];

/// Paper millimetres and model metres are independent of display/input units.
class ArchitectDrawingScale {
  /// OS/2 sCapHeight / unitsPerEm of bundled Noto Sans. Paper text sizes
  /// describe capital-letter height, rather than the font's larger em square.
  static const fontCapRatio = .714;
  static const presets = [20, 50, 100, 200, 500];
  final int denominator;
  const ArchitectDrawingScale(this.denominator) : assert(denominator > 0);
  double modelToPaper(double metres) => metres * 1000 / denominator;
  double paperToModel(double mm) => mm * denominator / 1000;
  String get ratio => '1:$denominator';
  double get defaultTextMm => denominator <= 50 ? 1.5 : 2.2;
}

class ArchitectSavedDrawing {
  final String id, sourceId, name;
  final ArchitectDrawingKind kind;
  final int scale;
  final int sourceNumber;
  final bool roof;
  final Map<String, bool> visibility;
  const ArchitectSavedDrawing({
    required this.id,
    required this.sourceId,
    required this.kind,
    this.name = '',
    this.scale = 100,
    this.sourceNumber = 1,
    this.roof = false,
    this.visibility = const {},
  });
  ArchitectSavedDrawing copyWith({
    String? name,
    int? scale,
    Map<String, bool>? visibility,
  }) => ArchitectSavedDrawing(
    id: id,
    sourceId: sourceId,
    kind: kind,
    name: name ?? this.name,
    scale: scale ?? this.scale,
    sourceNumber: sourceNumber,
    roof: roof,
    visibility: visibility ?? this.visibility,
  );
  String get sourceKey => '${kind.name}:$sourceId';
  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'kind': kind.name,
    'name': name,
    'scale': scale,
    'sourceNumber': sourceNumber,
    'roof': roof,
    'visibility': visibility,
  };
  factory ArchitectSavedDrawing.fromJson(Map j) => ArchitectSavedDrawing(
    id: j['id'] as String,
    sourceId: j['sourceId'] as String,
    kind: ArchitectDrawingKind.values.byName(j['kind'] as String),
    name: j['name'] as String? ?? '',
    scale: (j['scale'] as num?)?.toInt() ?? 100,
    sourceNumber: (j['sourceNumber'] as num?)?.toInt() ?? 1,
    roof: j['roof'] == true,
    visibility: Map<String, bool>.from(j['visibility'] as Map? ?? {}),
  );
}

/// Frame is on paper (mm); anchor is a fixed point in the source view (metres).
class ArchitectDrawingPlacement {
  final String id, drawingId, number;
  final Rect frame;
  final Offset anchor;
  final int scale;
  final double rotation;
  final bool locked, showTitle;
  const ArchitectDrawingPlacement({
    required this.id,
    required this.drawingId,
    required this.frame,
    required this.anchor,
    this.number = '1',
    this.scale = 100,
    this.rotation = 0,
    this.locked = false,
    this.showTitle = true,
  });
  ArchitectDrawingPlacement copyWith({
    String? drawingId,
    String? number,
    Rect? frame,
    Offset? anchor,
    int? scale,
    double? rotation,
    bool? locked,
    bool? showTitle,
  }) => ArchitectDrawingPlacement(
    id: id,
    drawingId: drawingId ?? this.drawingId,
    number: number ?? this.number,
    frame: frame ?? this.frame,
    anchor: anchor ?? this.anchor,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    locked: locked ?? this.locked,
    showTitle: showTitle ?? this.showTitle,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'drawingId': drawingId,
    'number': number,
    'frame': _rectJson(frame),
    'anchor': _xy(anchor),
    'scale': scale,
    'rotation': rotation,
    'locked': locked,
    'showTitle': showTitle,
  };
  factory ArchitectDrawingPlacement.fromJson(Map j) =>
      ArchitectDrawingPlacement(
        id: j['id'] as String,
        drawingId: j['drawingId'] as String,
        number: j['number'] as String? ?? '1',
        frame: _rect(j['frame']),
        anchor: _point(j['anchor']),
        scale: (j['scale'] as num?)?.toInt() ?? 100,
        rotation: _number(j['rotation'], 0),
        locked: j['locked'] == true,
        showTitle: j['showTitle'] != false,
      );
}

class ArchitectTitleItem {
  final String id, text;
  final ArchitectTitleField field;
  final Rect rect;
  final double textMm;
  final bool border;
  const ArchitectTitleItem({
    required this.id,
    required this.rect,
    this.field = ArchitectTitleField.text,
    this.text = '',
    this.textMm = 2.2,
    this.border = true,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'rect': _rectJson(rect),
    'field': field.name,
    'text': text,
    'textMm': textMm,
    'border': border,
  };
  factory ArchitectTitleItem.fromJson(Map j) => ArchitectTitleItem(
    id: j['id'] as String,
    rect: _rect(j['rect']),
    field: ArchitectTitleField.values.byName(j['field'] as String),
    text: j['text'] as String? ?? '',
    textMm: _number(j['textMm'], 2.2),
    border: j['border'] != false,
  );
}

class ArchitectSheetTemplate {
  final String id, name;
  final List<ArchitectTitleItem> items;
  const ArchitectSheetTemplate({
    required this.id,
    this.name = '',
    this.items = const [],
  });
  static const standard = ArchitectSheetTemplate(
    id: 'standard',
    items: [
      ArchitectTitleItem(
        id: 'project',
        rect: Rect.fromLTWH(0, 0, 180, 10),
        field: ArchitectTitleField.project,
        textMm: 3.3,
      ),
      ArchitectTitleItem(
        id: 'drawing',
        rect: Rect.fromLTWH(0, 10, 180, 10),
        field: ArchitectTitleField.drawing,
      ),
      ArchitectTitleItem(
        id: 'number',
        rect: Rect.fromLTWH(0, 20, 40, 10),
        field: ArchitectTitleField.number,
      ),
      ArchitectTitleItem(
        id: 'scale',
        rect: Rect.fromLTWH(40, 20, 40, 10),
        field: ArchitectTitleField.scale,
      ),
      ArchitectTitleItem(
        id: 'author',
        rect: Rect.fromLTWH(80, 20, 60, 10),
        field: ArchitectTitleField.author,
      ),
      ArchitectTitleItem(
        id: 'date',
        rect: Rect.fromLTWH(140, 20, 40, 10),
        field: ArchitectTitleField.date,
      ),
    ],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };
  factory ArchitectSheetTemplate.fromJson(Map j) => ArchitectSheetTemplate(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    items: (j['items'] as List? ?? [])
        .map((e) => ArchitectTitleItem.fromJson(e as Map))
        .toList(),
  );
}

class ArchitectSheet {
  final String id, name, number, templateId, author, date;
  final double widthMm, heightMm, marginMm;
  final List<ArchitectDrawingPlacement> placements;
  const ArchitectSheet({
    required this.id,
    this.name = '',
    this.number = 'A-01',
    this.templateId = 'standard',
    this.author = '',
    this.date = '',
    this.widthMm = 420,
    this.heightMm = 297,
    this.marginMm = 10,
    this.placements = const [],
  });
  ArchitectSheet copyWith({
    String? name,
    String? number,
    String? templateId,
    String? author,
    String? date,
    double? widthMm,
    double? heightMm,
    double? marginMm,
    List<ArchitectDrawingPlacement>? placements,
  }) => ArchitectSheet(
    id: id,
    name: name ?? this.name,
    number: number ?? this.number,
    templateId: templateId ?? this.templateId,
    author: author ?? this.author,
    date: date ?? this.date,
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    marginMm: marginMm ?? this.marginMm,
    placements: placements ?? this.placements,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'templateId': templateId,
    'author': author,
    'date': date,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'marginMm': marginMm,
    'placements': placements.map((e) => e.toJson()).toList(),
  };
  factory ArchitectSheet.fromJson(Map j) => ArchitectSheet(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    number: j['number'] as String? ?? '',
    templateId: j['templateId'] as String? ?? 'standard',
    author: j['author'] as String? ?? '',
    date: j['date'] as String? ?? '',
    widthMm: _number(j['widthMm'], 420),
    heightMm: _number(j['heightMm'], 297),
    marginMm: _number(j['marginMm'], 10),
    placements: (j['placements'] as List? ?? [])
        .map((e) => ArchitectDrawingPlacement.fromJson(e as Map))
        .toList(),
  );
}

class ArchitectDocument {
  final Map<String, int> viewScales;

  /// Keys: scale/role for profiles; view/element/role/scale for overrides.
  final Map<String, double> profileMm, overrideMm;
  final List<ArchitectSavedDrawing> drawings;
  final List<ArchitectSheet> sheets;
  final List<ArchitectSheetTemplate> templates;
  const ArchitectDocument({
    this.viewScales = const {},
    this.profileMm = const {},
    this.overrideMm = const {},
    this.drawings = const [],
    this.sheets = const [],
    this.templates = const [ArchitectSheetTemplate.standard],
  });
  ArchitectDocument copyWith({
    Map<String, int>? viewScales,
    Map<String, double>? profileMm,
    Map<String, double>? overrideMm,
    List<ArchitectSavedDrawing>? drawings,
    List<ArchitectSheet>? sheets,
    List<ArchitectSheetTemplate>? templates,
  }) => ArchitectDocument(
    viewScales: viewScales ?? this.viewScales,
    profileMm: profileMm ?? this.profileMm,
    overrideMm: overrideMm ?? this.overrideMm,
    drawings: drawings ?? this.drawings,
    sheets: sheets ?? this.sheets,
    templates: templates ?? this.templates,
  );
  double textMm(
    String view,
    String element,
    ArchitectAnnotationRole role,
    int scale,
  ) {
    final base = ArchitectDrawingScale(scale).defaultTextMm;
    return overrideMm['$view/$element/${role.name}/$scale'] ??
        profileMm['$scale/${role.name}'] ??
        base *
            (role == ArchitectAnnotationRole.roomName
                ? 1.2
                : role == ArchitectAnnotationRole.title
                ? 1.5
                : 1);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'viewScales': viewScales,
    'profileMm': profileMm,
    'overrideMm': overrideMm,
    'drawings': drawings.map((e) => e.toJson()).toList(),
    'sheets': sheets.map((e) => e.toJson()).toList(),
    'templates': templates.map((e) => e.toJson()).toList(),
  };
  factory ArchitectDocument.fromProjectJson(Map json) {
    if (json['document'] is Map) {
      return ArchitectDocument.fromJson(json['document'] as Map);
    }
    final scale = (json['dimensionScale'] as num?)?.toInt() ?? 100;
    final overrides = <String, double>{};
    void migrate(String view, Map data) {
      for (final a in data['annotations'] as List? ?? []) {
        final record = a as Map;
        overrides['$view/${record['id']}/ordinary/$scale'] =
            _number(record['fontSize'], .30) *
            1000 /
            scale *
            ArchitectDrawingScale.fontCapRatio;
      }
    }

    for (final s in json['storeys'] as List? ?? []) {
      migrate('plan:${s['id']}', s as Map);
    }
    for (final s in json['sections'] as List? ?? []) {
      migrate('section:${s['id']}', s['drawing'] as Map? ?? {});
    }
    for (final s in json['elevations'] as List? ?? []) {
      migrate('elevation:${s['id']}', s['drawing'] as Map? ?? {});
    }
    return ArchitectDocument(overrideMm: overrides);
  }
  factory ArchitectDocument.fromJson(Map j) => ArchitectDocument(
    viewScales: (j['viewScales'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    profileMm: (j['profileMm'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, _number(v, 2.2)),
    ),
    overrideMm: (j['overrideMm'] as Map? ?? {}).map(
      (k, v) => MapEntry(k as String, _number(v, 2.2)),
    ),
    drawings: (j['drawings'] as List? ?? [])
        .map((e) => ArchitectSavedDrawing.fromJson(e as Map))
        .toList(),
    sheets: (j['sheets'] as List? ?? [])
        .map((e) => ArchitectSheet.fromJson(e as Map))
        .toList(),
    templates: j['templates'] == null
        ? const [ArchitectSheetTemplate.standard]
        : (j['templates'] as List)
              .map((e) => ArchitectSheetTemplate.fromJson(e as Map))
              .toList(),
  );
}
