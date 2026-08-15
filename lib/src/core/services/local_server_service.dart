import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// LAN HTTP server for sharing one PDF or DXF file.
/// Uses an IPv4 address and port only, without tokens or mDNS.
class LocalServerService {
  LocalServerService._();

  static HttpServer? _server;
  static String? _serverUrl;
  static String? _ipAddress;
  static int? _port;
  static String? _serverName;

  static bool _isRunning = false;

  static Timer? _autoShutdownTimer;
  static DateTime? _shutdownAt;

  static final Random _random = Random.secure();

  static const String _baseName = 'KotoView';
  static const int _preferredPort = 8080;
  static const Duration defaultShutdownTimeout = Duration(minutes: 15);

  static bool get isRunning => _isRunning;
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

  /// Starts the local server and returns its local address.
  ///
  /// Example: http://192.168.1.25:8080
  static Future<String?> startServer(
    String filePath, {
    String? fileName,
    Duration? shutdownTimeout,
  }) async {
    await stopServer();

    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }

      final ip = await _resolveLanIpv4();

      if (ip == null) {
        throw StateError(
          'No LAN IPv4 address found. Connect the device to Wi-Fi first.',
        );
      }

      final resolvedName = _safeFileName(
        fileName ?? file.path.split(Platform.pathSeparator).last,
      );

      final extension = _extensionOf(resolvedName);
      final serverName = _generateServerName();

      final handler = _buildHandler(
        file: file,
        fileName: resolvedName,
        extension: extension,
        serverName: serverName,
      );

      final server = await _bindServer(handler);

      _server = server;
      _ipAddress = ip;
      _port = server.port;
      _serverName = serverName;
      _isRunning = true;

      _serverUrl = server.port == 80
          ? 'http://$ip'
          : 'http://$ip:${server.port}';

      _scheduleAutoShutdown(timeout: shutdownTimeout ?? defaultShutdownTimeout);

      // ignore: avoid_print
      print('KotoView server started: $_serverUrl');

      return _serverUrl;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Failed to start KotoView server: $e');
      // ignore: avoid_print
      print(stackTrace);

      await stopServer();
      return null;
    }
  }

  static shelf.Handler _buildHandler({
    required File file,
    required String fileName,
    required String extension,
    required String serverName,
  }) {
    final contentType = _contentTypeFor(extension);
    final fileTypeLabel = _fileTypeLabelFor(extension);
    final fileIcon = _fileIconFor(extension);

    return (shelf.Request request) async {
      _refreshAutoShutdownTimer();

      final path = request.url.path;

      if (path.isEmpty || path == '/') {
        return shelf.Response.ok(
          _buildHtmlPage(
            serverName: serverName,
            fileName: fileName,
            fileTypeLabel: fileTypeLabel,
            fileIcon: fileIcon,
            extension: extension,
            currentUrl: _serverUrl ?? '',
          ),
          headers: const {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-store, no-cache, must-revalidate',
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
          },
        );
      }

      if (path == 'download') {
        return _fileResponse(
          file: file,
          fileName: fileName,
          contentType: contentType,
          inline: false,
        );
      }

      if (path == 'view' && extension == 'pdf') {
        return _fileResponse(
          file: file,
          fileName: fileName,
          contentType: contentType,
          inline: true,
        );
      }

      return shelf.Response.notFound('Not found.', headers: _textHeaders);
    };
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
      } catch (e) {
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
    } catch (_) {
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
    } catch (_) {
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

    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {
        // The server may already be closed.
      }
    }

    // ignore: avoid_print
    print('KotoView server stopped');
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
      default:
        return '📁';
    }
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\r\n"]'), '_').trim();
    return cleaned.isEmpty ? 'shared-file' : cleaned;
  }

  static String _asciiFallbackFileName(String value) {
    return value.replaceAll(RegExp(r'[^\x20-\x7E]'), '_').replaceAll('"', '_');
  }

  static const Map<String, String> _textHeaders = {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store, no-cache, must-revalidate',
    'X-Content-Type-Options': 'nosniff',
  };

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
    <div class="note">
      This link works only while KotoView sharing is active and both devices
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
