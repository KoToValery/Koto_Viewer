import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'dicom_models.dart';
import 'dicom_parser.dart';

/// Payload passed into isolates for parsing
class _StudyScanPayload {
  final String path;
  final bool isZip;
  final bool isDirectory;

  const _StudyScanPayload({
    required this.path,
    required this.isZip,
    required this.isDirectory,
  });
}

/// Lightweight intermediate representation transferred across isolates
class _RawSliceInfo {
  final String filePath;
  final int frameIndex;
  final DicomHeader header;

  const _RawSliceInfo({
    required this.filePath,
    this.frameIndex = 0,
    required this.header,
  });
}

class _ScanResult {
  final String studyInstanceUID;
  final String studyDescription;
  final String studyDate;
  final String patientName;
  final String patientId;
  final String? patientAge;
  final String? patientSex;
  final String? tempDirPath;
  final List<Map<String, dynamic>> rawSeries;

  const _ScanResult({
    required this.studyInstanceUID,
    required this.studyDescription,
    required this.studyDate,
    required this.patientName,
    required this.patientId,
    this.patientAge,
    this.patientSex,
    this.tempDirPath,
    required this.rawSeries,
  });
}

/// Background isolate worker for scanning directories and zip files
_ScanResult _scanInIsolate(_StudyScanPayload payload) {
  String? tempDirPath;
  Directory scanDir;

  if (payload.isZip) {
    // Unzip to a temporary directory
    final tempDir = Directory.systemTemp.createTempSync('koto_dicom_');
    tempDirPath = tempDir.path;

    final zipFile = File(payload.path);
    final zipBytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);

    for (final file in archive) {
      if (!file.isFile) continue;
      final rawName = file.name.replaceAll('\\', '/');
      final baseName = rawName.split('/').last.toLowerCase();

      // Skip OS / metadata junk
      if (baseName.startsWith('__macosx') ||
          baseName.startsWith('.') ||
          baseName == 'thumbs.db' ||
          baseName.endsWith('.ds_store')) {
        continue;
      }

      final content = file.content;
      if (content is! List<int> || content.isEmpty) continue;

      // Extract file to temp folder
      final targetFile = File('${tempDir.path}/$rawName');
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsBytesSync(content, flush: true);
    }

    scanDir = tempDir;
  } else if (payload.isDirectory) {
    scanDir = Directory(payload.path);
  } else {
    // Single file treated as 1-file scan
    final file = File(payload.path);
    final bytes = file.readAsBytesSync();
    final header = DicomParser.parse(bytes);

    final rawSeries = <Map<String, dynamic>>[];
    final slices = <_RawSliceInfo>[];

    if (header.numberOfFrames > 1) {
      for (int f = 0; f < header.numberOfFrames; f++) {
        slices.add(_RawSliceInfo(
          filePath: payload.path,
          frameIndex: f,
          header: header,
        ));
      }
    } else {
      slices.add(_RawSliceInfo(
        filePath: payload.path,
        frameIndex: 0,
        header: header,
      ));
    }

    rawSeries.add({
      'uid': header.seriesInstanceUID ?? 'Series_1',
      'desc': header.seriesDescription ?? (header.modality != null ? '${header.modality} Series' : 'Series 1'),
      'modality': header.modality ?? 'DICOM',
      'slices': slices,
    });

    return _ScanResult(
      studyInstanceUID: header.studyInstanceUID ?? 'Study_1',
      studyDescription: header.studyDescription ?? 'DICOM Study',
      studyDate: header.formattedStudyDate,
      patientName: header.formattedPatientName,
      patientId: header.patientId ?? 'Unknown',
      patientAge: header.patientAge,
      patientSex: header.patientSex,
      tempDirPath: null,
      rawSeries: rawSeries,
    );
  }

  // --- Scan Directory Recursively ---
  final Map<String, List<_RawSliceInfo>> seriesMap = {};
  final Map<String, String> seriesDescMap = {};
  final Map<String, String> seriesModalityMap = {};

  String studyInstanceUID = 'Study_1';
  String studyDescription = 'DICOM Study';
  String studyDate = '';
  String patientName = 'Unknown';
  String patientId = 'Unknown';
  String? patientAge;
  String? patientSex;

  void processFile(File f) {
    final lower = f.path.toLowerCase();
    final fileName = lower.split(Platform.pathSeparator).last;

    if (fileName.startsWith('.') ||
        fileName.startsWith('__') ||
        fileName.endsWith('.ds_store') ||
        fileName.endsWith('.txt') ||
        fileName.endsWith('.xml') ||
        fileName.endsWith('.pdf')) {
      return;
    }

    // Check if it's DICOM
    final isDcmExt = lower.endsWith('.dcm') || lower.endsWith('.dicom');
    if (!isDcmExt && !DicomParser.isDicomFile(f)) {
      return;
    }

    try {
      final bytes = f.readAsBytesSync();
      final header = DicomParser.parse(bytes);

      if (studyInstanceUID == 'Study_1' && header.studyInstanceUID != null) {
        studyInstanceUID = header.studyInstanceUID!;
      }
      if (studyDescription == 'DICOM Study' && header.studyDescription != null) {
        studyDescription = header.studyDescription!;
      }
      if (studyDate.isEmpty && header.formattedStudyDate.isNotEmpty) {
        studyDate = header.formattedStudyDate;
      }
      if (patientName == 'Unknown' && header.patientName != null) {
        patientName = header.formattedPatientName;
      }
      if (patientId == 'Unknown' && header.patientId != null) {
        patientId = header.patientId!;
      }
      if (patientAge == null && header.patientAge != null) {
        patientAge = header.patientAge;
      }
      if (patientSex == null && header.patientSex != null) {
        patientSex = header.patientSex;
      }

      final sUid = header.seriesInstanceUID ?? 'Series_Default';
      seriesMap.putIfAbsent(sUid, () => []);

      if (header.numberOfFrames > 1) {
        for (int frame = 0; frame < header.numberOfFrames; frame++) {
          seriesMap[sUid]!.add(_RawSliceInfo(
            filePath: f.path,
            frameIndex: frame,
            header: header,
          ));
        }
      } else {
        seriesMap[sUid]!.add(_RawSliceInfo(
          filePath: f.path,
          frameIndex: 0,
          header: header,
        ));
      }

      if (!seriesDescMap.containsKey(sUid)) {
        seriesDescMap[sUid] = header.seriesDescription ??
            (header.modality != null ? '${header.modality} Series' : 'Series ${seriesMap.length}');
      }
      if (!seriesModalityMap.containsKey(sUid)) {
        seriesModalityMap[sUid] = header.modality ?? 'DICOM';
      }
    } catch (_) {
      // Ignore unparseable or corrupted files gracefully
    }
  }

  if (scanDir.existsSync()) {
    final entities = scanDir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity is File) {
        processFile(entity);
      }
    }
  }

  // Sort slices within each series
  final rawSeries = <Map<String, dynamic>>[];
  for (final entry in seriesMap.entries) {
    final sUid = entry.key;
    final slices = entry.value;

    slices.sort((a, b) {
      // 1. Try instanceNumber first
      final inA = a.header.instanceNumber;
      final inB = b.header.instanceNumber;
      if (inA != null && inB != null && inA != inB) {
        return inA.compareTo(inB);
      }

      // 2. Try sliceLocation next
      final locA = a.header.sliceLocation;
      final locB = b.header.sliceLocation;
      if (locA != null && locB != null && locA != locB) {
        return locA.compareTo(locB);
      }

      // 3. Try frameIndex
      if (a.frameIndex != b.frameIndex) {
        return a.frameIndex.compareTo(b.frameIndex);
      }

      // 4. Fallback to filePath
      return a.filePath.compareTo(b.filePath);
    });

    rawSeries.add({
      'uid': sUid,
      'desc': seriesDescMap[sUid] ?? 'Series',
      'modality': seriesModalityMap[sUid] ?? 'DICOM',
      'slices': slices,
    });
  }

  return _ScanResult(
    studyInstanceUID: studyInstanceUID,
    studyDescription: studyDescription,
    studyDate: studyDate,
    patientName: patientName,
    patientId: patientId,
    patientAge: patientAge,
    patientSex: patientSex,
    tempDirPath: tempDirPath,
    rawSeries: rawSeries,
  );
}

