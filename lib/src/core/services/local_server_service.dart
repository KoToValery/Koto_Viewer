import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart';

/// Local HTTP server for sharing PDF files over local network
class LocalServerService {
  static HttpServer? _server;
  static String? _serverUrl;
  static bool _isRunning = false;
  static String? _serverName;
  static String? _ipAddress;
  static int? _port;
  static Timer? _autoShutdownTimer;
  static DateTime? _startedAt;
  static final Random _random = Random();
  static Registration? _mdnsRegistration;

  static const String _baseName = 'KotoView';
  static const String _localHostname = 'kotoview';
  static const int _nameSuffixLength = 4;
  static const Duration defaultShutdownTimeout = Duration(minutes: 15);
  static const int _preferredPort = 8080;

  static String get localDomainUrl => 'http://$_localHostname.local';

  /// Generate a short, memorable server name like KotoView-A1B2
  static String _generateShortName() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = String.fromCharCodes(
      Iterable.generate(
        _nameSuffixLength,
        (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
      ),
    );
    return '$_baseName-$suffix';
  }

  /// Try to bind server on preferredPort, fallback to random free port
  static Future<HttpServer> _bindServer(shelf.Handler handler) async {
    HttpServer? server;
    final portsToTry = <int>[_preferredPort, 80, 8081, 8082, 0];

    for (final port in portsToTry) {
      try {
        server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
        return server;
      } catch (_) {
        continue;
      }
    }

    throw Exception('Could not bind to any port');
  }

  /// Register mDNS service (Bonjour / .local) so the server is reachable via kotoview.local
  static Future<void> _registerMdnsService(int port) async {
    try {
      await _unregisterMdnsService();

      final service = Service(
        name: _localHostname,
        type: '_http._tcp',
        port: port,
      );

      _mdnsRegistration = await register(service);

      // ignore: avoid_print
      print('🔔 mDNS registered: $_localHostname.local:_http._tcp:$port');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️  mDNS registration failed: $e');
      // ignore: avoid_print
      print('   Server is still accessible via IP address.');
      _mdnsRegistration = null;
    }
  }

  /// Unregister mDNS service
  static Future<void> _unregisterMdnsService() async {
    if (_mdnsRegistration != null) {
      try {
        await unregister(_mdnsRegistration!);
        // ignore: avoid_print
        print('🔕 mDNS unregistered');
      } catch (e) {
        // ignore: avoid_print
        print('⚠️  mDNS unregister failed: $e');
      }
      _mdnsRegistration = null;
    }
  }

