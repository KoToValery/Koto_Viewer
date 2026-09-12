import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'dicom_parser.dart';

/// Interaction mode for the DICOM canvas
enum DicomInteractionMode {
  panZoom,
  windowLevel,
  ruler,
}

/// Represents an on-screen caliper measurement between two points.
class DicomMeasurement {
  /// Start point in image pixel coordinates
  final Offset start;

  /// End point in image pixel coordinates
  final Offset end;

  /// Physical spacing (row = dy, col = dx) in mm per pixel
  final double? pixelSpacingRow;
  final double? pixelSpacingCol;

  const DicomMeasurement({
    required this.start,
    required this.end,
    this.pixelSpacingRow,
    this.pixelSpacingCol,
  });

  /// Distance in physical millimeters if spacing is available, else in pixels.
  double get distance {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    if (pixelSpacingRow != null && pixelSpacingCol != null) {
      final physicalDx = dx * pixelSpacingCol!;
      final physicalDy = dy * pixelSpacingRow!;
      return math.sqrt(physicalDx * physicalDx + physicalDy * physicalDy);
    }

    return math.sqrt(dx * dx + dy * dy);
  }

  bool get isCalibrated => pixelSpacingRow != null && pixelSpacingCol != null;

  String get formattedDistance {
    final dist = distance;
    if (isCalibrated) {
      if (dist >= 10) {
        return '${dist.toStringAsFixed(1)} mm';
      } else {
        return '${dist.toStringAsFixed(2)} mm';
      }
    }
    return '${dist.toStringAsFixed(0)} px';
  }
}

/// Represents a single slice / frame in a DICOM series.
class DicomSliceItem {
  final int sliceIndex;
  final String? filePath;
  final Uint8List? rawBytes;
  final int frameIndex;
  final DicomHeader header;

  const DicomSliceItem({
    required this.sliceIndex,
    this.filePath,
    this.rawBytes,
    this.frameIndex = 0,
    required this.header,
  });

  int? get instanceNumber => header.instanceNumber;
  double? get sliceLocation => header.sliceLocation;
  double? get sliceThickness => header.sliceThickness;

  /// Asynchronously retrieve the file bytes for this slice.
  Future<Uint8List> getBytes() async {
    if (rawBytes != null && rawBytes!.isNotEmpty) {
      return rawBytes!;
    }
    if (filePath != null) {
      return File(filePath!).readAsBytes();
    }
    throw StateError('DicomSliceItem has neither rawBytes nor a valid filePath.');
  }
}

/// Represents a series of DICOM slices (e.g. Axial CT, Coronal reconstruction).
class DicomSeriesItem {
  final String seriesInstanceUID;
  final String seriesDescription;
  final String modality;
  final List<DicomSliceItem> slices;

  const DicomSeriesItem({
    required this.seriesInstanceUID,
    required this.seriesDescription,
    required this.modality,
    required this.slices,
  });

  int get sliceCount => slices.length;
  DicomSliceItem get firstSlice => slices.first;
  DicomHeader get representativeHeader => slices.first.header;
}

/// Represents a complete DICOM study containing one or more series.
class DicomStudyItem {
  final String studyInstanceUID;
  final String studyDescription;
  final String studyDate;
  final String patientName;
  final String patientId;
  final String? patientAge;
  final String? patientSex;
  final List<DicomSeriesItem> series;

  /// Optional temporary directory to clean up on disposal (e.g. for unzipped studies).
  final Directory? tempDirectory;

  const DicomStudyItem({
    required this.studyInstanceUID,
    required this.studyDescription,
    required this.studyDate,
    required this.patientName,
    required this.patientId,
    this.patientAge,
    this.patientSex,
    required this.series,
    this.tempDirectory,
  });

  int get totalSlices => series.fold(0, (sum, s) => sum + s.sliceCount);

  /// Cleanup temporary files if any were created during unzipping.
  void dispose() {
    if (tempDirectory != null && tempDirectory!.existsSync()) {
      try {
        tempDirectory!.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
