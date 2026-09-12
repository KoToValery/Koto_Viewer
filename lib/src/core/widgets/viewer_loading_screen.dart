import 'package:flutter/material.dart';
import '../l10n/l10n_extensions.dart';

/// Unified modern loading screen for file viewers (PDF, 3D CAD, Ebooks, CAD, DOCX, XLSX, etc.)
/// Displays a glowing format-themed icon, file name, formatted file size badge,
/// progress bar with status message, and an easily accessible cancel/close button.
class ViewerLoadingScreen extends StatelessWidget {
  final String fileName;
  final int? fileSizeBytes;
  final IconData icon;
  final Color accentColor;
  final String? loadingTitle;
  final String? statusMessage;
  final double? progress;
  final String? progressDetails;
  final VoidCallback? onCancel;

  const ViewerLoadingScreen({
    super.key,
    required this.fileName,
    this.fileSizeBytes,
    required this.icon,
    required this.accentColor,
    this.loadingTitle,
    this.statusMessage,
    this.progress,
    this.progressDetails,
    this.onCancel,
  });

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final formattedSize = fileSizeBytes != null ? _formatFileSize(fileSizeBytes!) : '';
    final l10n = context.l10n;
    final effectiveTitle = loadingTitle ?? l10n.loadingFile;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: l10n.cancel,
          onPressed: () {
            if (onCancel != null) {
              onCancel!();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Format Icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.28),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),

                // File Name
                Text(
                  fileName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),

                // File Size Badge
                if (formattedSize.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      formattedSize,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Progress Info Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        progressDetails ?? effectiveTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (progress != null)
                      Text(
                        '${(progress! * 100).clamp(0, 100).toInt()}%',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),

                // Subtitle Status Message
                if (statusMessage != null && statusMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    statusMessage!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
