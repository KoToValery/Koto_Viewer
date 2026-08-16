import 'dart:convert';

enum KotoFileType { pdf, dxf, dwg, other }

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
    return KotoFileType.other;
  }

  bool get isCad => fileType == KotoFileType.dxf || fileType == KotoFileType.dwg;

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
