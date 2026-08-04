import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/local_server_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LocalNetworkShareDialog extends StatefulWidget {
  final String filePath;

  const LocalNetworkShareDialog({
    super.key,
    required this.filePath,
  });

  @override
  State<LocalNetworkShareDialog> createState() => _LocalNetworkShareDialogState();
}

class _LocalNetworkShareDialogState extends State<LocalNetworkShareDialog> {
  bool _isStarting = true;
  bool _hasError = false;
  String? _serverUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    // Don't stop server here - user might want to keep sharing
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _isStarting = true;
      _hasError = false;
    });

    try {
      final fileName = widget.filePath.split(Platform.pathSeparator).last;
      final url = await LocalServerService.startServer(widget.filePath, fileName: fileName);

      if (url != null && mounted) {
        setState(() {
          _serverUrl = url;
          _isStarting = false;
        });
      } else {
        throw Exception('Failed to start server');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isStarting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _stopServer() async {
    await LocalServerService.stopServer();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _copyToClipboard() {
    if (_serverUrl != null) {
      Clipboard.setData(ClipboardData(text: _serverUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL копиран в клипборда'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi, color: Colors.purple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Локална мрежа',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content
            if (_isStarting)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Стартиране на сървър...'),
                  ],
                ),
              )
            else if (_hasError)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Грешка',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Не може да се стартира сървър',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _startServer,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Опитай отново'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: QrImageView(
                      data: _serverUrl!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Как да използвам:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Уверете се, че компютърът е в същата WiFi мрежа\n'
                          '2. Сканирайте QR кода или отворете линка\n'
                          '3. Изтеглете или прегледайте PDF-а',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // URL Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _serverUrl!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: _copyToClipboard,
                          tooltip: 'Копирай',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stop button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _stopServer,
                      icon: const Icon(Icons.stop),
                      label: const Text('Спри споделянето'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Warning
                  Text(
                    '⚠️ Сървърът ще работи докато не го спрете',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