  /// Start the local server and share a PDF file
  static Future<String?> startServer(
    String filePath, {
    String? fileName,
  }) async {
    try {
      await stopServer();

      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }

      final fileBytes = await file.readAsBytes();
      final displayName =
          fileName ?? filePath.split(Platform.pathSeparator).last;

      _serverName = _generateShortName();

      final networkInfo = NetworkInfo();
      _ipAddress = await networkInfo.getWifiIP();

      if (_ipAddress == null || _ipAddress!.isEmpty) {
        try {
          final interfaces = await NetworkInterface.list(
            includeLoopback: false,
            type: InternetAddressType.IPv4,
          );
          for (final iface in interfaces) {
            for (final addr in iface.addresses) {
              if (!addr.address.startsWith('127.') &&
                  !addr.address.startsWith('169.254')) {
                _ipAddress = addr.address;
                break;
              }
            }
            if (_ipAddress != null) break;
          }
        } catch (_) {}

        if (_ipAddress == null || _ipAddress!.isEmpty) {
          throw Exception('Not connected to a network');
        }
      }

      final handler = const shelf.Pipeline().addHandler((
        shelf.Request request,
      ) {
        resetAutoShutdownTimer();

        try {
          final path = request.url.path;

          if (path == '' || path == '/') {
            return shelf.Response.ok(
              _buildHtmlPage(displayName),
              headers: {'Content-Type': 'text/html; charset=utf-8'},
            );
          }

          if (path == 'download') {
            return shelf.Response.ok(
              Stream.fromIterable([fileBytes]),
              headers: {
                'Content-Type': 'application/pdf',
                'Content-Disposition':
                    'attachment; filename="${Uri.encodeComponent(displayName)}"',
                'Content-Length': fileBytes.length.toString(),
                'Cache-Control': 'no-store',
                'Access-Control-Allow-Origin': '*',
              },
            );
          }

          if (path == 'view') {
            return shelf.Response.ok(
              Stream.fromIterable([fileBytes]),
              headers: {
                'Content-Type': 'application/pdf',
                'Content-Disposition':
                    'inline; filename="${Uri.encodeComponent(displayName)}"',
                'Content-Length': fileBytes.length.toString(),
                'Cache-Control': 'no-store',
                'Access-Control-Allow-Origin': '*',
              },
            );
          }

          return shelf.Response.notFound(
            'Not Found',
            headers: {'Content-Type': 'text/plain'},
          );
        } catch (e) {
          return shelf.Response.internalServerError(
            body: 'Server error: $e',
            headers: {'Content-Type': 'text/plain'},
          );
        }
      });

      _server = await _bindServer(handler);
      _server!.autoCompress = true;
      _server!.sessionTimeout = 5 * 60;

      _port = _server!.port;
      _serverUrl = _port == 80
          ? 'http://$_ipAddress'
          : 'http://$_ipAddress:$_port';

      await _registerMdnsService(_port!);

      _isRunning = true;
      _startedAt = DateTime.now();

      _scheduleAutoShutdown();

      // ignore: avoid_print
      print('✅ Server started at $_serverUrl');
      // ignore: avoid_print
      print('🌐 Local domain: $localDomainUrl');
      // ignore: avoid_print
      print('📛 Name: $_serverName');
      // ignore: avoid_print
      print('⏱️  Auto-shutdown in ${defaultShutdownTimeout.inMinutes} min');

      return _serverUrl;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ Error starting server: $e');
      // ignore: avoid_print
      print(stackTrace);
      _isRunning = false;
      return null;
    }
  }

  static void _scheduleAutoShutdown({Duration? timeout}) {
    _cancelAutoShutdown();
    final t = timeout ?? defaultShutdownTimeout;
    _autoShutdownTimer = Timer(t, () {
      // ignore: avoid_print
      print('⏰ Auto-shutdown timer fired');
      stopServer();
    });
  }

  static void _cancelAutoShutdown() {
    _autoShutdownTimer?.cancel();
    _autoShutdownTimer = null;
  }

  /// Reset (refresh) the auto-shutdown timer after activity.
  static void resetAutoShutdownTimer({Duration? timeout}) {
    if (_isRunning) {
      _scheduleAutoShutdown(timeout: timeout);
    }
  }

  /// Seconds remaining until the server auto-stops (0 if not running).
  static int get remainingSeconds {
    if (_startedAt == null) return 0;
    final elapsed = DateTime.now().difference(_startedAt!);
    final rem = defaultShutdownTimeout - elapsed;
    return rem.isNegative ? 0 : rem.inSeconds;
  }

  /// Stop the local server
  static Future<void> stopServer() async {
    _cancelAutoShutdown();
    _startedAt = null;
    await _unregisterMdnsService();
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
      _serverUrl = null;
      _serverName = null;
      _ipAddress = null;
      _port = null;
      _isRunning = false;
      // ignore: avoid_print
      print('🛑 Server stopped');
    }
  }

  /// Check if server is running
  static bool get isRunning => _isRunning;

  /// Get current server URL
  static String? get serverUrl => _serverUrl;

  /// Short memorable server name e.g. KotoView-A3K7
  static String? get serverName => _serverName;

  /// Get IP address
  static String? get ipAddress => _ipAddress;

  /// Get port
  static int? get port => _port;

  /// Display name e.g. KotoView-A3K7 ::: 45678
  static String get serverDisplayName {
    final name = _serverName ?? _baseName;
    final p = _port ?? _preferredPort;
    return '$name • $p';
  }

  /// Build HTML page for download
  static String _buildHtmlPage(String fileName) {
    final name = _serverName ?? _baseName;
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <title>$name - PDF Share</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%);
            min-height: 100vh;
            display: flex; justify-content: center; align-items: center; padding: 16px;
        }
        .container {
            background: white; border-radius: 18px;
            box-shadow: 0 12px 40px rgba(0,0,0,0.25);
            padding: 28px; max-width: 440px; width: 100%; text-align: center;
        }
        .chip {
            display: inline-block; background: #EDE9FE; color: #4F46E5;
            padding: 6px 14px; border-radius: 999px;
            font-weight: 700; font-size: 13px; letter-spacing: .3px;
            margin-bottom: 18px;
        }
        .icon { font-size: 68px; margin-bottom: 10px; }
        h1 { color: #111827; font-size: 22px; margin-bottom: 4px; font-weight: 800; }
        .from { color: #4F46E5; font-size: 14px; margin-bottom: 16px; font-weight: 600; }
        .filename {
            background: #F9FAFB; border: 1px solid #E5E7EB;
            padding: 12px; border-radius: 10px;
            word-break: break-word; color: #374151;
            font-size: 13px; margin-bottom: 8px;
        }
        .meta {
            text-align: left; background: #F3F4F6;
            border-radius: 10px; padding: 12px 14px; margin-bottom: 18px;
            font-size: 12px; color: #4B5563; line-height: 1.6;
        }
        .meta span { font-weight: 600; color: #1F2937; }
        .buttons { display: flex; flex-direction: column; gap: 10px; }
        .btn {
            padding: 14px 20px; border: none; border-radius: 10px;
            font-size: 15px; font-weight: 700; cursor: pointer;
            text-decoration: none; display: block;
            transition: transform .15s, box-shadow .15s;
        }
        .btn:active { transform: translateY(1px); }
        .btn-download { background: #4F46E5; color: white; }
        .btn-view { background: #7C3AED; color: white; }
        @media (max-width: 420px) {
            .container { padding: 22px 18px; border-radius: 14px; }
            h1 { font-size: 20px; }
            .icon { font-size: 56px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="chip">$name</div>
        <div class="icon">📄</div>
        <h1>PDF Document</h1>
        <div class="from">shared from $_baseName</div>
        <div class="filename">$fileName</div>
        <div class="meta">
            <div>📛 Server: <span>$name</span></div>
            <div>📍 IP: <span>${_ipAddress ?? '—'}</span></div>
            <div>🔌 Port: <span>${_port ?? '—'}</span></div>
            <div>🌐 Local: <span>$localDomainUrl</span></div>
        </div>
        <div class="buttons">
            <a href="/download" class="btn btn-download">📥 Download PDF</a>
            <a href="/view" class="btn btn-view" target="_blank">👁️ View in Browser</a>
        </div>
    </div>
</body>
</html>
''';
  }
}
