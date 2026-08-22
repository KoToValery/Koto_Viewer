import 'dart:convert';

enum FileCategory {
  all,
  cad2d,
  cad3d,
  pcb,
  documents,
}

extension FileCategoryExtension on FileCategory {
  String get label {
    switch (this) {
      case FileCategory.all:
        return 'All';
      case FileCategory.cad2d:
        return '2D CAD';
      case FileCategory.cad3d:
        return '3D Models';
      case FileCategory.pcb:
        return 'PCB & Hardware';
      case FileCategory.documents:
        return 'Documents';
    }
  }

  String get shortLabel {
    switch (this) {
      case FileCategory.all:
        return 'All';
      case FileCategory.cad2d:
        return '2D CAD';
      case FileCategory.cad3d:
        return '3D';
      case FileCategory.pcb:
        return 'PCB';
      case FileCategory.documents:
        return 'Docs';
    }
  }
}

enum KotoFileType { pdf, dxf, dwg, svg, stl, obj, gltf, glb, xlsx, txt, md, docx, eps, gbr, drl, kicad, plt, step, iges, pptx, ppt, rtf, zip, other }

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
    if (lower.endsWith('.step') || lower.endsWith('.stp') || lower.endsWith('.p21')) return KotoFileType.step;
    if (lower.endsWith('.iges') || lower.endsWith('.igs')) return KotoFileType.iges;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return KotoFileType.xlsx;
    if (lower.endsWith('.txt') || lower.endsWith('.log') || lower.endsWith('.csv')) return KotoFileType.txt;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return KotoFileType.md;
    if (lower.endsWith('.docx')) return KotoFileType.docx;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppsx')) return KotoFileType.pptx;
    if (lower.endsWith('.ppt') || lower.endsWith('.pps')) return KotoFileType.ppt;
    if (lower.endsWith('.rtf')) return KotoFileType.rtf;
    if (lower.endsWith('.eps')) return KotoFileType.eps;
    if (lower.endsWith('.zip')) return KotoFileType.zip;
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
        lower.endsWith('.gm2') ||
        lower.endsWith('.top') ||
        lower.endsWith('.bot') ||
        lower.endsWith('.smt') ||
        lower.endsWith('.smb') ||
        lower.endsWith('.sst') ||
        lower.endsWith('.ssb') ||
        lower.endsWith('.edge')) {
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
      fileType == KotoFileType.glb ||
      fileType == KotoFileType.step ||
      fileType == KotoFileType.iges;
  bool get isStep => fileType == KotoFileType.step;
  bool get isIges => fileType == KotoFileType.iges;
  bool get isXlsx => fileType == KotoFileType.xlsx;
  bool get isTxt => fileType == KotoFileType.txt;
  bool get isMd => fileType == KotoFileType.md;
  bool get isDocx => fileType == KotoFileType.docx;
  bool get isPptx => fileType == KotoFileType.pptx;
  bool get isPpt => fileType == KotoFileType.ppt;
  bool get isPresentation => isPptx || isPpt;
  bool get isRtf => fileType == KotoFileType.rtf;
  bool get isEps => fileType == KotoFileType.eps;
  bool get isGerber => fileType == KotoFileType.gbr;
  bool get isDrill => fileType == KotoFileType.drl;
  bool get isKicad => fileType == KotoFileType.kicad;
  bool get isZip => fileType == KotoFileType.zip;
  bool get isPlotter => fileType == KotoFileType.plt;
  bool get isPcb => isGerber || isDrill || isKicad || isZip;
  bool get isVector => isSvg || isEps || isPcb || isPlotter;
  bool get isTextDoc => isTxt || isMd || isDocx || isRtf || isPresentation;

  FileCategory get category {
    if (is3d) return FileCategory.cad3d;
    if (isCad || isPlotter || isSvg || isEps) return FileCategory.cad2d;
    if (isPcb) return FileCategory.pcb;
    return FileCategory.documents;
  }

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
