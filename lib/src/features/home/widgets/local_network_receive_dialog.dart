import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/services/file_opener_service.dart';
import '../../../core/services/local_server_service.dart';

/// Dialog that runs the local HTTP server in Upload/Receive mode,
/// displays a QR code and URL for LAN devices to upload files,
/// and lists received files with quick "Open" actions.
class LocalNetworkReceiveDialog extends StatefulWidget {
  const LocalNetworkReceiveDialog({super.key});

  @override
  State<LocalNetworkReceiveDialog> createState() =>
      _LocalNetworkReceiveDialogState();
}

class _LocalNetworkReceiveDialogState extends State<LocalNetworkReceiveDialog> {
  bool _isStarting = true;
  bool _hasError = false;
  String? _serverUrl;
  String? _errorMessage;

  StreamSubscription<File>? _fileSub;
  final List<File> _receivedFiles = [];
  String? _latestReceivedFileName;
  Timer? _notificationDismissTimer;

  @override
  void initState() {
    super.initState();
    _startServer();
    _fileSub = LocalServerService.onFileReceived.listen(_handleFileReceived);
  }

  @override
  void dispose() {
    _notificationDismissTimer?.cancel();
    _fileSub?.cancel();
    LocalServerService.stopServer();
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    super.dispose();
  }

  void _handleFileReceived(File file) {
    if (mounted) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      _notificationDismissTimer?.cancel();
      _notificationDismissTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) {
          setState(() {
            _latestReceivedFileName = null;
          });
        }
      });

      setState(() {
        _receivedFiles.insert(0, file);
        _latestReceivedFileName = fileName;
      });
    }
  }

  Future<void> _startServer() async {
    setState(() {
      _isStarting = true;
      _hasError = false;
    });

    try {
      final url = await LocalServerService.startReceiveServer();

      if (url != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 80));
        setState(() {
          _serverUrl = url;
          _isStarting = false;
        });
      } else {
        throw Exception('Failed to start server');
      }
    } on SocketException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocalNetworkReceiveDialog._startServer.socket');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isStarting = false;
          _errorMessage = e.message;
        });
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocalNetworkReceiveDialog._startServer');
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

  Future<void> _openFile(File file) async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await FileOpenerService.openFile(
      context: context,
      filePath: file.path,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _iconForFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.zip') || lower.endsWith('.kpack') || lower.endsWith('.cbz') || lower.endsWith('.cbr')) {
      return Icons.folder_zip_rounded;
    }
    if (lower.endsWith('.dwg') || lower.endsWith('.dxf')) {
      return Icons.draw_rounded;
    }
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (lower.endsWith('.stl') || lower.endsWith('.obj') || lower.endsWith('.glb') || lower.endsWith('.gltf') || lower.endsWith('.ifc') || lower.endsWith('.step')) {
      return Icons.view_in_ar_rounded;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.mkv') || lower.endsWith('.avi')) {
      return Icons.play_circle_fill_rounded;
    }
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls') || lower.endsWith('.csv')) {
      return Icons.table_chart_rounded;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc') || lower.endsWith('.pptx') || lower.endsWith('.txt')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _colorForFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.zip') || lower.endsWith('.kpack')) return const Color(0xFF059669);
    if (lower.endsWith('.dwg') || lower.endsWith('.dxf')) return const Color(0xFF0284C7);
    if (lower.endsWith('.pdf')) return const Color(0xFFDC2626);
    if (lower.endsWith('.stl') || lower.endsWith('.obj') || lower.endsWith('.glb') || lower.endsWith('.ifc')) return const Color(0xFF0891B2);
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return const Color(0xFFE11D48);
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return const Color(0xFF16A34A);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.receiveFiles,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.receiveFilesSubtitle,
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

              if (_latestReceivedFileName != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${context.l10n.receivedFiles}: $_latestReceivedFileName',
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _notificationDismissTimer?.cancel();
                          setState(() => _latestReceivedFileName = null);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_isStarting)
                _buildLoading()
              else if (_hasError)
                _buildError(context)
              else
                _buildContent(context),
            ],
          ),
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
            'Starting Wi-Fi server...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Getting LAN network address',
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
          const Icon(Icons.wifi_off_rounded, size: 54, color: Color(0xFFEF4444)),
          const SizedBox(height: 14),
          const Text(
            'Cannot start Wi-Fi receiver',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage?.replaceAll('Exception: ', '') ??
                'Make sure your device is connected to a local Wi-Fi network and try again.',
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
                borderRadius: BorderRadius.circular(12),
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

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayUrl = _serverUrl ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: displayUrl,
            version: QrVersions.auto,
            size: 170,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF6366F1),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Steps box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF6366F1)),
                  SizedBox(width: 6),
                  Text(
                    'How to upload:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '1. Open browser on your PC or phone (same Wi-Fi)\n'
                '2. Scan QR or type the IP address below\n'
                '3. Drag & drop ZIP presentations, CAD or documents',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF4338CA),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // IP URL Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => _copyToClipboard(displayUrl, 'Server URL'),
                tooltip: 'Copy URL',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Received files section
        if (_receivedFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${context.l10n.receivedFiles} (${_receivedFiles.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _receivedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final file = _receivedFiles[index];
                final name = file.path.split(Platform.pathSeparator).last;
                final size = file.existsSync() ? file.lengthSync() : 0;
                final color = _colorForFile(file.path);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconForFile(file.path),
                          size: 18,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatFileSize(size),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _openFile(file),
                        child: Text(
                          context.l10n.openFile,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _stopServer,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text(
              _receivedFiles.isEmpty ? 'Close Server' : 'Done',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
