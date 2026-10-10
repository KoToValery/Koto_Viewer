import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/support_layout_evaluator.dart';

/// Shared presentation for manual inspection and automatic placement.
class LayoutAssessmentSummary extends StatelessWidget {
  final SupportLayoutAssessment assessment;
  final SupportLayoutAssessment? before;
  const LayoutAssessmentSummary({
    super.key,
    required this.assessment,
    this.before,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, a = assessment;
    final fields = [...a.topology.fields]
      ..sort((a, b) => b.utilization.compareTo(a.utilization));
    String change(num current, num? old, {int decimals = 0}) => old == null
        ? current.toStringAsFixed(decimals)
        : '${old.toStringAsFixed(decimals)} → ${current.toStringAsFixed(decimals)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (before != null)
          Text(
            l.schemeComparison,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        Text(
          l.schemeFieldSummary(a.topology.fields.length, a.problematicFields),
        ),
        Text(
          '${l.schemeUnresolvedFieldArea}: ${change(a.topology.unresolvedAreaM2, before?.topology.unresolvedAreaM2, decimals: 2)} m²',
        ),
        for (final f in fields.take(3))
          Text(
            '${f.lxM.toStringAsFixed(2)} × ${f.lyM.toStringAsFixed(2)} m · h ${f.thicknessM.isFinite ? (f.thicknessM * 100).round() : '—'} cm',
          ),
        Text(
          '${l.schemeOpeningSupportReview}: ${change(a.openingReviews, before?.openingReviews)}',
        ),
        Text(
          '${l.schemeBoundarySupportReview}: ${change(a.boundaryReviews, before?.boundaryReviews)}',
        ),
        Text(
          '${l.schemeContinuityIssues}: ${change(a.continuityIssues, before?.continuityIssues)}',
        ),
        Text(
          '${l.columns} + W: ${change(a.supportCount, before?.supportCount)}',
        ),
        Text(
          '${l.schemeConcreteVolume}: ${change(a.concreteVolumeM3, before?.concreteVolumeM3, decimals: 2)} m³',
        ),
        if (a.balanceAvailable)
          Text(
            '${l.schemeBalanceIndex}: ${change(a.balancePenalty, before?.balancePenalty, decimals: 3)}',
          ),
        if (a.unavailableChecks > 0)
          Text(
            '${l.schemeUnavailableChecks}: ${change(a.unavailableChecks, before?.unavailableChecks)}',
          ),
      ],
    );
  }
}
