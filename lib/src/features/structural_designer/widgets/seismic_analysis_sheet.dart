import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/seismic_analysis_models.dart';

/// Modal bottom sheet presenting a comprehensive Eurocode 8 (EC8) seismic analysis report
/// covering Center of Mass vs Rigidity, torsional balance, shear wall coverage ratios,
/// vertical regularity (floating/transfer columns), soft storeys, and beam sizing.
class SeismicAnalysisSheet extends StatefulWidget {
  final SeismicAnalysisReport report;

  const SeismicAnalysisSheet({super.key, required this.report});

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

            // Summary Metrics Cards
            Row(
              children: [
                _buildStatCard(
                  title: 'Макс. ексцентр.',
                  value: '${(report.maxEccentricityRatio * 100).round()}%',
                  color: report.hasTorsionalSensitivity
                      ? const Color(0xFFFF1744)
                      : (report.maxEccentricityRatio > 0.08
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF00E676)),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: 'Усукване',
                  value: report.hasTorsionalSensitivity ? 'ВИСОКО' : 'В норма',
                  color: report.hasTorsionalSensitivity
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF00E676),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: 'Насадени колони',
                  value: '${report.totalFloatingColumnsCount}',
                  color: report.totalFloatingColumnsCount > 0
                      ? const Color(0xFFD500F9)
                      : const Color(0xFF00E676),
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  title: 'Шайби (EC8)',
                  value: report.hasWallDeficit ? 'ДЕФИЦИТ' : 'ОК >=1%',
                  color: report.hasWallDeficit
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF00E676),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD500F9),
              labelColor: const Color(0xFFD500F9),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.track_changes_rounded, size: 15),
                      SizedBox(width: 4),
                      Text('Баланс (CM/CR)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.line_weight_rounded, size: 15),
                      SizedBox(width: 4),
                      Text('Шайби (%)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vertical_align_bottom_rounded, size: 15),
                      SizedBox(width: 4),
                      Text('Регулярност'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.horizontal_rule_rounded, size: 15),
                      SizedBox(width: 4),
                      Text('Греди/Отвори'),
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

  Widget _buildTorsionalTab(BuildContext context, SeismicAnalysisReport report) {
    if (report.storeyChecks.isEmpty) {
      return const Center(
        child: Text('Няма данни за етажи в проекта.',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: report.storeyChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final check = report.storeyChecks[idx];
        final isSensitive = check.isTorsionallySensitive;
        final color = isSensitive ? const Color(0xFFFF1744) : (check.maxEccentricityRatio > 0.08 ? const Color(0xFFFFB300) : const Color(0xFF00E676));

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
                      '${check.storeyName} — Сеизмичен ексцентрицитет',
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
                      isSensitive ? 'Усуквателно чувствителна' : 'Балансирана',
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

              // Detailed metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubmetric('Ексцентрицитет X (ex)', '${check.eccentricityM.dx.toStringAsFixed(2)} m (${(check.eccentricityRatioX * 100).round()}%)'),
                  _buildSubmetric('Ексцентрицитет Y (ey)', '${check.eccentricityM.dy.toStringAsFixed(2)} m (${(check.eccentricityRatioY * 100).round()}%)'),
                  _buildSubmetric('Лимит по EC8', '≤ 15%'),
                ],
              ),
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
                        check.architectRecommendation,
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
      return const Center(
        child: Text('Няма данни за етажи в проекта.',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: report.storeyChecks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final check = report.storeyChecks[idx];
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
                      '${check.storeyName} — Покритие със земетръсни шайби',
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
                      (okX && okY) ? 'ОК (≥ 1.0%)' : 'ДЕФИЦИТ (< 1.0%)',
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
                label: 'Покритие по X (ρ_wx):',
                valueText: '${check.wallRatioX.toStringAsFixed(2)}% (${check.wallAreaXM2.toStringAsFixed(1)} m²)',
                ratio: check.wallRatioX / 1.5,
                color: okX ? const Color(0xFF00E676) : const Color(0xFFFFB300),
              ),
              const SizedBox(height: 6),

              // Coverage Bar Y
              _buildRatioRow(
                label: 'Покритие по Y (ρ_wy):',
                valueText: '${check.wallRatioY.toStringAsFixed(2)}% (${check.wallAreaYM2.toStringAsFixed(1)} m²)',
                ratio: check.wallRatioY / 1.5,
                color: okY ? const Color(0xFF00E676) : const Color(0xFFFFB300),
              ),
              const SizedBox(height: 8),

              Text(
                'Препоръка по Eurocode 8 за България: минимум 1.0% - 1.5% шайби във всяко от двете направления спрямо етажна площ (${check.floorAreaM2.toStringAsFixed(0)} m²).',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegularityTab(BuildContext context, SeismicAnalysisReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Floating Columns Warning Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: report.totalFloatingColumnsCount > 0
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
                      color: report.totalFloatingColumnsCount > 0
                          ? const Color(0xFFD500F9)
                          : const Color(0xFF00E676),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Насадени колони (Floating / Transfer Columns)',
                        style: TextStyle(
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
                        '${report.totalFloatingColumnsCount} открити',
                        style: TextStyle(
                          color: report.totalFloatingColumnsCount > 0
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
                if (report.totalFloatingColumnsCount == 0)
                  const Text(
                    'Няма насадени колони. Всички колони по височината стъпват надеждно върху вертикални опори на долните етажи.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  )
                else ...[
                  const Text(
                    'КРИТИЧНО ЗА ЗЕМЕТРЪС (EC8 §4.2.3.3): Насадените колони предават целия си сеизмичен и вертикален товар точково върху плочата!',
                    style: TextStyle(
                        color: Color(0xFFEA80FC),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  for (final s in report.storeyChecks)
                    if (s.floatingColumnNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${s.storeyName}: Колони ${s.floatingColumnNames.join(", ")} са насадени без колона отдолу.',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Soft Storey Check Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: report.hasSoftStorey
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
                      color: report.hasSoftStorey
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00E676),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Проверка за Мек етаж (Soft Storey)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      report.hasSoftStorey ? 'ОПАСНОСТ' : 'НЯМА',
                      style: TextStyle(
                        color: report.hasSoftStorey
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
                  report.hasSoftStorey
                      ? 'Установена е рязка загуба на коравина (> 30%) между съседни етажи. Това създава предпоставка за етажен механизъм на разрушение при земетръс.'
                      : 'Коравината между етажите се изменя плавно по височина (без меки етажи).',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeamsAndOpeningsTab(BuildContext context, SeismicAnalysisReport report) {
    if (report.beamChecks.isEmpty && report.openingChecks.isEmpty) {
      return const Center(
        child: Text(
          'Няма дефинирани греди или отвори в плочите.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        if (report.beamChecks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Предварително оразмеряване на греди (h = L/10 - L/12):',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                      Text('Отвор L = ${b.spanM.toStringAsFixed(2)} m',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(b.recommendation, style: TextStyle(
                    color: b.isDepthSufficient ? Colors.white70 : const Color(0xFFFFD54F),
                    fontSize: 11,
                  )),
                ],
              ),
            ),
        ],

        if (report.openingChecks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              'Инсталационни отвори близо до опори (< 4d):',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                  color: op.isTooClose ? const Color(0xFFFF1744) : const Color(0xFF00E676),
                ),
              ),
              child: Text(op.recommendation, style: TextStyle(
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
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(
              valueText,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
