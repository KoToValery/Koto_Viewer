import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modern, comprehensive App Info & About dialog with dynamic version detection.
class AppInfoDialog extends StatefulWidget {
  const AppInfoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const AppInfoDialog(),
    );
  }

  @override
  State<AppInfoDialog> createState() => _AppInfoDialogState();
}

class _AppInfoDialogState extends State<AppInfoDialog> {
  PackageInfo? _packageInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/KoToValery/Koto_Viewer');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final versionText = _isLoading
        ? 'Loading version...'
        : _packageInfo != null
            ? 'v${_packageInfo!.version} (Build ${_packageInfo!.buildNumber})'
            : 'v1.0.0';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF161E2E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header with App Icon, Name and Version Badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.primary,
                          child: const Icon(Icons.architecture_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'KotoView',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                versionText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Universal CAD, 3D BIM, PCB & Document Viewer',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary
                    Text(
                      'A fast, offline, and 100% free open-source viewer engineered for CAD, 3D engineering models, PCB Gerber packages, vector graphics, and standard office documents.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Supported Formats Categories
                    _buildSectionHeader('Supported Formats & Engines', Icons.category_rounded, theme),
                    const SizedBox(height: 8),
                    _buildFeatureCard(
                      icon: Icons.draw_rounded,
                      title: '2D CAD & Engineering Drawings',
                      formats: ['DXF', 'DWG (LibreDWG)', 'HPGL / PLT', 'SVG'],
                      description: 'Full AutoCAD layer control, precision snap, area hatching, and BGS 2005 / WGS 84 / UTM coordinate transformation.',
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureCard(
                      icon: Icons.view_in_ar_rounded,
                      title: '3D CAD Models & BIM',
                      formats: ['STEP (.stp)', 'IGES (.igs)', 'STL', 'IFC (BIM)', 'OBJ', 'GLTF / GLB'],
                      description: 'GPU-accelerated 3D orbital camera, wireframe/shaded modes, and BIM building elements inspector.',
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureCard(
                      icon: Icons.memory_rounded,
                      title: 'PCB Electronics & Manufacturing',
                      formats: ['Gerber RS-274X', 'Excellon Drill', 'ZIP Archives (Altium, KiCad, Eagle, EasyEDA)'],
                      description: 'Composite multi-layer board stackup, drill hole mapping, solder mask toggles, and standardized copper colors.',
                      color: const Color(0xFF059669),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureCard(
                      icon: Icons.brush_rounded,
                      title: 'Vector Graphics',
                      formats: ['CorelDRAW (.cdr)', 'Adobe EPS (.eps)', 'SVG'],
                      description: 'Native RIFF and PostScript vector path rasterization and color palette extraction.',
                      color: const Color(0xFFEA580C),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureCard(
                      icon: Icons.description_rounded,
                      title: 'Office & Text Documents',
                      formats: ['PDF', 'Word (.docx)', 'Excel (.xlsx)', 'PowerPoint (.pptx, .ppt)', 'Markdown (.md)', 'TXT'],
                      description: 'Fast hardware-accelerated PDF engine, formatted Word XML, Excel spreadsheet grid, and presentation slides.',
                      color: const Color(0xFFD97706),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // License & Open Source
                    _buildSectionHeader('Open Source & Licensing', Icons.verified_user_rounded, theme),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('Licensed under GNU General Public License v3.0 (GPLv3)'),
                          const SizedBox(height: 4),
                          _buildBulletPoint('100% Free and Open Source Software (FOSS)'),
                          const SizedBox(height: 4),
                          _buildBulletPoint('DWG conversion powered by GNU LibreDWG'),
                          const SizedBox(height: 4),
                          _buildBulletPoint('No cloud dependencies • 100% Offline & Private'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'KotoView',
                        applicationVersion: versionText,
                        applicationIcon: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/icons/app_icon.png', width: 36, height: 36),
                        ),
                      );
                    },
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text('Licenses', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openGitHub,
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('GitHub', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required List<String> formats,
    required String description,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: formats.map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}
