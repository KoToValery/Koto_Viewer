import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/theme/app_theme.dart';
import 'local_network_share_dialog.dart';

class ShareOptionsSheet extends StatelessWidget {
  final String filePath;

  const ShareOptionsSheet({
    super.key,
    required this.filePath,
  });

  Future<void> _shareViaEmail(BuildContext context) async {
    Navigator.pop(context);
    
    final success = await NativeShareService.shareViaEmail(filePath);
    
    if (!success && context.mounted) {
      _showError(context, 'Грешка при споделяне по Email');
    }
  }

  Future<void> _shareViaMessaging(BuildContext context) async {
    Navigator.pop(context);
    
    final success = await NativeShareService.shareViaMessaging(filePath);
    
    if (!success && context.mounted) {
      _showError(context, 'Грешка при споделяне по съобщения');
    }
  }

  Future<void> _shareViaCloud(BuildContext context) async {
    Navigator.pop(context);
    
    final success = await NativeShareService.shareViaCloud(filePath);
    
    if (!success && context.mounted) {
      _showError(context, 'Грешка при качване в облак');
    }
  }

  void _shareViaLocalNetwork(BuildContext context) {
    Navigator.pop(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LocalNetworkShareDialog(filePath: filePath),
    );
  }

  Future<void> _shareWithAll(BuildContext context) async {
    Navigator.pop(context);
    
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'PDF Document',
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Грешка при споделяне: $e');
      }
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
                  AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.08),
                  AppTheme.secondaryColor.withValues(alpha: isDark ? 0.12 : 0.05),
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
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Изпрати документ',
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
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
            subtitle: 'Gmail, Outlook и други',
            isDark: isDark,
            onTap: () => _shareViaEmail(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.chat_bubble_rounded,
            color: AppTheme.accentColor,
            title: 'Съобщение',
            subtitle: 'Viber, WhatsApp, Messenger',
            isDark: isDark,
            onTap: () => _shareViaMessaging(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.cloud_upload_rounded,
            color: AppTheme.secondaryColor,
            title: 'Облак',
            subtitle: 'Google Drive, Dropbox, OneDrive',
            isDark: isDark,
            onTap: () => _shareViaCloud(context),
          ),

          const SizedBox(height: 10),

          _ShareOptionTile(
            icon: Icons.wifi_rounded,
            color: const Color(0xFF9333EA), // Purple color for local network
            title: 'Локална мрежа',
            subtitle: 'Сподели с QR код в WiFi мрежата',
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
              'Всички опции',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

