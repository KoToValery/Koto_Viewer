import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef AcadrustProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Rust DWG backend. Windows uses a child process; Android uses its existing
/// isolated service, so parser faults stay outside the Flutter process.
class AcadrustConverterService {
  static const androidChannel = MethodChannel(
    'com.koto.kotoviewer/dwg_converter',
  );
  static const cacheVersion = 7;
  static const conversionTimeout = Duration(minutes: 2);

  static String? findExecutable() {
    if (!Platform.isWindows) return null;
    final candidates = [
      '${File(Platform.resolvedExecutable).parent.path}/koto-acadrust.exe',
      '${Directory.current.path}/build/acadrust/x86_64-pc-windows-msvc/release/koto-acadrust.exe',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  static bool get isAvailable =>
      Platform.isAndroid || findExecutable() != null;

  /// Publishes only a successful, complete ASCII DXF; failed attempts cannot
  /// overwrite an existing cache or leave partial output for another backend.
  static Future<bool> convert({
    required String executable,
    required File input,
    required File output,
    AcadrustProcessRunner? processRunner,
  }) => _convertStaged(
    input: input,
    output: output,
    run: (source, destination) async {
      final result = await (processRunner ?? _runProcess)(executable, [
        source,
        destination,
      ]);
      if (result.exitCode != 0) {
        debugPrint(
          'AcadrustConverterService: exit ${result.exitCode}: ${result.stderr}',
        );
      }
      return result.exitCode == 0;
    },
  );

  static Future<bool> convertAndroid({
    required File input,
    required File output,
    MethodChannel channel = androidChannel,
  }) => _convertStaged(
    input: input,
    output: output,
    run: (source, destination) async =>
        await channel.invokeMethod<int>('convertDwg', {
          'inputPath': source,
          'outputPath': destination,
          'backend': 'acadrust',
        }) ==
        0,
  );

  static Future<bool> _convertStaged({
    required File input,
    required File output,
    required Future<bool> Function(String input, String output) run,
  }) async {
    Directory? workDir;
    try {
      workDir = await output.parent.createTemp('acadrust_');
      final stagedOutput = File('${workDir.path}/drawing.dxf');
      if (!await run(input.absolute.path, stagedOutput.absolute.path) ||
          !await isCompleteDxf(stagedOutput)) {
        debugPrint('AcadrustConverterService: conversion rejected');
        return false;
      }
      await stagedOutput.rename(output.path);
      return true;
    } on PlatformException {
      // Preserve typed OOM errors from the isolated Android worker.
      rethrow;
    } on Exception catch (error) {
      debugPrint('AcadrustConverterService: conversion failed: $error');
      return false;
    } finally {
      if (workDir != null) {
        try {
          await workDir.delete(recursive: true);
        } on FileSystemException catch (_) {
          // Best effort cleanup after the child process has exited.
        }
      }
    }
  }

  /// Validate cached and new files without reading a large drawing into memory.
  static Future<bool> isCompleteDxf(File file) async {
    if (!await file.exists() || await file.length() < 100) return false;
    final handle = await file.open();
    try {
      final length = await handle.length();
      // Layer metadata can be long, so validate the section structure at the
      // end, where every successful ASCII DXF must terminate with ENDSEC/EOF.
      await handle.setPosition(length > 256 ? length - 256 : 0);
      final tail = latin1.decode(await handle.read(256));
      return RegExp(
        r'0\s*\r?\nENDSEC\s*\r?\n\s*0\s*\r?\nEOF\s*$',
      ).hasMatch(tail);
    } finally {
      await handle.close();
    }
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) async {
    final process = await Process.start(executable, arguments);
    // Always drain both pipes, retaining only bounded diagnostic output.
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = _readDiagnostics(process.stderr);
    try {
      final exitCode = await process.exitCode.timeout(conversionTimeout);
      await stdoutDone;
      return ProcessResult(process.pid, exitCode, '', await stderrDone);
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      await stdoutDone;
      await stderrDone;
      rethrow;
    }
  }

  static Future<String> _readDiagnostics(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      final remaining = 8192 - bytes.length;
      if (remaining > 0) bytes.addAll(chunk.take(remaining));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