/// High-level service to scan and load DICOM studies from a file, directory, or ZIP archive.
class DicomStudyLoader {
  const DicomStudyLoader._();

  /// Quick check if a given ZIP archive contains DICOM files.
  static bool isDicomZip(String zipPath) {
    try {
      final file = File(zipPath);
      if (!file.existsSync()) return false;
      final bytes = file.readAsBytesSync();
      return isDicomZipBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Check if raw ZIP bytes contain DICOM files without full extraction.
  static bool isDicomZipBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      for (final file in archive) {
        if (!file.isFile) continue;
        final rawName = file.name.replaceAll('\\', '/');
        final lower = rawName.toLowerCase();
        final baseName = lower.split('/').last;

        if (baseName.startsWith('__') || baseName.startsWith('.')) continue;

        // Direct extension or DICOMDIR match
        if (lower.endsWith('.dcm') ||
            lower.endsWith('.dicom') ||
            baseName == 'dicomdir' ||
            lower.contains('/dicom/')) {
          return true;
        }

        // Test magic bytes on candidates (including extensionless or dot-separated UIDs)
        final ext = baseName.contains('.') ? baseName.split('.').last : '';
        const nonDicomExtensions = {
          'txt', 'png', 'jpg', 'jpeg', 'bmp', 'pdf', 'xml', 'html', 'json',
          'csv', 'zip', 'exe', 'dll', 'doc', 'docx'
        };
        if (!nonDicomExtensions.contains(ext)) {
          final content = file.content;
          if (content is List<int> && content.length >= 132) {
            if (content[128] == 0x44 &&
                content[129] == 0x49 &&
                content[130] == 0x43 &&
                content[131] == 0x4D) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Load a DICOM study from a file, folder, or zip archive path.
  static Future<DicomStudyItem> load(String path) async {
    final lower = path.toLowerCase();
    final isZip = lower.endsWith('.zip');
    final isDir = Directory(path).existsSync();

    final result = await compute(
      _scanInIsolate,
      _StudyScanPayload(
        path: path,
        isZip: isZip,
        isDirectory: isDir,
      ),
    );

    final seriesList = <DicomSeriesItem>[];
    for (final raw in result.rawSeries) {
      final uid = raw['uid'] as String;
      final desc = raw['desc'] as String;
      final modality = raw['modality'] as String;
      final rawSlices = raw['slices'] as List<_RawSliceInfo>;

      final slices = <DicomSliceItem>[];
      for (int i = 0; i < rawSlices.length; i++) {
        final info = rawSlices[i];
        slices.add(DicomSliceItem(
          sliceIndex: i,
          filePath: info.filePath,
          frameIndex: info.frameIndex,
          header: info.header,
        ));
      }

      if (slices.isNotEmpty) {
        seriesList.add(DicomSeriesItem(
          seriesInstanceUID: uid,
          seriesDescription: desc,
          modality: modality,
          slices: slices,
        ));
      }
    }

    if (seriesList.isEmpty) {
      throw DicomParseException('No readable DICOM slices found in $path');
    }

    return DicomStudyItem(
      studyInstanceUID: result.studyInstanceUID,
      studyDescription: result.studyDescription,
      studyDate: result.studyDate,
      patientName: result.patientName,
      patientId: result.patientId,
      patientAge: result.patientAge,
      patientSex: result.patientSex,
      series: seriesList,
      tempDirectory: result.tempDirPath != null ? Directory(result.tempDirPath!) : null,
    );
  }
}
