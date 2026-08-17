import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/theme/app_theme.dart';
import 'local_network_share_dialog.dart';

enum _ShareFileType { pdf, dxf, svg, stl, obj, glb, xlsx, txt, md, docx, eps, other }

_ShareFileType _detectFileType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.pdf')) return _ShareFileType.pdf;
  if (lower.endsWith('.dxf')) return _ShareFileType.dxf;
  if (lower.endsWith('.svg')) return _ShareFileType.svg;
  if (lower.endsWith('.stl')) return _ShareFileType.stl;
  if (lower.endsWith('.obj')) return _ShareFileType.obj;
  if (lower.endsWith('.glb') || lower.endsWith('.gltf')) return _ShareFileType.glb;
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return _ShareFileType.xlsx;
  if (lower.endsWith('.txt') || lower.endsWith('.log') || lower.endsWith('.csv')) return _ShareFileType.txt;
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) return _ShareFileType.md;
  if (lower.endsWith('.docx') || lower.endsWith('.doc')) return _ShareFileType.docx;
  if (lower.endsWith('.eps')) return _ShareFileType.eps;
  return _ShareFileType.other;
}

class ShareOptionsSheet extends StatelessWidget {
  final String filePath;

  const ShareOptionsSheet({super.key, required this.filePath});

  Future<void> _shareViaEmail(BuildContext context) async {
    Navigator.pop(context);

    final success = await NativeShareService.shareViaEmail(filePath);

    if (!success && context.mounted) {
      _showError(context, 'Error sharing via Email');
    }
  }

  Future<void> _shareViaMessaging(BuildContext context) async {
    Navigator.pop(context);

    final success = await NativeShareService.shareViaMessaging(filePath);

    if (!success && context.mounted) {
      _showError(context, 'Error sharing via messaging');
    }
  }

  Future<void> _shareWithAll(BuildContext context) async {
    Navigator.pop(context);

    try {
      final file = File(filePath);
      if (await file.exists()) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        await Share.shareXFiles(
          [XFile(filePath)],
          subject: filePath.split(Platform.pathSeparator).last,
          sharePositionOrigin: origin,
        );
      } else if (context.mounted) {
        _showError(context, 'File does not exist');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Error opening share dialog: $e');
      }
    }
  }

  void _shareViaLocalNetwork(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocalNetworkShareDialog(filePath: filePath),
    );
  }

  Future<void> _shareViaCloud(BuildContext context) async {
    Navigator.pop(context);

    final success = await NativeShareService.shareViaCloud(filePath);

    if (!success && context.mounted) {
      _showError(context, 'Error uploading to cloud');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileType = _detectFileType(filePath);

    final bool isDxf = fileType == _ShareFileType.dxf;
    final bool isSvg = fileType == _ShareFileType.svg;
    final bool is3d = fileType == _ShareFileType.stl ||
        fileType == _ShareFileType.obj ||
        fileType == _ShareFileType.glb;
    final bool isXlsx = fileType == _ShareFileType.xlsx;
    final bool isTxt = fileType == _ShareFileType.txt;
    final bool isMd = fileType == _ShareFileType.md;
    final bool isDocx = fileType == _ShareFileType.docx;
    final bool isEps = fileType == _ShareFileType.eps;

    final Color cardColorStart = isDxf
        ? const Color(0xFF059669)
        : isSvg
            ? const Color(0xFFEA580C)
            : is3d
                ? const Color(0xFF0891B2)
                : isXlsx
                    ? const Color(0xFF107C41)
                    : isDocx
                        ? const Color(0xFF2563EB)
                        : isEps
                            ? const Color(0xFF8B5CF6)
                            : isTxt
                                ? const Color(0xFF475569)
                                : isMd
                                    ? const Color(0xFF4338CA)
                                    : AppTheme.primaryColor;
    final Color cardColorEnd = isDxf
        ? const Color(0xFF10B981)
        : isSvg
            ? const Color(0xFFFB923C)
            : is3d
                ? const Color(0xFF06B6D4)
                : isXlsx
                    ? const Color(0xFF22C55E)
                    : isDocx
                        ? const Color(0xFF60A5FA)
                        : isEps
                            ? const Color(0xFFA78BFA)
                            : isTxt
                                ? const Color(0xFF64748B)
                                : isMd
                                    ? const Color(0xFF6366F1)
                                    : AppTheme.secondaryColor;
    final IconData fileIcon = isDxf
        ? Icons.draw_rounded
        : isSvg
            ? Icons.gesture_rounded
            : is3d
                ? Icons.view_in_ar_rounded
                : isXlsx
                    ? Icons.table_chart_rounded
                    : isDocx
                        ? Icons.article_rounded
                        : isEps
                            ? Icons.gesture_rounded
                            : isTxt
                                ? Icons.description_rounded
                                : isMd
                                    ? Icons.menu_book_rounded
                                    : Icons.picture_as_pdf_rounded;
    final String sendLabel = isDxf
        ? 'Send DXF Drawing'
        : isSvg
            ? 'Send SVG Vector'
            : is3d
                ? 'Send 3D Model'
                : isXlsx
                    ? 'Send Spreadsheet'
                    : isDocx
                        ? 'Send Word Document'
                        : isEps
                            ? 'Send EPS Vector'
                            : isTxt
                                ? 'Send Text Document'
                                : isMd
                                    ? 'Send Markdown Document'
                                    : 'Send Document';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // File card — gradient accent instead of plain text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cardColorStart.withValues(alpha: isDark ? 0.18 : 0.08),
                  cardColorEnd.withValues(alpha: isDark ? 0.12 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardColorStart, cardColorEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fileIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sendLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Share options — each tinted with a brand color
          _ShareOptionTile(
            icon: Icons.email_rounded,
            color: AppTheme.primaryColor,
            title: 'Email',
            subtitle: 'Gmail, Outlook and more',
            isDark: isDark,
            onTap: () => _shareViaEmail(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.chat_bubble_rounded,
            color: AppTheme.accentColor,
            title: 'Message',
            subtitle: 'Viber, WhatsApp, Messenger, Telegram',
            isDark: isDark,
            onTap: () => _shareViaMessaging(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.cloud_upload_rounded,
            color: AppTheme.secondaryColor,
            title: 'Cloud',
            subtitle: 'Google Drive, Dropbox, OneDrive',
            isDark: isDark,
            onTap: () => _shareViaCloud(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.wifi_rounded,
            color: const Color(0xFF9333EA), // Purple color for local network
            title: 'Local Network',
            subtitle: 'Share with QR code over WiFi',
            isDark: isDark,
            onTap: () => _shareViaLocalNetwork(context),
          ),

          const SizedBox(height: 8),

          // Show all — text button, low visual weight on purpose
          TextButton.icon(
            onPressed: () => _shareWithAll(context),
            icon: Icon(
              Icons.apps_rounded,
              size: 18,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            label: Text(
              'All Options',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _ShareOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
