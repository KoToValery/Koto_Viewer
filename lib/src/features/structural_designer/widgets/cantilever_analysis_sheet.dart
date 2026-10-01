import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/cantilever_analysis_models.dart';

/// Modal bottom sheet presenting a comprehensive Eurocode 2 structural check report
/// for all detected linear cantilevers, double corner cantilevers, and transfer columns.
class CantileverAnalysisSheet extends StatelessWidget {
  final StructuralAnalysisSummary summary;

  const CantileverAnalysisSheet({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Color(0xFF00E5FF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.cantileverAnalysisTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Summary Metrics Cards
            Row(
              children: [
                _buildStatCard(
                  title: context.l10n.totalCantilevers,
                  value: '${summary.totalCantilevers}',
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.cornerCantilevers,
                  value: '${summary.cornerCantilevers}',
                  color: summary.cornerCantilevers > 0
                      ? const Color(0xFFFFB300)
                      : Colors.white70,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.criticalZones,
                  value: '${summary.criticalCount}',
                  color: summary.criticalCount > 0
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF00E676),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.maxDeflection,
                  value: '${summary.maxDeflectionMm.toStringAsFixed(1)} mm',
                  color: summary.maxDeflectionRatio > 1.0
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF00E5FF),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Eurocode standard info banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.eurocodeStandardInfo,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Zones List
            if (summary.zones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF00E676), size: 48),
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.noCantileversFound,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: summary.zones.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final zone = summary.zones[idx];
                    return _buildZoneCard(context, zone);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, CantileverZone zone) {
    final statusColor = zone.riskLevel.color;
    final bool isOverLimit = zone.longTermDeflectionMm > zone.limitDeflectionMm;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Type & Risk Badge
          Row(
            children: [
              Icon(zone.type.icon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.type.localizedLabel(context.l10n),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      zone.storeyName,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  zone.riskLevel.localizedLabel(context.l10n),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Geometric Properties Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (zone.isCorner) ...[
                _buildProp('Lx', '${zone.length.toStringAsFixed(2)} m'),
                _buildProp('Ly', '${zone.lengthY?.toStringAsFixed(2) ?? '-'} m'),
                _buildProp('Ldiag', '${zone.effectiveDiagonal?.toStringAsFixed(2)} m'),
              ] else ...[
                _buildProp(context.l10n.propLengthL, '${zone.length.toStringAsFixed(2)} m'),
              ],
              _buildProp(context.l10n.propSlabH, '${(zone.slabThickness * 100).toInt()} cm'),
              _buildProp(
                'L/h',
                zone.slendernessRatio.toStringAsFixed(1),
                color: zone.slendernessRatio > 10.0
                    ? const Color(0xFFFF1744)
                    : (zone.slendernessRatio > 7.0
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF00E676)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Deflection Comparison Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.deflectionFtot(zone.longTermDeflectionMm.toStringAsFixed(1)),
                          style: TextStyle(
                            color: isOverLimit
                                ? const Color(0xFFFF1744)
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          context.l10n.deflectionLimitFlim(zone.limitDeflectionMm.toStringAsFixed(1)),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (zone.deflectionRatio / 1.5).clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: isOverLimit
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00E676),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recommendations
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rec in zone.recommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: Color(0xFF00E5FF), fontSize: 12)),
                        Expanded(
                          child: Text(
                            rec,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProp(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
