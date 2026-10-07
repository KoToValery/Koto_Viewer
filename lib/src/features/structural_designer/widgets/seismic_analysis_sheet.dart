import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/seismic_analysis_models.dart';
import '../analysis/diaphragm_storey_links.dart';

/// Modal bottom sheet presenting a comprehensive Eurocode 8 (EC8) seismic analysis report
/// covering Center of Mass vs Rigidity, torsional balance, shear wall coverage ratios,
/// vertical regularity (floating/transfer columns), soft storeys, and beam sizing.
class SeismicAnalysisSheet extends StatefulWidget {
  final SeismicAnalysisReport report;
  final VoidCallback? onEditLoads;
  final void Function(String storeyId, String elementId, bool isWall)? onLocateElement;

  const SeismicAnalysisSheet({super.key, required this.report, this.onEditLoads, this.onLocateElement});

  @override
  State<SeismicAnalysisSheet> createState() => _SeismicAnalysisSheetState();
}

class _SeismicAnalysisSheetState extends State<SeismicAnalysisSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final canEvaluate = report.storeyChecks.isNotEmpty && report.storeyChecks.every((c) => c.hasSlabDiaphragm && c.hasLateralStiffness);

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
            if (widget.onEditLoads != null)
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: widget.onEditLoads, icon: const Icon(Icons.tune),
                label: Text(context.l10n.seismicLoadsTitle))),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD500F9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.waves_rounded,
                      color: Color(0xFFD500F9), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.seismicAnalysisTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.l10n.seismicAnalysisSubtitle,
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

            Text(context.l10n.seismicModelAssumptions,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 10),
            // Summary Metrics Cards
            Row(
              children: [
                _buildStatCard(
                  title: context.l10n.seismicStatMaxEccentricity,
                  value: canEvaluate
                      ? '${(report.maxEccentricityRatio * 100).round()}%'
                      : '—',
                  color: !canEvaluate ? const Color(0xFFFFB300) : report.hasTorsionalSensitivity
                      ? const Color(0xFFFF1744)
                      : (report.maxEccentricityRatio > 0.08
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF00E676)),
                ),
                const SizedBox(width: 6),
                _buildStatCard(
                  title: context.l10n.seismicStatTorsion,
                  value: !canEvaluate ? context.l10n.seismicNotEvaluated : report.hasTorsionalSensitivity
                      ? context.l10n.seismicStatusHigh
                      : (report.hasStructuralEccentricity
                          ? context.l10n.seismicStatusEccentricShort
                          : context.l10n.seismicStatusNormal),
                  color: !canEvaluate ? const Color(0xFFFFB300) : report.hasTorsionalSensitivity
                      ? const Color(0xFFFF1744)
                      : (report.hasStructuralEccentricity
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF00E676)),
                ),
                const SizedBox(width: 6),
                _buildStatCard(
                  title: context.l10n.seismicStatFloatingColumns,
                  value: '${report.totalFloatingColumnsCount}',
                  color: report.totalFloatingColumnsCount > 0
                      ? const Color(0xFFD500F9)
                      : const Color(0xFF00E676),
                ),
                const SizedBox(width: 6),
                _buildStatCard(
                  title: context.l10n.seismicStatShearWallsEc8,
                  value: report.hasWallDeficit
                      ? context.l10n.seismicStatusDeficit
                      : context.l10n.seismicStatusOkCoverage,
                  color: report.hasWallDeficit
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF00E676),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar - scrollable with intrinsic tab widths to prevent overflow
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFFD500F9),
              labelColor: const Color(0xFFD500F9),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.track_changes_rounded, size: 15),
                      const SizedBox(width: 4),
                      Text(context.l10n.seismicTabBalance),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.line_weight_rounded, size: 15),
                      const SizedBox(width: 4),
                      Text(context.l10n.seismicTabWalls),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.vertical_align_bottom_rounded, size: 15),
                      const SizedBox(width: 4),
                      Text(context.l10n.seismicTabRegularity),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.horizontal_rule_rounded, size: 15),
                      const SizedBox(width: 4),
                      Text(context.l10n.seismicTabBeamsOpenings),
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
                  _buildTorsionalTab(context, report),
                  _buildWallsTab(context, report),
                  _buildRegularityTab(context, report),
                  _buildBeamsAndOpeningsTab(context, report),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
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



  Widget _buildRegion(BuildContext context, DiaphragmRegionCheck region, int index) {
    final check = region.check;
    final eccentricity = check?.eccentricityM;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.seismicRegionTitle(index + 1, region.columnIds.length, region.wallIds.length),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        if (region.ambiguousSupportNames.isNotEmpty)
          Text(context.l10n.seismicRegionSharedSupport(region.ambiguousSupportNames.join(', ')),
            style: const TextStyle(color: Colors.amber, fontSize: 11))
        else if (check != null) ...[
          Row(children: [
            _buildSubmetric('A', '${check.floorAreaM2.toStringAsFixed(2)} m²'),
            _buildSubmetric(context.l10n.seismicEccentricityXLabel,
              eccentricity == null ? '—' : '${eccentricity.dx.toStringAsFixed(3)} m'),
            _buildSubmetric(context.l10n.seismicEccentricityYLabel,
              eccentricity == null ? '—' : '${eccentricity.dy.toStringAsFixed(3)} m'),
          ]),
          const SizedBox(height: 6),
          Text(check.localizedRecommendation(context.l10n),
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _buildTorsionalTab(BuildContext context, SeismicAnalysisReport report) {
    if (report.storeyChecks.isEmpty) {
      return Center(
        child: Text(context.l10n.seismicNoStoreys,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: report.storeyChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final check = report.storeyChecks[idx];

        if (!check.hasSlabDiaphragm || !check.hasLateralStiffness) {
          const color = Color(0xFFFFB300);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${check.storeyName} — ${context.l10n.seismicEccentricityTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
                        !check.hasSlabDiaphragm ? context.l10n.seismicNoSlabBadge : context.l10n.seismicNotEvaluated,
                        style: const TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubmetric(context.l10n.seismicEccentricityXLabel, context.l10n.seismicNoSlabEccentricity),
                    _buildSubmetric(context.l10n.seismicEccentricityYLabel, context.l10n.seismicNoSlabEccentricity),
                    _buildSubmetric(context.l10n.seismicLimitEc8Label, '—'),
                  ],
                ),
                const SizedBox(height: 8),
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
                      const Icon(Icons.info_outline, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          check.localizedRecommendation(context.l10n),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (check.diaphragmRegions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(context.l10n.seismicRegionScope,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  for (var i = 0; i < check.diaphragmRegions.length; i++)
                    _buildRegion(context, check.diaphragmRegions[i], i),
                ],
              ],
            ),
          );
        }

        final isSensitive = check.isTorsionallySensitive;
        final color = isSensitive
            ? const Color(0xFFFF1744)
            : (check.hasSignificantEccentricity || check.maxEccentricityRatio > 0.08
                ? const Color(0xFFFFB300)
                : const Color(0xFF00E676));
        final eccX = check.eccentricityM?.dx ?? 0.0;
        final eccY = check.eccentricityM?.dy ?? 0.0;
        final String badgeText = isSensitive
            ? context.l10n.seismicTorsionSensitive
            : (check.hasSignificantEccentricity
                ? context.l10n.seismicTorsionStiffEccentric
                : context.l10n.seismicBalanced);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${check.storeyName} — ${context.l10n.seismicEccentricityTitle}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
                      badgeText,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Detailed metrics Row 1: Structural Eccentricity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubmetric(context.l10n.seismicEccentricityXLabel, '${eccX.toStringAsFixed(2)} m (${(check.eccentricityRatioX * 100).round()}%)'),
                  _buildSubmetric(context.l10n.seismicEccentricityYLabel, '${eccY.toStringAsFixed(2)} m (${(check.eccentricityRatioY * 100).round()}%)'),
                  _buildSubmetric(
                    context.l10n.seismicLimitEc8Label,
                    check.torsionalRadiusX > 0 && check.torsionalRadiusY > 0
                        ? 'X ≤ ${(0.30 * check.torsionalRadiusX).toStringAsFixed(2)} m; Y ≤ ${(0.30 * check.torsionalRadiusY).toStringAsFixed(2)} m'
                        : '—',
                  ),
                ],
              ),
              if (check.torsionalRadiusX > 0 && check.massRadiusOfGyration > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubmetric(
                      context.l10n.seismicTorsionalRadiiLabel,
                      'rx=${check.torsionalRadiusX.toStringAsFixed(2)} m, ry=${check.torsionalRadiusY.toStringAsFixed(2)} m',
                    ),
                    _buildSubmetric(
                      context.l10n.seismicMassRadiusLabel,
                      'ls=${check.massRadiusOfGyration.toStringAsFixed(2)} m (${check.isTorsionallyStiff ? "r ≥ ls ✓" : "r < ls ⚠️"})',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),

              // Architectural Recommendation
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
                      isSensitive ? Icons.error_outline_rounded : Icons.check_circle_outline,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        check.localizedRecommendation(context.l10n),
                        style: TextStyle(
                          color: isSensitive ? const Color(0xFFFF8A80) : Colors.white,
                          fontSize: 11,
                          fontWeight: isSensitive ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildWallsTab(BuildContext context, SeismicAnalysisReport report) {
    if (report.storeyChecks.isEmpty) {
      return Center(
        child: Text(context.l10n.seismicNoStoreys,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: report.storeyChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final check = report.storeyChecks[idx];

        if (!check.hasSlabDiaphragm) {
          const cardColor = Color(0xFFFFB300);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardColor.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.line_weight_rounded, color: cardColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${check.storeyName} — ${context.l10n.seismicShearWallCoverageTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cardColor),
                      ),
                      child: Text(
                        context.l10n.seismicNoSlabBadge,
                        style: const TextStyle(
                          color: cardColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.seismicNoSlabWallCoverage,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          );
        }

        final bool okX = check.isWallCoverageSufficientX;
        final bool okY = check.isWallCoverageSufficientY;
        final Color cardColor = (!okX || !okY) ? const Color(0xFFFFB300) : const Color(0xFF00E676);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardColor.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.line_weight_rounded, color: cardColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${check.storeyName} — ${context.l10n.seismicShearWallCoverageTitle}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cardColor),
                    ),
                    child: Text(
                      (okX && okY) ? context.l10n.seismicOkMinCoverage : context.l10n.seismicDeficitMinCoverage,
                      style: TextStyle(
                        color: cardColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Coverage Bar X
              _buildRatioRow(
                label: context.l10n.seismicWallCoverageXLabel,
                valueText: '${check.wallRatioX.toStringAsFixed(2)}% (${check.wallAreaXM2.toStringAsFixed(1)} m²)',
                ratio: check.wallRatioX / 1.5,
                color: okX ? const Color(0xFF00E676) : const Color(0xFFFFB300),
              ),
              const SizedBox(height: 6),

              // Coverage Bar Y
              _buildRatioRow(
                label: context.l10n.seismicWallCoverageYLabel,
                valueText: '${check.wallRatioY.toStringAsFixed(2)}% (${check.wallAreaYM2.toStringAsFixed(1)} m²)',
                ratio: check.wallRatioY / 1.5,
                color: okY ? const Color(0xFF00E676) : const Color(0xFFFFB300),
              ),
              const SizedBox(height: 8),

              Text(
                context.l10n.seismicWallRecommendationText(check.floorAreaM2.toStringAsFixed(0)),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),

              if (check.disconnectedWallNames.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFB300),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFB300)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFB300)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.seismicWallsOutsideSlabWarning(check.disconnectedWallNames.length),
                          style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _elementLink(String storeyId, String id, bool wall, String text, Color color) {
    return InkWell(onTap: widget.onLocateElement == null ? null
      : () => widget.onLocateElement!(storeyId, id, wall),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11))),
        if(widget.onLocateElement != null) const Icon(Icons.my_location, color: Colors.cyan, size:18),
      ])));
  }

  Widget _buildRegularityTab(BuildContext context, SeismicAnalysisReport report) {
    final verticalAvailable = report.storeyChecks.every((s) => s.verticalOrderValid);
    final hasRatios = report.storeyChecks.any((s) => s.stiffnessRatioXToAbove != null || s.stiffnessRatioYToAbove != null);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!verticalAvailable)
            Padding(padding: const EdgeInsets.all(12), child: Text(context.l10n.seismicElevationAmbiguous,
              style: const TextStyle(color: Colors.amber))),
          // 1. Floating Columns Warning Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !verticalAvailable ? Colors.amber : report.totalFloatingColumnsCount > 0
                    ? const Color(0xFFD500F9)
                    : const Color(0xFF00E676),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.vertical_align_bottom_rounded,
                      color: !verticalAvailable ? Colors.amber : report.totalFloatingColumnsCount > 0
                          ? const Color(0xFFD500F9)
                          : const Color(0xFF00E676),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.seismicFloatingColumnsTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (report.totalFloatingColumnsCount > 0
                                ? const Color(0xFFD500F9)
                                : const Color(0xFF00E676))
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.seismicCountFound(report.totalFloatingColumnsCount),
                        style: TextStyle(
                          color: !verticalAvailable ? Colors.amber : report.totalFloatingColumnsCount > 0
                              ? const Color(0xFFEA80FC)
                              : const Color(0xFF00E676),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!verticalAvailable)
                  Text(context.l10n.seismicNotEvaluated, style: const TextStyle(color: Colors.amber))
                else if (report.totalFloatingColumnsCount == 0)
                  Text(
                    context.l10n.seismicNoFloatingColumnsText,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  )
                else ...[
                  Text(
                    context.l10n.seismicCriticalEc8FloatingText,
                    style: const TextStyle(
                        color: Color(0xFFEA80FC),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  for (final s in report.storeyChecks)
                    for (var i=0;i<s.floatingColumnIds.length;i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _elementLink(s.storeyId, s.floatingColumnIds[i], false,
                          context.l10n.seismicFloatingColItem(s.storeyName, s.floatingColumnNames[i]), Colors.white),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Soft Storey Check Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.l10n.seismicWallContinuityTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(context.l10n.seismicWallContinuityScope,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
              if (!report.storeyChecks.any((s) => s.wallVerticalChecks.isNotEmpty))
                Text(context.l10n.seismicNotEvaluated,
                  style: const TextStyle(color: Colors.amber, fontSize: 11)),
              for (final storey in report.storeyChecks)
                for (final wall in storey.wallVerticalChecks)
                  Padding(padding: const EdgeInsets.only(top: 6), child: _elementLink(storey.storeyId, wall.wallId, true,
                    context.l10n.seismicWallContinuityItem(storey.storeyName, wall.wallName,
                      wall.coverage == null ? context.l10n.seismicNotEvaluated
                        : '${(wall.coverage! * 100).toStringAsFixed(1)}%'),
                    wall.isContinuous ? Colors.white70 : Colors.amber)),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !hasRatios ? Colors.amber : report.hasSoftStorey
                    ? const Color(0xFFFF1744)
                    : const Color(0xFF00E676),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.layers_clear_rounded,
                      color: !hasRatios ? Colors.amber : report.hasSoftStorey
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00E676),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.seismicSoftStoreyTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      !hasRatios ? context.l10n.seismicNotEvaluated : report.hasSoftStorey ? context.l10n.seismicDanger : context.l10n.seismicNone,
                      style: TextStyle(
                        color: !hasRatios ? Colors.amber : report.hasSoftStorey
                            ? const Color(0xFFFF1744)
                            : const Color(0xFF00E676),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  !hasRatios ? context.l10n.seismicNotEvaluated : report.hasSoftStorey
                      ? context.l10n.seismicSoftStoreyDangerText
                      : context.l10n.seismicSoftStoreyOkText,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(context.l10n.seismicDirectionalScope, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                for (final s in report.storeyChecks)
                  if(s.stiffnessRatioXToAbove != null || s.stiffnessRatioYToAbove != null)
                    Text('${s.storeyName}: X ${s.stiffnessRatioXToAbove?.toStringAsFixed(2) ?? '—'} · Y ${s.stiffnessRatioYToAbove?.toStringAsFixed(2) ?? '—'}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 10),
                Text(context.l10n.seismicRegionTrackingTitle, style: const TextStyle(color: Colors.white, fontSize: 13)),
                for(final s in report.storeyChecks)
                  for(final link in s.regionLinksBelow)
                    Padding(padding: const EdgeInsets.only(top:6),child:Text(
                      context.l10n.seismicRegionTrackingItem(s.storeyName, link.upperRegion+1,
                        link.lowerStoreyName, link.lowerRegions.map((i)=>i+1).join(', '),
                        link.coverage==null?'—':'${(link.coverage!*100).toStringAsFixed(1)}%',
                        switch(link.kind) {
                          RegionLinkKind.oneToOne => context.l10n.seismicLinkUnique,
                          RegionLinkKind.branching => context.l10n.seismicLinkBranching,
                          RegionLinkKind.unmatched => context.l10n.seismicLinkAbsent,
                          RegionLinkKind.unknown => context.l10n.seismicNotEvaluated,
                        }),style: const TextStyle(color:Colors.white70,fontSize:11))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeamsAndOpeningsTab(BuildContext context, SeismicAnalysisReport report) {
    if (report.beamChecks.isEmpty && report.openingChecks.isEmpty) {
      return Center(
        child: Text(
          context.l10n.seismicNoBeamsOrOpenings,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        if (report.beamChecks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              context.l10n.seismicBeamSizingTitle,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          for (final b in report.beamChecks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: b.isDepthSufficient ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${b.beamName} (${b.storeyName})',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(context.l10n.seismicSpanM(b.spanM.toStringAsFixed(2)),
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(b.localizedRecommendation(context.l10n), style: TextStyle(
                    color: b.isDepthSufficient ? Colors.white70 : const Color(0xFFFFD54F),
                    fontSize: 11,
                  )),
                ],
              ),
            ),
        ],

        if (report.openingChecks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              context.l10n.seismicOpeningsProximityTitle,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          for (final op in report.openingChecks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !op.distanceToSupportM.isFinite ? const Color(0xFFFFB300) : op.isTooClose ? const Color(0xFFFF1744) : Colors.white38,
                ),
              ),
              child: Text(op.localizedRecommendation(context.l10n), style: TextStyle(
                color: op.isTooClose ? const Color(0xFFFF8A80) : Colors.white70,
                fontSize: 11,
              )),
            ),
        ],
      ],
    );
  }

  Widget _buildRatioRow({
    required String label,
    required String valueText,
    required double ratio,
    required Color color,
  }) {
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
                  valueText,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildSubmetric(String title, String value) {
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
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
