import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/element_check_models.dart';
import '../models/structural_element.dart';
import 'element_check_panel.dart';

// === SECTION: INDEX ===
// === SECTION: SUMMARY SHEET ===
// === SECTION: STAT CARD ===

// === SECTION: SUMMARY SHEET ===

/// Mobile-first summary sheet for the whole building preliminary check:
/// columns, shear walls, slabs, torsion/drift, seismic base shear, and quick
/// jump to elements needing attention.
class BuildingCheckSummarySheet extends StatelessWidget {
  final StructuralProject project;
  final PreliminaryCheckReport report;
  final bool isRunning;
  final bool isStale;
  final VoidCallback onRunFullCheck;
  final VoidCallback onEditParameters;
  final void Function(String storeyId, String elementId, bool isWall)?
  onLocateElement;

  const BuildingCheckSummarySheet({
    super.key,
    required this.project,
    required this.report,
    required this.isRunning,
    required this.isStale,
    required this.onRunFullCheck,
    required this.onEditParameters,
    this.onLocateElement,
  });

  double _maxUtilization(Iterable<double> values) {
    var worst = double.nan;
    for (final v in values) {
      if (!v.isFinite) continue;
      if (!worst.isFinite || v > worst) worst = v;
    }
    return worst;
  }

  String _elementName(ElementUtilization e) {
    for (final s in project.storeys) {
      if (s.id != e.storeyId) continue;
      if (e.type == CheckedElementType.column) {
        for (final c in s.columns) {
          if (c.id == e.elementId) return '${c.displayName} · ${s.name}';
        }
      } else {
        for (final w in s.shearWalls) {
          if (w.id == e.elementId) return '${w.displayName} · ${s.name}';
        }
      }
    }
    return e.elementId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seismic = report.seismic;

    final colMax = _maxUtilization(
      report.elements.values
          .where((e) => e.type == CheckedElementType.column)
          .map((e) => e.utilization),
    );
    final wallMax = _maxUtilization(
      report.elements.values
          .where((e) => e.type == CheckedElementType.wall)
          .map((e) => e.utilization),
    );
    final slabMax = report.unsupported.isNotEmpty
        ? 9.99
        : _maxUtilization(report.slabs.map((s) => s.governing.utilization));
    final torsionMax = seismic == null
        ? double.nan
        : _maxUtilization(
            seismic.storeys.map((s) => s.torsion.governingRatio),
          );

    final attention = report.elements.values
        .where(
          (e) =>
              e.level == UtilizationLevel.over ||
              e.level == UtilizationLevel.near,
        )
        .toList()
      ..sort((a, b) => b.utilization.compareTo(a.utilization));

    final hasEccIssue = seismic?.storeys.any(
          (s) => s.torsion.hasHighEccentricity,
        ) ??
        false;
    final hasFlexIssue = seismic?.storeys.any(
          (s) => s.torsion.isTorsionallyFlexible,
        ) ??
        false;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1E24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.84,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Header row: title + mesh badge + design data shortcut.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.checkBuildingTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (report.durationMs > 0 || isRunning)
                          Text(
                            isRunning
                                ? l10n.checkRunning
                                : report.isFullCheck
                                    ? l10n.checkFullDoneBadge(report.durationMs)
                                    : l10n.checkLiveDoneBadge(report.durationMs),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onEditParameters,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(l10n.designParamsAction),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 4 compact stat cards (Expanded + FittedBox prevents overflow on 320px).
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: l10n.checkSummaryColumns,
                      utilization: colMax,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StatCard(
                      label: l10n.checkSummaryWalls,
                      utilization: wallMax,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StatCard(
                      label: l10n.checkSummarySlabs,
                      utilization: slabMax,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _StatCard(
                      label: l10n.checkSummaryTorsion,
                      utilization: torsionMax,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Action button: run fine 0.25m full check.
              FilledButton.icon(
                onPressed: isRunning ? null : onRunFullCheck,
                icon: isRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(
                  isRunning ? l10n.checkRunning : l10n.checkRunFullButton,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seismic status banner
                      if (seismic == null || !seismic.isConfigured)
                        _banner(
                          color: const Color(0xFF90A4AE),
                          icon: Icons.waves_rounded,
                          text: l10n.checkSummarySeismicUnset,
                          onTap: onEditParameters,
                        )
                      else ...[
                        _banner(
                          color: const Color(0xFF00E5FF),
                          icon: Icons.waves_rounded,
                          text: l10n.checkSummaryBaseShear(
                            math.max(
                              seismic.baseShear1Kn.isFinite
                                  ? seismic.baseShear1Kn
                                  : 0,
                              seismic.baseShear2Kn.isFinite
                                  ? seismic.baseShear2Kn
                                  : 0,
                            ).toStringAsFixed(0),
                            math.max(
                              seismic.period1S.isFinite ? seismic.period1S : 0,
                              seismic.period2S.isFinite ? seismic.period2S : 0,
                            ).toStringAsFixed(2),
                            seismic.totalMassTonnes.toStringAsFixed(0),
                          ),
                        ),
                        if (seismic.requires3dAnalysis) ...[
                          const SizedBox(height: 6),
                          _banner(
                            color: const Color(0xFFFFB74D),
                            icon: Icons.warning_amber_rounded,
                            text: l10n.checkNeeds3dWarning,
                          ),
                        ],
                      ],
                      if (hasFlexIssue) ...[
                        const SizedBox(height: 6),
                        _banner(
                          color: const Color(0xFFFFB74D),
                          icon: Icons.rotate_right_rounded,
                          text: l10n.checkTorsionAdviceFlex,
                        ),
                      ],
                      if (hasEccIssue) ...[
                        const SizedBox(height: 6),
                        _banner(
                          color: const Color(0xFFFFB74D),
                          icon: Icons.center_focus_weak_rounded,
                          text: l10n.checkTorsionAdviceEcc,
                        ),
                      ],
                      if (report.unsupported.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _banner(
                          color: UtilizationLevel.over.color,
                          icon: Icons.error_outline_rounded,
                          text: l10n.checkUnsupportedHint,
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (report.elements.isEmpty && report.slabs.isEmpty)
                        Text(
                          l10n.checkSummaryNoElements,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        )
                      else if (attention.isEmpty &&
                          report.unsupported.isEmpty &&
                          (!slabMax.isFinite ||
                              slabMax <= UtilizationLevel.nearThreshold))
                        Text(
                          l10n.checkSummaryAllOk,
                          style: TextStyle(
                            color: UtilizationLevel.ok.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
                        Text(
                          l10n.checkSummaryAttentionList,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final e in attention.take(12)) ...[
                          _attentionTile(context, l10n, e),
                          const SizedBox(height: 6),
                        ],
                      ],
                      const Divider(color: Colors.white12, height: 18),
                      Text(
                        l10n.checkPreliminary,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _attentionTile(
    BuildContext context,
    AppLocalizations l10n,
    ElementUtilization e,
  ) {
    final g = e.governing;
    final color = e.level.color;
    return InkWell(
      onTap: onLocateElement == null
          ? () => showElementCheckDetails(context, e)
          : () => onLocateElement!(
              e.storeyId,
              e.elementId,
              e.type == CheckedElementType.wall,
            ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF262932),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _elementName(e),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (g != null)
                    Text(
                      '${checkKindName(l10n, g.kind)} · ${checkDemandCapacityText(g)}',
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
            const SizedBox(width: 8),
            Text(
              utilizationText(e.utilization),
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === SECTION: STAT CARD ===

class _StatCard extends StatelessWidget {
  final String label;
  final double utilization;

  const _StatCard({required this.label, required this.utilization});

  @override
  Widget build(BuildContext context) {
    final level = UtilizationLevel.of(utilization);
    final color = level.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              utilizationText(utilization),
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
