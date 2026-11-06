/// Cooperative cancellation shared by architectural exchange exporters.
class ArchitectExportCancelled implements Exception {
  const ArchitectExportCancelled();
}

class ArchitectExportElementError implements Exception {
  const ArchitectExportElementError(this.elementId, this.code);
  final String elementId, code;
}

void architectCheckExportCancelled(bool Function()? isCancelled) {
  if (isCancelled?.call() ?? false) throw const ArchitectExportCancelled();
}

/// Geometry that requires dart:ui stays on the UI isolate in short stages;
/// serialization receives plain data and runs in a worker isolate.
Future<void> architectExportCheckpoint(
  double progress, {
  void Function(double)? onProgress,
  bool Function()? isCancelled,
}) async {
  architectCheckExportCancelled(isCancelled);
  onProgress?.call(progress.clamp(0.0, 1.0));
  await Future<void>.delayed(Duration.zero);
  architectCheckExportCancelled(isCancelled);
}
