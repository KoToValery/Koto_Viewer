import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../errors/app_error_handler.dart';
import '../models/pdf_item.dart';
import 'recent_files_service.dart';

/// LAN HTTP server for sharing files and receiving uploads (e.g. large ZIP presentations, CAD, 3D, PDF).
/// Uses streaming to disk with flat, minimal RAM consumption.
class LocalServerService {
  LocalServerService._();

  static HttpServer? _server;
  static String? _serverUrl;
  static String? _ipAddress;
  static int? _port;
  static String? _serverName;

  static bool _isRunning = false;
  static bool _isReceiveMode = false;

  static Timer? _autoShutdownTimer;
  static DateTime? _shutdownAt;

  static final Random _random = Random.secure();

  static final StreamController<File> _fileReceivedController =
      StreamController<File>.broadcast();

  /// Emits whenever a file is successfully uploaded to this server from LAN.
  static Stream<File> get onFileReceived => _fileReceivedController.stream;

  static const String _baseName = 'KoTo Viewer';
  static const int _preferredPort = 8080;
  static const Duration defaultShutdownTimeout = Duration(minutes: 15);

  static bool get isRunning => _isRunning;
  static bool get isReceiveMode => _isReceiveMode;
  static String? get serverUrl => _serverUrl;
  static String? get shareUrl => _serverUrl;
  static String? get ipAddress => _ipAddress;
  static int? get port => _port;
  static String? get serverName => _serverName;

  static String get serverDisplayName {
    final name = _serverName ?? _baseName;
    final port = _port ?? _preferredPort;
    return '$name • $port';
  }

  static int get remainingSeconds {
    final shutdownAt = _shutdownAt;

    if (!_isRunning || shutdownAt == null) {
      return 0;
    }

    final seconds = shutdownAt.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  /// Starts the local server in Receive/Upload mode (without requiring a preselected file).
  static Future<String?> startReceiveServer({
    Duration? shutdownTimeout,
  }) async {
    return startServer(
      null,
      isReceiveMode: true,
      shutdownTimeout: shutdownTimeout,
    );
  }

  /// Starts the local server and returns its LAN address.
  /// If [filePath] is provided, it serves that file for download.
  /// If [filePath] is null or [isReceiveMode] is true, it serves the upload hub.
  static Future<String?> startServer(
    String? filePath, {
    String? fileName,
    Duration? shutdownTimeout,
    bool isReceiveMode = false,
  }) async {
    await stopServer();

    try {
      File? file;
      String? resolvedName;
      String extension = '';

      if (filePath != null) {
        file = File(filePath);
        if (!await file.exists()) {
          throw FileSystemException('File does not exist', filePath);
        }
        resolvedName = _safeFileName(
          fileName ?? file.path.split(Platform.pathSeparator).last,
        );
        extension = _extensionOf(resolvedName);
      }

      final ip = await _resolveLanIpv4();

      if (ip == null) {
        throw StateError(
          'No LAN IPv4 address found. Connect the device to Wi-Fi first.',
        );
      }

      final serverName = _generateServerName();

      final handler = _buildHandler(
        file: file,
        fileName: resolvedName,
        extension: extension,
        serverName: serverName,
        isReceiveOnly: filePath == null || isReceiveMode,
      );

      final server = await _bindServer(handler);

      _server = server;
      _ipAddress = ip;
      _port = server.port;
      _serverName = serverName;
      _isRunning = true;
      _isReceiveMode = filePath == null || isReceiveMode;

      _serverUrl = server.port == 80
          ? 'http://$ip'
          : 'http://$ip:${server.port}';

      _scheduleAutoShutdown(timeout: shutdownTimeout ?? defaultShutdownTimeout);

      // ignore: avoid_print
      print('KoTo Viewer server started: $_serverUrl (receiveMode: $_isReceiveMode)');

      return _serverUrl;
    } on SocketException catch (e, stackTrace) {
      AppErrorHandler.recordError(e, stackTrace, context: 'LocalServerService.startServer: SocketException');
      // ignore: avoid_print
      print('Failed to start KoTo Viewer server: $e');
      await stopServer();
      return null;
    } on Exception catch (e, stackTrace) {
      AppErrorHandler.recordError(e, stackTrace, context: 'LocalServerService.startServer');
      // ignore: avoid_print
      print('Failed to start KoTo Viewer server: $e');
      await stopServer();
      return null;
    }
  }

  /// Determines the safe directory to store uploaded files.
  static Future<Directory> getUploadDirectory() async {
    if (Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (publicDownload.existsSync()) {
          final testFile = File('${publicDownload.path}/.koto_write_test_${DateTime.now().millisecondsSinceEpoch}');
          testFile.writeAsStringSync('ok');
          testFile.deleteSync();
          return publicDownload;
        }
      } catch (_) {
        // Scoped storage on Android 11+ might restrict direct writes to /Download
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final uploads = Directory('${extDir.path}/Uploads');
          if (!uploads.existsSync()) {
            uploads.createSync(recursive: true);
          }
          return uploads;
        }
      } catch (_) {}

      final docs = await getApplicationDocumentsDirectory();
      final uploads = Directory('${docs.path}/Uploads');
      if (!uploads.existsSync()) {
        uploads.createSync(recursive: true);
      }
      return uploads;
    } else if (Platform.isWindows) {
      try {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloadDir = Directory('$userProfile\\Downloads');
          if (downloadDir.existsSync()) return downloadDir;
        }
        final downloads = await getDownloadsDirectory();
        if (downloads != null && downloads.existsSync()) return downloads;
      } catch (_) {}

