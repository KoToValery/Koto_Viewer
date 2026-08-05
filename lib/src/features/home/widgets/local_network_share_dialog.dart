import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/local_server_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LocalNetworkShareDialog extends StatefulWidget {
  final String filePath;

  const LocalNetworkShareDialog({super.key, required this.filePath});

  @override
  State<LocalNetworkShareDialog> createState() =>
      _LocalNetworkShareDialogState();
}

class _LocalNetworkShareDialogState extends State<LocalNetworkShareDialog> {
  bool _isStarting = true;
  bool _hasError = false;
  String? _serverUrl;
  String? _serverName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  @override
  void dispose() {
    LocalServerService.stopServer();
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _isStarting = true;
      _hasError = false;
    });

    try {
      final fileName = widget.filePath.split(Platform.pathSeparator).last;
      final url = await LocalServerService.startServer(
        widget.filePath,
        fileName: fileName,
      );

      if (url != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _serverUrl = url;
          _serverName = LocalServerService.serverName;
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local Network',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _serverName != null
                            ? '$_serverName • $fileName'
                            : fileName,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 22,
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_isStarting)
              _buildLoading()
            else if (_hasError)
              _buildError(context)
            else
              _buildSuccess(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Starting server...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Getting your network address',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(0xFFEF4444)),
          const SizedBox(height: 14),
          const Text(
            'Cannot start sharing',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage?.replaceAll('Exception: ', '') ??
                'Make sure you are connected to WiFi or a local network and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _startServer,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localUrl = LocalServerService.localDomainUrl;
    final port = LocalServerService.port;
    final needsPortInLocalUrl = port != null && port != 80;
    final fullLocalUrl = needsPortInLocalUrl
        ? '$localUrl:$port'
        : localUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: QrImageView(
            data: _serverUrl!,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF4F46E5),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 17, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text(
                    'Scan or open the link',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4338CA),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '1. Connect the other device to the same WiFi\n'
                '2. Scan the QR code or copy the URL below\n'
                '3. Or try http://kotoview.local on macOS/iOS/Linux\n'
                '4. Download or view the PDF in any browser',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3730A3),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC4B5FD),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language,
                size: 17,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Address (.local)',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark
                            ? Colors.indigo.shade200
                            : Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      fullLocalUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                        letterSpacing: .1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined, size: 19),
                onPressed: () => _copyToClipboard(fullLocalUrl, 'Local URL'),
                tooltip: 'Copy local URL',
                color: const Color(0xFF4F46E5),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3B0764) : const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF581C87) : const Color(0xFFE9D5FF),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 17,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Name',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark
                            ? Colors.purple.shade200
                            : Colors.purple.shade700,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _serverName ?? 'KotoView',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B21A8),
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined, size: 19),
                onPressed: () => _copyToClipboard(_serverName ?? 'KotoView', 'Server name'),
                tooltip: 'Copy name',
                color: const Color(0xFF7E22CE),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 17, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IP Address',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _serverUrl!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 19),
                onPressed: () => _copyToClipboard(_serverUrl!, 'IP URL'),
                tooltip: 'Copy URL',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _stopServer,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text(
              'Stop Sharing',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Server stays on while this session is active',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
