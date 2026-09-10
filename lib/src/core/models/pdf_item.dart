import 'dart:convert';
import 'dart:io';

enum FileCategory {
  all,
  cad2d,
  cad3d,
  pcb,
  routes,
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
      case FileCategory.routes:
        return 'Routes & Maps';
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
      case FileCategory.routes:
        return 'Routes';
      case FileCategory.documents:
        return 'Docs';
    }
  }
}

enum KotoFileType { pdf, dxf, dwg, svg, stl, obj, gltf, glb, xlsx, txt, md, docx, eps, gbr, drl, kicad, plt, step, iges, ifc, pptx, rtf, zip, cdr, cbz, cbr, cbt, epub, fb2, gpx, kml, kmz, geojson, fbx, threeMf, lottie, font, ico, psd, code, csv, jupyter, dicom, other }

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
    if (lower.endsWith('.epub')) return KotoFileType.epub;
    if (lower.endsWith('.fb2') || lower.endsWith('.fb2.zip')) return KotoFileType.fb2;
    if (lower.endsWith('.cbz')) return KotoFileType.cbz;
    if (lower.endsWith('.cbr')) return KotoFileType.cbr;
    if (lower.endsWith('.cbt')) return KotoFileType.cbt;
    if (lower.endsWith('.dxf')) return KotoFileType.dxf;
    if (lower.endsWith('.dwg')) return KotoFileType.dwg;
    if (lower.endsWith('.svg')) return KotoFileType.svg;
    if (lower.endsWith('.stl')) return KotoFileType.stl;
    if (lower.endsWith('.obj')) return KotoFileType.obj;
    if (lower.endsWith('.gltf')) return KotoFileType.gltf;
    if (lower.endsWith('.glb')) return KotoFileType.glb;
    if (lower.endsWith('.fbx')) return KotoFileType.fbx;
    if (lower.endsWith('.3mf')) return KotoFileType.threeMf;
    if (lower.endsWith('.step') || lower.endsWith('.stp') || lower.endsWith('.p21')) return KotoFileType.step;
    if (lower.endsWith('.iges') || lower.endsWith('.igs')) return KotoFileType.iges;
    if (lower.endsWith('.ifc')) return KotoFileType.ifc;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return KotoFileType.xlsx;
    if (lower.endsWith('.ipynb')) return KotoFileType.jupyter;
    if (lower.endsWith('.csv') || lower.endsWith('.tsv')) return KotoFileType.csv;
    if (lower.endsWith('.txt') || lower.endsWith('.log')) return KotoFileType.txt;
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return KotoFileType.md;
    if (lower.endsWith('.docx')) return KotoFileType.docx;
    if (lower.endsWith('.pptx') || lower.endsWith('.ppsx') || lower.endsWith('.ppt') || lower.endsWith('.pps')) return KotoFileType.pptx;
    if (lower.endsWith('.rtf')) return KotoFileType.rtf;
    if (lower.endsWith('.eps')) return KotoFileType.eps;
    if (lower.endsWith('.cdr')) return KotoFileType.cdr;
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
    if (lower.endsWith('.gpx')) return KotoFileType.gpx;
    if (lower.endsWith('.kml')) return KotoFileType.kml;
    if (lower.endsWith('.kmz')) return KotoFileType.kmz;
    if (lower.endsWith('.geojson') || lower.endsWith('.geo.json')) return KotoFileType.geojson;
    if (lower.endsWith('.lottie')) return KotoFileType.lottie;
    if (lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.woff') || lower.endsWith('.woff2')) return KotoFileType.font;
    if (lower.endsWith('.ico')) return KotoFileType.ico;
    if (lower.endsWith('.psd') || lower.endsWith('.psb')) return KotoFileType.psd;
    if (lower.endsWith('.dcm') || lower.endsWith('.dicom')) return KotoFileType.dicom;
    
    // --- Docker files (matched by filename, not extension) ---
    final baseName = (name.contains('/')
            ? name.split('/').where((s) => s.isNotEmpty).last
            : (name.contains(Platform.pathSeparator)
                ? name.split(Platform.pathSeparator).last
                : name))
        .toLowerCase();
    final basePath = (path.contains('/')
            ? path.split('/').where((s) => s.isNotEmpty).last
            : (path.contains(Platform.pathSeparator)
                ? path.split(Platform.pathSeparator).last
                : path))
        .toLowerCase();

    bool isDocker(String str) {
      return str == 'dockerfile' ||
          str.startsWith('dockerfile.') ||
          str.endsWith('.dockerfile') ||
          str == '.dockerignore' ||
          str == 'docker-compose.yml' ||
          str == 'docker-compose.yaml' ||
          (str.startsWith('docker-compose.') &&
              (str.endsWith('.yml') || str.endsWith('.yaml')));
    }

    if (isDocker(baseName) || isDocker(basePath) || isDocker(lower)) {
      return KotoFileType.code;
    }

    if (lower.endsWith('.dart') || lower.endsWith('.js') || lower.endsWith('.mjs') || lower.endsWith('.ts') || lower.endsWith('.tsx') ||
        lower.endsWith('.py') || lower.endsWith('.pyw') || lower.endsWith('.java') || lower.endsWith('.kt') || lower.endsWith('.kts') ||
        lower.endsWith('.swift') || lower.endsWith('.cpp') || lower.endsWith('.cc') || lower.endsWith('.cxx') || lower.endsWith('.c') ||
        lower.endsWith('.h') || lower.endsWith('.hpp') || lower.endsWith('.cs') || lower.endsWith('.go') || lower.endsWith('.rs') ||
        lower.endsWith('.php') || lower.endsWith('.rb') || lower.endsWith('.sh') || lower.endsWith('.bash') || lower.endsWith('.ps1') ||
        lower.endsWith('.css') || lower.endsWith('.html') || lower.endsWith('.htm') || lower.endsWith('.json') || lower.endsWith('.xml') ||
        lower.endsWith('.yaml') || lower.endsWith('.yml') || lower.endsWith('.toml') || lower.endsWith('.ini') || lower.endsWith('.env') ||
        lower.endsWith('.sql') || lower.endsWith('.proto')) {
      return KotoFileType.code;
    }

    return KotoFileType.other;
  }

  bool get isCad => fileType == KotoFileType.dxf || fileType == KotoFileType.dwg;
  bool get isCode => fileType == KotoFileType.code;
  bool get isSvg => fileType == KotoFileType.svg;
  bool get isLottie => fileType == KotoFileType.lottie;
  bool get isFont => fileType == KotoFileType.font;
  bool get isIco => fileType == KotoFileType.ico;
  bool get isPsd => fileType == KotoFileType.psd;
  bool get isDicom => fileType == KotoFileType.dicom;
  bool get isComic => fileType == KotoFileType.cbz || fileType == KotoFileType.cbr || fileType == KotoFileType.cbt;
  bool get isEbook => fileType == KotoFileType.epub || fileType == KotoFileType.fb2;
  bool get isRoute =>
      fileType == KotoFileType.gpx ||
      fileType == KotoFileType.kml ||
      fileType == KotoFileType.kmz ||
      fileType == KotoFileType.geojson;
  bool get is3d =>
      fileType == KotoFileType.stl ||
      fileType == KotoFileType.obj ||
      fileType == KotoFileType.gltf ||
      fileType == KotoFileType.glb ||
      fileType == KotoFileType.fbx ||
      fileType == KotoFileType.step ||
      fileType == KotoFileType.iges ||
      fileType == KotoFileType.ifc ||
      fileType == KotoFileType.threeMf;
  bool get isFbx => fileType == KotoFileType.fbx;
  bool get isThreeMf => fileType == KotoFileType.threeMf;
  bool get isStep => fileType == KotoFileType.step;
  bool get isIges => fileType == KotoFileType.iges;
  bool get isIfc => fileType == KotoFileType.ifc;
  bool get isXlsx => fileType == KotoFileType.xlsx;
  bool get isTxt => fileType == KotoFileType.txt;
  bool get isCsv => fileType == KotoFileType.csv;
  bool get isJupyter => fileType == KotoFileType.jupyter;
  bool get isMd => fileType == KotoFileType.md;
  bool get isDocx => fileType == KotoFileType.docx;
  bool get isPptx => fileType == KotoFileType.pptx;
  bool get isPresentation => isPptx;
  bool get isRtf => fileType == KotoFileType.rtf;
  bool get isEps => fileType == KotoFileType.eps;
  bool get isCdr => fileType == KotoFileType.cdr;
  bool get isGerber => fileType == KotoFileType.gbr;
  bool get isDrill => fileType == KotoFileType.drl;
  bool get isKicad => fileType == KotoFileType.kicad;
  bool get isZip => fileType == KotoFileType.zip;
  bool get isPlotter => fileType == KotoFileType.plt;
  bool get isPcb => isGerber || isDrill || isKicad || isZip;
  bool get isVector => isSvg || isEps || isCdr || isPcb || isPlotter;
  bool get isTextDoc => isTxt || isCsv || isJupyter || isMd || isDocx || isRtf || isPresentation || isComic || isEbook;

  FileCategory get category {
    if (isRoute) return FileCategory.routes;
    if (is3d) return FileCategory.cad3d;
    if (isCad || isPlotter || isSvg || isEps || isCdr) return FileCategory.cad2d;
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
