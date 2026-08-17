import 'dart:convert';

enum KotoFileType { pdf, dxf, dwg, svg, stl, obj, gltf, glb, xlsx, txt, md, docx, eps, gbr, drl, kicad, plt, other }

class PdfItem {
  final String path;
  final String name;
  final int sizeInBytes;
  final DateTime lastOpened;
  final int pageCount;

  PdfItem({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.lastOpened,
    this.pageCount = 0,
  });

  KotoFileType get fileType {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return KotoFileType.pdf;
    if (lower.endsWith('.dxf')) return KotoFileType.dxf;
    if (lower.endsWith('.dwg')) return KotoFileType.dwg;
    if (lower.endsWith('.svg')) return KotoFileType.svg;
    if (lower.endsWith('.stl')) return KotoFileType.stl;
    if (lower.endsWith('.obj')) return KotoFileType.obj;
    if (lower.endsWith('.gltf')) return KotoFileType.gltf;
    if (lower.endsWith('.glb')) return KotoFileType.glb;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return KotoFileType.xlsx;
    if (lower.endsWith('.txt') || lower.endsWith('.log') || lower.endsWith('.csv')) return KotoFileType.txt;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return KotoFileType.md;
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return KotoFileType.docx;
    if (lower.endsWith('.eps')) return KotoFileType.eps;
    if (lower.endsWith('.kicad_pcb') ||
        lower.endsWith('.kicad_sch') ||
        lower.endsWith('.kicad_sym') ||
        lower.endsWith('.sch') ||
        lower.endsWith('.brd')) {
      return KotoFileType.kicad;
    }
    if (lower.endsWith('.plt') ||
        lower.endsWith('.hpgl') ||
        lower.endsWith('.hpg') ||
        lower.endsWith('.prn')) {
      return KotoFileType.plt;
    }
    if (lower.endsWith('.gbr') ||
        lower.endsWith('.ger') ||
        lower.endsWith('.pho') ||
        lower.endsWith('.art') ||
        lower.endsWith('.gtl') ||
        lower.endsWith('.gbl') ||
        lower.endsWith('.gts') ||
        lower.endsWith('.gbs') ||
        lower.endsWith('.gto') ||
        lower.endsWith('.gbo') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1') ||
        lower.endsWith('.gm2')) {
      return KotoFileType.gbr;
    }
    if (lower.endsWith('.drl') ||
        lower.endsWith('.xln') ||
        lower.endsWith('.exc') ||
        lower.endsWith('.drd')) {
      return KotoFileType.drl;
    }
    return KotoFileType.other;
  }

  bool get isCad => fileType == KotoFileType.dxf || fileType == KotoFileType.dwg;
  bool get isSvg => fileType == KotoFileType.svg;
  bool get is3d =>
      fileType == KotoFileType.stl ||
      fileType == KotoFileType.obj ||
      fileType == KotoFileType.gltf ||
      fileType == KotoFileType.glb;
  bool get isXlsx => fileType == KotoFileType.xlsx;
  bool get isTxt => fileType == KotoFileType.txt;
  bool get isMd => fileType == KotoFileType.md;
  bool get isDocx => fileType == KotoFileType.docx;
  bool get isEps => fileType == KotoFileType.eps;
  bool get isGerber => fileType == KotoFileType.gbr;
  bool get isDrill => fileType == KotoFileType.drl;
  bool get isKicad => fileType == KotoFileType.kicad;
  bool get isPlotter => fileType == KotoFileType.plt;
  bool get isPcb => isGerber || isDrill || isKicad;
  bool get isVector => isSvg || isEps || isPcb || isPlotter;
  bool get isTextDoc => isTxt || isMd || isDocx;

  String get fileExtension {
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'sizeInBytes': sizeInBytes,
      'lastOpened': lastOpened.millisecondsSinceEpoch,
      'pageCount': pageCount,
    };
  }

  factory PdfItem.fromMap(Map<String, dynamic> map) {
    return PdfItem(
      path: map['path'] ?? '',
      name: map['name'] ?? '',
      sizeInBytes: map['sizeInBytes']?.toInt() ?? 0,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(map['lastOpened'] ?? 0),
      pageCount: map['pageCount']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory PdfItem.fromJson(String source) =>
      PdfItem.fromMap(json.decode(source));

  PdfItem copyWith({
    String? path,
    String? name,
    int? sizeInBytes,
    DateTime? lastOpened,
    int? pageCount,
  }) {
    return PdfItem(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastOpened: lastOpened ?? this.lastOpened,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}
