import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/vertical_capacity_models.dart';
import '../analysis/support_layout_evaluator.dart';
import '../analysis/slab_boundary_geometry.dart';
import 'layout_assessment_summary.dart';

/// Modal bottom sheet presenting a comprehensive Eurocode 2 (EC2) vertical gravitational
/// capacity report covering column axial crushing, punching shear, slab span-to-depth deflection,
/// and foundation soil pressure.
class VerticalCapacitySheet extends StatefulWidget {
  final VerticalCapacityReport report;
  final Map<String, SupportLayoutAssessment> assessments;

  const VerticalCapacitySheet({super.key, required this.report,
    this.assessments = const {},
  });

  @override
  State<VerticalCapacitySheet> createState() => _VerticalCapacitySheetState();
}

class _VerticalCapacitySheetState extends State<VerticalCapacitySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.domain_rounded,
                      color: Color(0xFF00E5FF), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.verticalCapacityTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.l10n.verticalCapacitySubtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                  title: context.l10n.totalBaseLoad,
                  value: '${report.totalVerticalLoadBaseKn.toStringAsFixed(0)} kN',
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.verticalBasePressure,
                  value: '${report.basePressureKpa.toStringAsFixed(0)} kPa',
                  color: report.basePressureKpa > 250
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF64B5F6),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.criticalColumns,
                  value: '${report.criticalColumnsCount}',
                  color: report.criticalColumnsCount > 0
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF00E676),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: context.l10n.punchingRisks,
                  value: '${report.punchingRiskCount}',
                  color: report.punchingRiskCount > 0
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF00E676),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_column_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(context.l10n.verticalTabColumns(report.columnChecks.length)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(context.l10n.verticalTabSlabs(report.slabChecks.length)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.foundation_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(context.l10n.verticalTabFoundations),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tab Views
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildColumnsTab(context, report),
                  _buildSlabsTab(context, report),
                  _buildFoundationsTab(context, report),
                ],
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnsTab(BuildContext context, VerticalCapacityReport report) {
    if (report.columnChecks.isEmpty) {
      return Center(
        child: Text(
          context.l10n.verticalNoColumns,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    // Sort: critical first, then warning, then safe
    final sortedChecks = List<ColumnVerticalCheck>.from(report.columnChecks)
      ..sort((a, b) {
        final aPriority = a.status == VerticalCapacityStatus.critical
            ? 0
            : (a.status == VerticalCapacityStatus.warning ? 1 : 2);
        final bPriority = b.status == VerticalCapacityStatus.critical
            ? 0
            : (b.status == VerticalCapacityStatus.warning ? 1 : 2);
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        return b.axialUtilization.compareTo(a.axialUtilization);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: sortedChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final col = sortedChecks[idx];
        return _buildColumnCard(context, col);
      },
    );
  }

  Widget _buildColumnCard(BuildContext context, ColumnVerticalCheck col) {
    final statusColor = col.status.color;
    final int curWCm = (col.widthM * 100).round();
    final int curHCm = (col.heightM * 100).round();

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
          // Header: Name, Storey, Dimensions & Status Badge
          Row(
            children: [
              Icon(Icons.view_column_rounded, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${col.columnName} (${curWCm}x$curHCm cm)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      context.l10n.verticalStoreysCarried(
                        col.storeyName,
                        col.numStoreysAbove,
                        col.numStoreysAbove == 1 ? context.l10n.verticalStoreySingle : context.l10n.verticalStoreyPlural,
                        col.tributaryAreaM2.toStringAsFixed(1),
                      ),
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
                  col.status.localizedLabel(context.l10n),
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

          // Utilization Metrics
          // 1. Axial Compression N_Ed vs N_Rd
          _buildUtilizationRow(
            label: context.l10n.verticalAxialCompressionLabel,
            valueText:
                'Ned = ${col.accumulatedLoadNedKn.toStringAsFixed(0)} kN / Nrd = ${col.axialCapacityNrdKn.toStringAsFixed(0)} kN',
            ratio: col.axialUtilization,
            color: col.isAxiallyOverloaded
                ? const Color(0xFFFF1744)
                : (col.axialUtilization > 0.8
                    ? const Color(0xFFFFB300)
                    : const Color(0xFF00E676)),
          ),
          const SizedBox(height: 6),

          // 2. Punching Shear v_Ed vs v_Rd,c
          _buildUtilizationRow(
            label: context.l10n.verticalPunchingCheckLabel,
            valueText:
                'v_Ed = ${col.punchingShearStressVedMpa.toStringAsFixed(2)} MPa / v_Rd,c = ${col.punchingShearResistanceVrdMpa.toStringAsFixed(2)} MPa',
            ratio: col.punchingUtilization,
            color: col.isPunchingCritical
                ? const Color(0xFFFF1744)
                : ((col.punchingUtilization > 0.85 ||
                          col.punchingRequiresReview)
                      ? const Color(0xFFFFB300)
                    : const Color(0xFF00E676)),
          ),
          const SizedBox(height: 10),

          // Architect-facing Recommendation Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  col.hasCritical
                      ? Icons.error_outline_rounded
                      : (col.hasWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    col.localizedRecommendation(context.l10n),
                    style: TextStyle(
                      color: col.hasCritical ? const Color(0xFFFF8A80) : Colors.white,
                      fontSize: 11,
                      fontWeight: col.hasCritical ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${switch (col.punchingPosition) {
              PunchingSupportPosition.interior => context.l10n.schemeInteriorColumn,
              PunchingSupportPosition.edge => context.l10n.schemeEdgeColumn,
              PunchingSupportPosition.corner => context.l10n.schemeCornerColumn,
              PunchingSupportPosition.undetermined => context.l10n.schemeUnknownColumnPosition,
            }} · β ${col.punchingBeta.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (col.punchingRequiresReview)
            Text(
              context.l10n.schemePunchingGeometryReview,
              style: const TextStyle(color: Colors.amber, fontSize: 11),
          ),

          // Optional Punching Warning
          if (col.punchingRecommendation != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9100).withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFFF9100)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      col.localizedPunchingRecommendation(context.l10n) ?? col.punchingRecommendation!,
                      style: const TextStyle(
                        color: Color(0xFFFFD180),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUtilizationRow({
    required String label,
    required String valueText,
    required double ratio,
    required Color color,
  }) {
    final percent = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$valueText ($percent%)',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildSlabsTab(BuildContext context, VerticalCapacityReport report) {
    if (report.slabChecks.isEmpty) {
      return Center(
        child: Text(
          context.l10n.verticalNoSlabs,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: report.slabChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final slab = report.slabChecks[idx];
        final assessment = widget.assessments[slab.storeyId];
        final unresolved =
            assessment != null &&
            (assessment.topology.invalidGeometry ||
                assessment.topology.limited ||
                assessment.topology.unresolvedAreaM2 > 1e-6 ||
                assessment.topology.fields.any((f) => f.requiresReview));
        final bool isSafe = slab.isDeflectionSafe && !unresolved;
        final color = (!slab.isSpanDetermined || unresolved)
            ? Colors.amber : isSafe ? const Color(0xFF00E676) : const Color(0xFFFF1744);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.verticalSlabStoreyTitle(slab.storeyName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      (!slab.isSpanDetermined || unresolved)
                          ? context.l10n.schemeSpanUnknown : isSafe ? context.l10n.verticalSlabStatusOk : context.l10n.verticalSlabStatusEnlarge,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubmetric(
                    context.l10n.verticalClearSpanLmax,
                    slab.isSpanDetermined ? '${slab.maxSpanM.toStringAsFixed(2)} m' : '—',
                  ),
                  _buildSubmetric(
                    context.l10n.verticalCurrentThicknessH,
                    '${(slab.currentThicknessM * 100).round()} cm',
                  ),
                  _buildSubmetric(
                    context.l10n.verticalRequiredThicknessEc2,
                    slab.isSpanDetermined ? '${(slab.recommendedMinThicknessM * 100).round()} cm' : '—',
                    color: !isSafe ? const Color(0xFFFF1744) : Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.assessments[slab.storeyId] != null)
                LayoutAssessmentSummary(
                  assessment: widget.assessments[slab.storeyId]!,
                ),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSafe ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slab.localizedRecommendation(context.l10n),
                        style: TextStyle(
                          color: isSafe ? Colors.white70 : const Color(0xFFFF8A80),
                          fontSize: 11,
                          fontWeight: !isSafe ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoundationsTab(BuildContext context, VerticalCapacityReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.foundation_rounded, color: Color(0xFF00E5FF), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.verticalFoundationsEvaluation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoLine(context.l10n.verticalTotalBaseLoadNed,
                    '${report.totalVerticalLoadBaseKn.toStringAsFixed(1)} kN'),
                const SizedBox(height: 6),
                _buildInfoLine(context.l10n.verticalFootprintArea,
                    '${report.footprintAreaM2.toStringAsFixed(1)} m²'),
                const SizedBox(height: 6),
                _buildInfoLine(context.l10n.verticalMeanBasePressure,
                    '${report.basePressureKpa.toStringAsFixed(1)} kPa (${(report.basePressureKpa / 100).toStringAsFixed(2)} kg/cm²)'),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.basePressureKpa <= 200
                              ? context.l10n.verticalBasePressureSafeText(report.basePressureKpa.toStringAsFixed(0))
                              : context.l10n.verticalBasePressureHighText(report.basePressureKpa.toStringAsFixed(0)),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
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

  Widget _buildSubmetric(String title, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
