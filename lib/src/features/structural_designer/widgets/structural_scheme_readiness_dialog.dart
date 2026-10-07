import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/structural_scheme_readiness.dart';
import '../models/structural_element.dart';

class StructuralSchemeReadinessDialog extends StatelessWidget {
  final StructuralProject project;
  final double scale;
  final bool editing;
  const StructuralSchemeReadinessDialog({
    super.key,
    required this.project,
    required this.scale,
    this.editing = false,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final result = StructuralSchemeReadiness.evaluate(
      project,
      scale,
      editing: editing,
    );
    String message(SchemeReadinessIssue issue) => switch (issue) {
      SchemeReadinessIssue.editing => l.schemeEditing,
      SchemeReadinessIssue.missingSlab => l.openingNoSlab,
      SchemeReadinessIssue.missingStaircase => l.schemeMissingStairs,
      SchemeReadinessIssue.ambiguousLevels => l.schemeAmbiguousLevels,
      SchemeReadinessIssue.invalidSlabLevel => l.schemeInvalidLevel,
      SchemeReadinessIssue.invalidGeometry => l.schemeInvalidGeometry,
      SchemeReadinessIssue.overlappingSlabs => l.schemeOverlappingSlabs,
      SchemeReadinessIssue.computationLimit => l.schemeComputationLimit,
    };
    return AlertDialog(
      title: Text(l.schemeReadinessTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.geometryReady) Text(l.schemeGeometryReady),
              for (final issue in result.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message(issue)),
                ),
              const SizedBox(height: 8),
              Text('${l.schemeRegionsLabel}: ${result.regionCount}'),
              for (final ref in result.openings.where(
                (r) =>
                    r.type == SlabOpeningType.staircase ||
                    r.type == SlabOpeningType.elevator,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${ref.type == SlabOpeningType.staircase ? l.openingStaircaseTitle : l.openingElevatorTitle}\n'
                    '${l.schemeCeilingLabel} ${project.activeStorey.slabs.indexWhere((s) => s.id == ref.slabId) + 1} · '
                    '${l.ceilingSlabLevels(ref.concreteTop.toStringAsFixed(3), ref.concreteSoffit.toStringAsFixed(3))}',
                  ),
                ),
              const Divider(),
              Text(
                l.schemeReadinessHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}