      final docs = await getApplicationDocumentsDirectory();
      final uploads = Directory('${docs.path}\\KoToViewer\\Uploads');
      if (!uploads.existsSync()) {
        uploads.createSync(recursive: true);
      }
      return uploads;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      final uploads = Directory('${docs.path}/Uploads');
      if (!uploads.existsSync()) {
        uploads.createSync(recursive: true);
      }
      return uploads;
    }
  }

  static shelf.Handler _buildHandler({
    required File? file,
    required String? fileName,
    required String extension,
    required String serverName,
    required bool isReceiveOnly,
  }) {
    final contentType = _contentTypeFor(extension);
    final fileTypeLabel = _fileTypeLabelFor(extension);
    final fileIcon = _fileIconFor(extension);

    return (shelf.Request request) async {
      _refreshAutoShutdownTimer();

      final path = request.url.path;

      // Handle CORS preflight
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }

      // Handle File Upload via streaming directly to disk
      if (request.method == 'POST' && (path == 'upload' || path == 'api/upload')) {
        return await _handleStreamingUpload(request);
      }

      // Root path
      if (path.isEmpty || path == '/') {
        if (isReceiveOnly || file == null) {
          return shelf.Response.ok(
            _buildUploadHtmlPage(
              serverName: serverName,
              currentUrl: _serverUrl ?? '',
            ),
            headers: _htmlHeaders,
          );
        }

        return shelf.Response.ok(
          _buildHtmlPage(
            serverName: serverName,
            fileName: fileName ?? 'shared-file',
            fileTypeLabel: fileTypeLabel,
            fileIcon: fileIcon,
            extension: extension,
            currentUrl: _serverUrl ?? '',
          ),
          headers: _htmlHeaders,
        );
      }

      // Dedicated /upload path
      if (path == 'upload') {
        return shelf.Response.ok(
          _buildUploadHtmlPage(
            serverName: serverName,
            currentUrl: _serverUrl ?? '',
          ),
          headers: _htmlHeaders,
        );
      }

      // Download single shared file
      if (path == 'download' && file != null) {
        return _fileResponse(
          file: file,
          fileName: fileName ?? 'shared-file',
          contentType: contentType,
          inline: false,
        );
      }

      // Inline PDF viewer
      if (path == 'view' && extension == 'pdf' && file != null) {
        return _fileResponse(
          file: file,
          fileName: fileName ?? 'document.pdf',
          contentType: contentType,
          inline: true,
        );
      }

      return shelf.Response.notFound('Not found.', headers: _textHeaders);
    };
  }

  /// Streams incoming upload directly to disk using [IOSink].
  /// Does NOT hold the whole file in RAM, enabling multi-gigabyte uploads smoothly.
  static Future<shelf.Response> _handleStreamingUpload(shelf.Request request) async {
    try {
      String? rawFileName = request.url.queryParameters['filename'] ??
          request.headers['x-file-name'];

      if (rawFileName == null || rawFileName.trim().isEmpty) {
        final contentDisp = request.headers['content-disposition'];
        if (contentDisp != null) {
          final parts = contentDisp.split(';');
          for (final part in parts) {
            final trimmed = part.trim();
            if (trimmed.startsWith('filename=')) {
              rawFileName = trimmed.substring(9).replaceAll('"', '').trim();
              break;
            } else if (trimmed.startsWith("filename*=")) {
              final val = trimmed.substring(10).replaceAll('"', '').trim();
              final idx = val.lastIndexOf("''");
              rawFileName = idx != -1 ? val.substring(idx + 2) : val;
              break;
            }
          }
        }
      }

      if (rawFileName != null) {
        try {
          rawFileName = Uri.decodeComponent(rawFileName);
        } catch (_) {}
      }

      final sanitizedName = _safeFileName(
        rawFileName ?? 'upload_${DateTime.now().millisecondsSinceEpoch}.bin',
      );

      final uploadDir = await getUploadDirectory();
      var targetFile = File('${uploadDir.path}${Platform.pathSeparator}$sanitizedName');

      // Prevent overwrite collisions by appending incrementing index
      if (await targetFile.exists()) {
        final dotIndex = sanitizedName.lastIndexOf('.');
        final base = dotIndex > 0 ? sanitizedName.substring(0, dotIndex) : sanitizedName;
        final ext = dotIndex > 0 ? sanitizedName.substring(dotIndex) : '';
        var counter = 1;
        while (await targetFile.exists()) {
          targetFile = File('${uploadDir.path}${Platform.pathSeparator}${base}_$counter$ext');
          counter++;
        }
      }

      // Stream network chunks directly to target file on disk
      final sink = targetFile.openWrite();
      try {
        await sink.addStream(request.read());
        await sink.flush();
        await sink.close();
      } catch (e, stackTrace) {
        try {
          await sink.close();
        } catch (_) {}
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        AppErrorHandler.recordError(e, stackTrace, context: 'LocalServerService._handleStreamingUpload.pipe');
        rethrow;
      }

      final fileSize = await targetFile.length();
      if (fileSize == 0) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Empty file received (0 bytes)'}),
          headers: {'Content-Type': 'application/json', ..._corsHeaders},
        );
      }

      _refreshAutoShutdownTimer();

      // Register uploaded file in RecentFilesService so it appears immediately on the home screen
      try {
        final pdfItem = PdfItem.fromPath(targetFile.path, sizeInBytes: fileSize);
        await RecentFilesService.addRecentFile(pdfItem);
      } catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'LocalServerService._handleStreamingUpload.recent');
      }

      // Broadcast received file event to active UI listeners (e.g. LocalNetworkReceiveDialog)
      _fileReceivedController.add(targetFile);

      final savedFileName = targetFile.path.split(Platform.pathSeparator).last;
      // ignore: avoid_print
      print('Uploaded file saved successfully: ${targetFile.path} ($fileSize bytes)');

      return shelf.Response.ok(
        jsonEncode({
          'success': true,
          'fileName': savedFileName,
          'size': fileSize,
          'path': targetFile.path,
        }),
        headers: {'Content-Type': 'application/json', ..._corsHeaders},
      );
    } catch (e, stackTrace) {
      AppErrorHandler.recordError(e, stackTrace, context: 'LocalServerService._handleStreamingUpload');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json', ..._corsHeaders},
      );
    }
  }

  static Future<shelf.Response> _fileResponse({
    required File file,
    required String fileName,
    required String contentType,
    required bool inline,
  }) async {
    if (!await file.exists()) {
      return shelf.Response.notFound(
        'The shared file is no longer available.',
        headers: _textHeaders,
      );
    }

    final length = await file.length();
    final disposition = inline ? 'inline' : 'attachment';
    final asciiName = _asciiFallbackFileName(fileName);
    final encodedName = Uri.encodeComponent(fileName);

    return shelf.Response.ok(
      file.openRead(),
      headers: {
        'Content-Type': contentType,
        'Content-Length': length.toString(),
        'Content-Disposition':
            "$disposition; filename=\"$asciiName\"; filename*=UTF-8''$encodedName",
        'Cache-Control': 'no-store, no-cache, must-revalidate',
        'Pragma': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
        ..._corsHeaders,
      },
    );
  }

  static Future<HttpServer> _bindServer(shelf.Handler handler) async {
    const ports = <int>[_preferredPort, 8081, 8082, 8083, 0];

    Object? lastError;

    for (final port in ports) {
      try {
        return await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
      } on SocketException catch (e) {
        lastError = e;
      } on Exception catch (e) {
        lastError = e;
      }
    }

    throw StateError('Could not bind HTTP server: $lastError');
  }

  static Future<String?> _resolveLanIpv4() async {
    try {
      final wifiIp = await NetworkInfo().getWifiIP();

      if (_isUsableLanIpv4(wifiIp)) {
        return wifiIp;
      }
    } on PlatformException catch (_) {
      // Fall back to listing interfaces.
    } on Exception catch (_) {
      // Fall back to listing interfaces.
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isUsableLanIpv4(address.address)) {
            return address.address;
          }
        }
      }
    } on SocketException catch (_) {
      return null;
    } on Exception catch (_) {
      return null;
    }

    return null;
  }

  static bool _isUsableLanIpv4(String? address) {
    if (address == null || address.isEmpty) {
      return false;
    }

    final ip = InternetAddress.tryParse(address);

    if (ip == null || ip.type != InternetAddressType.IPv4) {
      return false;
    }

    if (ip.isLoopback || ip.isLinkLocal) {
      return false;
    }

    final parts = address.split('.').map(int.tryParse).toList();

    if (parts.length != 4 || parts.any((part) => part == null)) {
      return false;
    }

    final a = parts[0]!;
    final b = parts[1]!;

    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  static void resetAutoShutdownTimer({Duration? timeout}) {
    if (!_isRunning) {
      return;
    }

    _scheduleAutoShutdown(timeout: timeout ?? defaultShutdownTimeout);
  }

  static void _refreshAutoShutdownTimer() {
    resetAutoShutdownTimer();
  }

  static void _scheduleAutoShutdown({required Duration timeout}) {
    _autoShutdownTimer?.cancel();
    _shutdownAt = DateTime.now().add(timeout);

    _autoShutdownTimer = Timer(timeout, () {
      // ignore: discarded_futures
      stopServer();
    });
  }

  static Future<void> stopServer() async {
    _autoShutdownTimer?.cancel();
    _autoShutdownTimer = null;
    _shutdownAt = null;

    final server = _server;

    _server = null;
    _serverUrl = null;
    _ipAddress = null;
    _port = null;
    _serverName = null;
    _isRunning = false;
    _isReceiveMode = false;

    if (server != null) {
      try {
        await server.close(force: true);
      } on SocketException catch (_) {
        // Already closed
      } on HttpException catch (_) {
        // Already closed
      } on Exception catch (_) {
        // Already closed
      }
    }

    // ignore: avoid_print
    print('KoTo Viewer server stopped');
  }

  static String _generateServerName() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    final suffix = String.fromCharCodes(
      List<int>.generate(
        4,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );

    return '$_baseName-$suffix';
  }

  static String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static String _contentTypeFor(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'dxf':
        return 'application/dxf';
      case 'zip':
      case 'kpack':
        return 'application/zip';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static String _fileTypeLabelFor(String extension) {
    switch (extension) {
      case 'pdf':
        return 'PDF document';
      case 'dxf':
        return 'DXF drawing';
      case 'zip':
      case 'kpack':
        return 'Project Presentation Archive';
      default:
        return 'File';
    }
  }

  static String _fileIconFor(String extension) {
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'dxf':
        return '📐';
      case 'zip':
      case 'kpack':
        return '📦';
      default:
        return '📁';
    }
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\r\n"\\\/]'), '_').trim();
    return cleaned.isEmpty ? 'shared-file' : cleaned;
  }

  static String _asciiFallbackFileName(String value) {
    return value.replaceAll(RegExp(r'[^\x20-\x7E]'), '_').replaceAll('"', '_');
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, X-File-Name, Accept',
  };

  static const Map<String, String> _htmlHeaders = {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store, no-cache, must-revalidate',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Access-Control-Allow-Origin': '*',
  };

  static const Map<String, String> _textHeaders = {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store, no-cache, must-revalidate',
    'X-Content-Type-Options': 'nosniff',
    ..._corsHeaders,
  };

  /// Dedicated high-speed upload webpage served to desktop and mobile browsers.
  static String _buildUploadHtmlPage({
    required String serverName,
    required String currentUrl,
  }) {
    final title = _escapeHtml('$serverName — Upload Files');
    final safeUrl = _escapeHtml(currentUrl);

    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>$title</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 20px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #0f172a;
      color: #f8fafc;
    }
    .card {
      width: min(100%, 520px);
      padding: 32px 28px;
      border: 1px solid #334155;
      border-radius: 24px;
      background: #1e293b;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.45);
      text-align: center;
    }
    .header-icon {
      font-size: 50px;
      margin-bottom: 12px;
      display: inline-block;
    }
    h1 {
      font-size: 23px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: 6px;
      background: linear-gradient(135deg, #a5b4fc, #c084fc);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    p.subtitle {
      font-size: 13.5px;
      color: #94a3b8;
      margin-bottom: 20px;
      line-height: 1.45;
    }
    .device-badge {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 20px;
      padding: 6px 14px;
      font-size: 12px;
      color: #38bdf8;
      font-weight: 600;
      margin-bottom: 22px;
    }
    .device-badge .dot {
      width: 8px;
      height: 8px;
      background: #22c55e;
      border-radius: 50%;
      box-shadow: 0 0 8px #22c55e;
    }
    .drop-zone {
      border: 2px dashed #6366f1;
      border-radius: 18px;
      padding: 34px 20px;
      background: rgba(99, 102, 241, 0.05);
      cursor: pointer;
      transition: all 0.2s ease;
      position: relative;
    }
    .drop-zone.dragover {
      border-color: #a855f7;
      background: rgba(168, 85, 247, 0.12);
      transform: scale(1.01);
    }
    .drop-icon {
      font-size: 42px;
      margin-bottom: 10px;
    }
    .drop-text {
      font-size: 15px;
      font-weight: 700;
      color: #e2e8f0;
      margin-bottom: 4px;
    }
    .drop-hint {
      font-size: 12.5px;
      color: #94a3b8;
    }
    .file-input {
      display: none;
    }
    .formats {
      margin-top: 14px;
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      justify-content: center;
    }
    .format-tag {
      background: #0f172a;
      border: 1px solid #334155;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      color: #cbd5e1;
    }
    .progress-box {
      display: none;
      margin-top: 22px;
      padding: 18px;
      background: #0f172a;
      border: 1px solid #334155;
      border-radius: 14px;
      text-align: left;
    }
    .progress-header {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 8px;
      color: #f1f5f9;
    }
    .progress-bar-bg {
      height: 10px;
      background: #334155;
      border-radius: 6px;
      overflow: hidden;
      margin-bottom: 8px;
    }
    .progress-bar-fill {
      height: 100%;
      width: 0%;
      background: linear-gradient(90deg, #6366f1, #a855f7);
      border-radius: 6px;
      transition: width 0.15s ease;
    }
    .progress-stats {
      display: flex;
      justify-content: space-between;
      font-size: 11.5px;
      color: #94a3b8;
      font-family: monospace;
    }
    .uploads-list {
      margin-top: 20px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .upload-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #0f172a;
      border: 1px solid #22c55e44;
      padding: 10px 14px;
      border-radius: 10px;
      font-size: 13px;
      text-align: left;
    }
    .upload-item .info {
      display: flex;
      align-items: center;
      gap: 10px;
      overflow: hidden;
    }
    .upload-item .filename {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 250px;
      font-weight: 600;
      color: #f1f5f9;
    }
    .upload-item .size {
      font-size: 11.5px;
      color: #94a3b8;
    }
    .upload-item .status-badge {
      color: #22c55e;
      font-size: 12px;
      font-weight: 700;
    }
    .url-note {
      margin-top: 20px;
      font-size: 12px;
      color: #64748b;
      line-height: 1.45;
    }
  </style>
</head>
<body>
  <main class="card">
    <div class="header-icon">📲</div>
    <h1>KoTo Viewer Upload</h1>
    <p class="subtitle">Direct Wi-Fi transfer to your device library</p>

    <div class="device-badge">
      <span class="dot"></span>
      <span>Target: $serverName</span>
    </div>

    <div class="drop-zone" id="dropZone">
      <div class="drop-icon">📤</div>
      <div class="drop-text">Drag & drop files here</div>
      <div class="drop-hint">or click to browse from your computer / phone</div>
      <input type="file" multiple id="fileInput" class="file-input">
      <div class="formats">
        <span class="format-tag">ZIP Presentations</span>
        <span class="format-tag">CAD (DWG, DXF)</span>
        <span class="format-tag">3D Models</span>
        <span class="format-tag">PDF</span>
        <span class="format-tag">Office</span>
      </div>
    </div>

    <div class="progress-box" id="progressBox">
      <div class="progress-header">
        <span id="currentFileName">Uploading...</span>
        <span id="percentText">0%</span>
      </div>
      <div class="progress-bar-bg">
        <div class="progress-bar-fill" id="progressBar"></div>
      </div>
      <div class="progress-stats">
        <span id="bytesText">0 / 0 MB</span>
        <span id="speedText">0 MB/s</span>
      </div>
    </div>

    <div class="uploads-list" id="uploadsList"></div>

    <div class="url-note">
      Connected to $safeUrl<br>
      Files stream directly to KoTo Viewer storage without size limits.
    </div>
  </main>

  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const progressBox = document.getElementById('progressBox');
    const currentFileName = document.getElementById('currentFileName');
    const percentText = document.getElementById('percentText');
    const progressBar = document.getElementById('progressBar');
    const bytesText = document.getElementById('bytesText');
    const speedText = document.getElementById('speedText');
    const uploadsList = document.getElementById('uploadsList');

    dropZone.addEventListener('click', () => fileInput.click());

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.add('dragover');
      });
    });

    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropZone.classList.remove('dragover');
      });
    });

    dropZone.addEventListener('drop', (e) => {
      const dt = e.dataTransfer;
      if (dt && dt.files && dt.files.length > 0) {
        handleFiles(dt.files);
      }
    });

    fileInput.addEventListener('change', () => {
      if (fileInput.files && fileInput.files.length > 0) {
        handleFiles(fileInput.files);
      }
    });

    function formatBytes(bytes) {
      if (bytes === 0) return '0 B';
      const k = 1024;
      const sizes = ['B', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    async function handleFiles(fileList) {
      const files = Array.from(fileList);
      for (const file of files) {
        await uploadFile(file);
      }
      fileInput.value = '';
    }

    function uploadFile(file) {
      return new Promise((resolve) => {
        progressBox.style.display = 'block';
        currentFileName.textContent = file.name;
        percentText.textContent = '0%';
        progressBar.style.width = '0%';
        bytesText.textContent = '0 / ' + formatBytes(file.size);
        speedText.textContent = 'Starting...';

        let lastLoaded = 0;
        let lastTime = Date.now();

        const xhr = new XMLHttpRequest();
        xhr.open('POST', '/upload?filename=' + encodeURIComponent(file.name), true);
        xhr.setRequestHeader('X-File-Name', encodeURIComponent(file.name));

        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            const percent = Math.round((e.loaded / e.total) * 100);
            percentText.textContent = percent + '%';
            progressBar.style.width = percent + '%';
            bytesText.textContent = formatBytes(e.loaded) + ' / ' + formatBytes(e.total);

            const now = Date.now();
            const timeDiff = (now - lastTime) / 1000;
            if (timeDiff >= 0.4) {
              const loadedDiff = e.loaded - lastLoaded;
              const speedBytesPerSec = loadedDiff / timeDiff;
              speedText.textContent = formatBytes(speedBytesPerSec) + '/s';
              lastLoaded = e.loaded;
              lastTime = now;
            }
          }
        };

        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            progressBox.style.display = 'none';
            addUploadedItem(file.name, file.size);
          } else {
            speedText.textContent = 'Failed (' + xhr.status + ')';
            alert('Upload error: ' + (xhr.responseText || 'Server error'));
          }
          resolve();
        };

        xhr.onerror = () => {
          speedText.textContent = 'Network error';
          alert('Network connection error while uploading ' + file.name);
          resolve();
        };

        xhr.send(file);
      });
    }

    function addUploadedItem(name, size) {
      const item = document.createElement('div');
      item.className = 'upload-item';
      item.innerHTML = `
        <div class="info">
          <span>✅</span>
          <div>
            <div class="filename">\${name}</div>
            <div class="size">\${formatBytes(size)}</div>
          </div>
        </div>
        <span class="status-badge">Received</span>
      `;
      uploadsList.prepend(item);
    }
  </script>
