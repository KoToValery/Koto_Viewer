import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:network_info_plus/network_info_plus.dart';

/// Local HTTP server for sharing PDF files over local network
class LocalServerService {
  static HttpServer? _server;
  static String? _currentFilePath;
  static String? _serverUrl;
  static bool _isRunning = false;
  
  /// Device name for mDNS (simplified)
  static String _deviceName = 'KotoPDF';
  
  /// Start the local server and share a PDF file
  static Future<String?> startServer(String filePath, {String? fileName}) async {
    try {
      // Stop existing server if running
      await stopServer();
      
      _currentFilePath = filePath;
      final file = File(filePath);
      
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }
      
      final fileBytes = await file.readAsBytes();
      final displayName = fileName ?? filePath.split(Platform.pathSeparator).last;
      
      // Get local IP address
      final networkInfo = NetworkInfo();
      String? ipAddress = await networkInfo.getWifiIP();
      
      if (ipAddress == null || ipAddress.isEmpty) {
        throw Exception('Not connected to WiFi');
      }
      
      // Create HTTP handler
      final handler = shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler((shelf.Request request) {
        
        // Root endpoint - show download page
        if (request.url.path == '' || request.url.path == '/') {
          return shelf.Response.ok(
            _buildHtmlPage(displayName, ipAddress),
            headers: {'Content-Type': 'text/html; charset=utf-8'},
          );
        }
        
        // Download endpoint
        if (request.url.path == 'download') {
          return shelf.Response.ok(
            fileBytes,
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Disposition': 'attachment; filename="${Uri.encodeComponent(displayName)}"',
              'Content-Length': fileBytes.length.toString(),
            },
          );
        }
        
        // View endpoint (open in browser)
        if (request.url.path == 'view') {
          return shelf.Response.ok(
            fileBytes,
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Disposition': 'inline; filename="${Uri.encodeComponent(displayName)}"',
            },
          );
        }
        
        return shelf.Response.notFound('Not found');
      });
      
      // Start server on random available port
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _isRunning = true;
      
      final port = _server!.port;
      _serverUrl = 'http://$ipAddress:$port';
      
      print('✅ Server started at $_serverUrl');
      return _serverUrl;
      
    } catch (e) {
      print('❌ Error starting server: $e');
      _isRunning = false;
      return null;
    }
  }
  
  /// Stop the local server
  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _currentFilePath = null;
      _serverUrl = null;
      _isRunning = false;
      print('🛑 Server stopped');
    }
  }
  
  /// Check if server is running
  static bool get isRunning => _isRunning;
  
  /// Get current server URL
  static String? get serverUrl => _serverUrl;
  
  /// Get device name
  static String get deviceName => _deviceName;
  
  /// Set device name
  static void setDeviceName(String name) {
    _deviceName = name.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
  }
  
  /// Build HTML page for download
  static String _buildHtmlPage(String fileName, String ipAddress) {
    return '''
<!DOCTYPE html>
<html lang="bg">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$_deviceName - PDF Споделяне</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 500px;
            width: 100%;
            text-align: center;
        }
        .icon {
            font-size: 80px;
            margin-bottom: 20px;
        }
        h1 {
            color: #333;
            font-size: 24px;
            margin-bottom: 10px;
        }
        .device-name {
            color: #667eea;
            font-size: 18px;
            margin-bottom: 20px;
            font-weight: 600;
        }
        .filename {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 10px;
            margin: 20px 0;
            word-break: break-word;
            color: #555;
            font-size: 14px;
        }
        .buttons {
            display: flex;
            flex-direction: column;
            gap: 15px;
            margin-top: 30px;
        }
        .btn {
            padding: 15px 30px;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.2);
        }
        .btn-download {
            background: #667eea;
            color: white;
        }
        .btn-view {
            background: #48bb78;
            color: white;
        }
        .info {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            font-size: 12px;
            color: #999;
        }
        @media (max-width: 480px) {
            .container {
                padding: 30px 20px;
            }
            h1 {
                font-size: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📄</div>
        <h1>PDF Документ</h1>
        <div class="device-name">от $_deviceName</div>
        <div class="filename">$fileName</div>
        
        <div class="buttons">
            <a href="/download" class="btn btn-download">
                📥 Изтегли
            </a>
            <a href="/view" class="btn btn-view" target="_blank">
                👁️ Преглед
            </a>
        </div>
        
        <div class="info">
            🔒 Сигурна връзка в локалната мрежа<br>
            📡 IP: $ipAddress
        </div>
    </div>
</body>
</html>
''';
  }
}
