import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/pdf_certificate_models.dart';
import '../services/pdf_certificate_service.dart';

class PdfCertificateInfoDialog extends StatefulWidget {
  final String filePath;
  final List<PdfCertificateInfo> initialCertificates;

  const PdfCertificateInfoDialog({
    super.key,
    required this.filePath,
    required this.initialCertificates,
  });

  static Future<void> show({
    required BuildContext context,
    required String filePath,
    required List<PdfCertificateInfo> certificates,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PdfCertificateInfoDialog(
        filePath: filePath,
        initialCertificates: certificates,
      ),
    );
  }

  @override
  State<PdfCertificateInfoDialog> createState() => _PdfCertificateInfoDialogState();
}

class _PdfCertificateInfoDialogState extends State<PdfCertificateInfoDialog> {
  late List<PdfCertificateInfo> _certificates;
  bool _isLoadingExternal = false;

  @override
  void initState() {
    super.initState();
    _certificates = List.from(widget.initialCertificates);
  }

  Future<void> _pickAndInspectExternalCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cer', 'crt', 'pfx', 'p12', 'pem'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return;
    }

    final extPath = result.files.single.path!;
    final isPfx = extPath.toLowerCase().endsWith('.pfx') || extPath.toLowerCase().endsWith('.p12');

    String? password;
    if (isPfx && mounted) {
      final passwordController = TextEditingController();
      final entered = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Certificate Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter PFX password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.ok),
            ),
          ],
        ),
      );
      if (entered != true) return;
      password = passwordController.text;
    }

    setState(() => _isLoadingExternal = true);

    try {
      final bytes = await File(extPath).readAsBytes();
      final certInfo = await PdfCertificateService.readExternalCertificate(bytes, password: password);
      if (mounted) {
        setState(() {
          _isLoadingExternal = false;
          if (certInfo != null) {
            _certificates = [certInfo, ..._certificates];
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not read certificate or incorrect password.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExternal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading certificate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dateFormat = DateFormat.yMMMMd().add_Hm();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _certificates.isNotEmpty ? Colors.green.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _certificates.isNotEmpty ? Icons.verified_user_rounded : Icons.security_outlined,
              color: _certificates.isNotEmpty ? Colors.green.shade700 : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.pdfDigitalCertificates,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_certificates.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.pdfNoDigitalCertificates,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                for (int i = 0; i < _certificates.length; i++) ...[
                  _buildCertificateCard(_certificates[i], theme, l10n, dateFormat),
                  if (i < _certificates.length - 1) const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 12),
              // Button to check an external certificate file (.cer / .pfx)
              OutlinedButton.icon(
                onPressed: _isLoadingExternal ? null : _pickAndInspectExternalCertificate,
                icon: _isLoadingExternal
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_open_outlined, size: 18),
                label: Text(
                  l10n.pdfCheckExternalCert,
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _buildCertificateCard(
    PdfCertificateInfo cert,
    ThemeData theme,
    dynamic l10n,
    DateFormat dateFormat,
  ) {
    final isExpired = cert.isExpired;
    final isNotYetValid = cert.isNotYetValid;

    Color badgeColor = Colors.green.shade700;
    String badgeText = l10n.pdfSignatureValid;
    if (isExpired) {
      badgeColor = Colors.orange.shade800;
      badgeText = l10n.pdfSignatureExpired;
    } else if (isNotYetValid) {
      badgeColor = Colors.orange.shade800;
      badgeText = 'Not Yet Valid';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cert.displaySigner,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          if (cert.issuerName != null && cert.issuerName!.isNotEmpty)
            _buildDetailRow(l10n.pdfIssuer, cert.issuerName!, Icons.account_balance_outlined, theme),

          if (cert.organization != null && cert.organization!.isNotEmpty)
            _buildDetailRow('Organization:', cert.organization!, Icons.business_outlined, theme),

          if (cert.signDate != null)
            _buildDetailRow(l10n.pdfSignDate, dateFormat.format(cert.signDate!), Icons.schedule_outlined, theme),

          if (cert.validFrom != null && cert.validTo != null)
            _buildDetailRow(
              'Validity:',
              '${dateFormat.format(cert.validFrom!)} - ${dateFormat.format(cert.validTo!)}',
              Icons.date_range_outlined,
              theme,
            ),

          if (cert.reason != null && cert.reason!.isNotEmpty)
            _buildDetailRow('Reason:', cert.reason!, Icons.comment_outlined, theme),

          if (cert.location != null && cert.location!.isNotEmpty)
            _buildDetailRow('Location:', cert.location!, Icons.place_outlined, theme),

          if (cert.subFilter != null && cert.subFilter!.isNotEmpty)
            _buildDetailRow('Format:', cert.subFilter!, Icons.fingerprint_outlined, theme),

          if (cert.serialNumber != null && cert.serialNumber!.isNotEmpty)
            _buildDetailRow('Serial No:', cert.serialNumber!, Icons.tag_outlined, theme),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