</body>
</html>
''';
  }

  /// Page shown when sharing an existing file.
  static String _buildHtmlPage({
    required String serverName,
    required String fileName,
    required String fileTypeLabel,
    required String fileIcon,
    required String extension,
    required String currentUrl,
  }) {
    final isPdf = extension == 'pdf';

    final title = _escapeHtml('$serverName — $fileTypeLabel');
    final safeFileName = _escapeHtml(fileName);
    final safeUrl = _escapeHtml(currentUrl);

    final viewButton = isPdf
        ? '''
<a class="button secondary" href="/view" target="_blank" rel="noopener">
  View PDF
</a>
'''
        : '';

    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>$title</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 20px;
      font-family: Arial, sans-serif;
      background: #111827;
      color: #f9fafb;
    }
    .card {
      width: min(100%, 460px);
      padding: 28px;
      border: 1px solid #374151;
      border-radius: 18px;
      background: #1f2937;
      box-shadow: 0 20px 45px rgba(0,0,0,.35);
      text-align: center;
    }
    .icon { font-size: 64px; margin-bottom: 12px; }
    h1 { font-size: 22px; margin: 0 0 8px; }
    .type { color: #93c5fd; font-weight: 700; margin-bottom: 18px; }
    .name {
      padding: 12px;
      background: #111827;
      border-radius: 10px;
      overflow-wrap: anywhere;
      margin-bottom: 18px;
    }
    .url {
      margin: 18px 0;
      padding: 10px;
      border-radius: 10px;
      background: #111827;
      color: #d1d5db;
      font: 12px monospace;
      overflow-wrap: anywhere;
      text-align: left;
    }
    .button {
      display: block;
      width: 100%;
      margin-top: 10px;
      padding: 14px;
      border-radius: 10px;
      color: #fff;
      background: #2563eb;
      font-weight: 700;
      text-decoration: none;
    }
    .button.secondary { background: #374151; }
    .upload-link {
      margin-top: 14px;
      display: block;
      font-size: 13px;
      color: #a5b4fc;
      text-decoration: underline;
    }
    .note {
      margin-top: 18px;
      color: #9ca3af;
      font-size: 13px;
      line-height: 1.45;
    }
  </style>
</head>
<body>
  <main class="card">
    <div class="icon">$fileIcon</div>
    <h1>$title</h1>
    <div class="type">$fileTypeLabel</div>
    <div class="name">$safeFileName</div>

    <a class="button" href="/download">Download file</a>
    $viewButton

    <div class="url">$safeUrl</div>

    <a class="upload-link" href="/upload">Need to send files to this device? Click here to Upload</a>

    <div class="note">
      This link works while KoTo Viewer sharing is active and both devices
      are connected to the same local network.
    </div>
  </main>
</body>
</html>
''';
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
