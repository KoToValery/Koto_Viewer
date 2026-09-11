import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_error_handler.dart';
import 'error_log_dialog.dart';

/// A user-friendly error screen displayed when a widget build or rendering fails,
/// replacing the default Flutter red/grey error screen.
class GlobalCrashWidget extends StatefulWidget {
  final FlutterErrorDetails details;

  const GlobalCrashWidget({
    super.key,
    required this.details,
  });

  @override
  State<GlobalCrashWidget> createState() => _GlobalCrashWidgetState();
}

class _GlobalCrashWidgetState extends State<GlobalCrashWidget> {
  bool _isExpanded = false;
  bool _isCopied = false;

  String _formatErrorDetails() {
    final buffer = StringBuffer();
    buffer.writeln('=== ERROR DETAILS ===');
    buffer.writeln('Exception: ${widget.details.exception}');
    if (widget.details.context != null) {
      buffer.writeln('Context: ${widget.details.context}');
    }
    if (widget.details.library != null) {
      buffer.writeln('Library: ${widget.details.library}');
    }
    if (widget.details.stack != null) {
      buffer.writeln('\n=== STACK TRACE ===');
      buffer.writeln(widget.details.stack);
    }
    return buffer.toString();
  }

  Future<void> _copyToClipboard() async {
    final text = _formatErrorDetails();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(() {
        _isCopied = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    }
  }

  void _navigateHome() {
    final nav = AppErrorHandler.navigatorKey?.currentState ?? Navigator.maybeOf(context);
    if (nav != null) {
      if (nav.canPop()) {
        nav.pop();
      } else {
        nav.pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Material(
      color: bgColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Warning Icon Container
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Something went wrong',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'The application encountered an unexpected issue while rendering or processing this screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _navigateHome,
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Go to Home'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: Icon(
                            _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                            size: 18,
                            color: _isCopied ? Colors.green : null,
                          ),
                          label: Text(_isCopied ? 'Copied!' : 'Copy Report'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Secondary action: View all error logs
                    TextButton.icon(
                      onPressed: () => ErrorLogDialog.show(context),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('View Error Log'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Collapsible Technical Details
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'Hide technical details' : 'Show technical details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: subtextColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _formatErrorDetails(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
