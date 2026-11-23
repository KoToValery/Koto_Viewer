import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/member_checks.dart';
import '../analysis/seismic_elf_calculator.dart';
import '../models/element_check_models.dart';

// === SECTION: INDEX ===
// === SECTION: LABELS ===
// === SECTION: CHIPS ROW ===
// === SECTION: DETAILS SHEET ===

// === SECTION: LABELS ===

String checkKindName(AppLocalizations l10n, CheckKind kind) => switch (kind) {
  CheckKind.columnAxial || CheckKind.wallAxial => l10n.checkNameColumnAxial,
  CheckKind.columnSeismicAxial ||
  CheckKind.wallSeismicAxial => l10n.checkNameSeismicAxial,
  CheckKind.wallSeismicShear => l10n.checkNameWallShear,
  CheckKind.storeyDrift => l10n.checkNameStoreyDrift,
  CheckKind.storeyTorsion => l10n.checkNameStoreyTorsion,
  CheckKind.punching => l10n.checkNamePunching,
  CheckKind.slabDeflection => l10n.checkNameSlabDeflection,
  CheckKind.slabBending => l10n.checkNameSlabBending,
};

String checkLevelName(AppLocalizations l10n, UtilizationLevel level) =>
    switch (level) {
      UtilizationLevel.ok => l10n.checkLevelOk,
      UtilizationLevel.near => l10n.checkLevelNear,
      UtilizationLevel.over => l10n.checkLevelOver,
      UtilizationLevel.unknown => l10n.checkLevelUnknown,
    };

/// "212 / 480 kN": numbers with unit symbols, not translatable words.
String checkDemandCapacityText(ElementCheck c) {
  if (!c.isDetermined) return '—';
  String n(double v, int digits) => v.toStringAsFixed(digits);
  return switch (c.kind) {
    CheckKind.columnAxial ||
    CheckKind.wallAxial ||
    CheckKind.wallSeismicShear => '${n(c.demand, 0)} / ${n(c.capacity, 0)} kN',
    CheckKind.columnSeismicAxial ||
    CheckKind.wallSeismicAxial => 'ν_d ${n(c.demand, 2)} / ${n(c.capacity, 2)}',
    CheckKind.storeyDrift => '${n(c.demand, 1)} / ${n(c.capacity, 1)} mm',
    CheckKind.storeyTorsion => '${n(c.demand, 2)} / ${n(c.capacity, 2)}',
    CheckKind.punching => '${n(c.demand, 2)} / ${n(c.capacity, 2)} MPa',
    CheckKind.slabDeflection => '${n(c.demand, 1)} / ${n(c.capacity, 1)} mm',
    CheckKind.slabBending => '${n(c.demand, 1)} / ${n(c.capacity, 1)} kNm/m',
  };
}

String checkAssumptionText(AppLocalizations l10n, CheckKind kind) {
  String pct(double v) => (v * 100).toStringAsFixed(v * 100 % 1 == 0 ? 0 : 1);
  return switch (kind) {
    CheckKind.columnAxial || CheckKind.columnSeismicAxial =>
      l10n.checkAssumptionColumn(
        pct(CheckAssumptions.columnSteelRatio),
        CheckAssumptions.columnNuLimit.toStringAsFixed(2),
      ),
    CheckKind.wallAxial || CheckKind.wallSeismicAxial =>
      l10n.checkAssumptionWall(
        pct(CheckAssumptions.wallSteelRatio),
        CheckAssumptions.wallNuLimit.toStringAsFixed(2),
      ),
    CheckKind.wallSeismicShear => l10n.checkAssumptionWallShear(
      SeismicElfAssumptions.dcmShearMagnification.toStringAsFixed(1),
      pct(SeismicElfAssumptions.wallHorizontalSteelRatio),
    ),
    CheckKind.storeyDrift => l10n.checkAssumptionDrift,
    CheckKind.storeyTorsion => l10n.checkAssumptionTorsion,
    CheckKind.punching => l10n.checkAssumptionPunching(
      pct(CheckAssumptions.slabTopSteelRatio),
    ),
    CheckKind.slabDeflection => l10n.checkAssumptionDeflection(
      CheckAssumptions.longTermDeflectionFactor.toStringAsFixed(0),
      CheckAssumptions.deflectionSpanRatio.toStringAsFixed(0),
    ),
    CheckKind.slabBending => l10n.checkAssumptionBending(
      CheckAssumptions.momentSmoothingRadiusM.toStringAsFixed(1),
    ),
  };
}

// === SECTION: CHIPS ROW ===

/// Compact result strip for the contextual dock of a selected support.
class ElementCheckPanel extends StatelessWidget {
  final ElementUtilization? utilization;
  final bool stale;
  final bool running;
  const ElementCheckPanel({
    super.key,
    required this.utilization,
    this.stale = false,
    this.running = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = utilization;
    final checks = e?.checks.where((c) => c.isDetermined).toList() ?? const [];
    if (e == null || checks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          running ? l10n.checkRunning : l10n.checkNotAvailable,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showElementCheckDetails(context, e),
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: stale ? 0.5 : 1,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in checks) _chip(l10n, c)],
                ),
              ),
              const Icon(Icons.info_outline, size: 18, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(AppLocalizations l10n, ElementCheck c) {
    final color = c.level.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        '${checkKindName(l10n, c.kind)} ${utilizationText(c.utilization)}',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// === SECTION: DETAILS SHEET ===

Future<void> showElementCheckDetails(
  BuildContext context,
  ElementUtilization e,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFF1E1E24),
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (ctx) {
    final l10n = ctx.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          shrinkWrap: true,
          children: [
            Text(
              l10n.checkAxialTotal(e.axialUls.toStringAsFixed(0)),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (e.slabReactionUls > 1e-6)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  l10n.checkSlabReaction(e.slabReactionUls.toStringAsFixed(0)),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            for (final c in e.checks.where((c) => c.isDetermined)) ...[
              _DetailRow(check: c),
              const SizedBox(height: 10),
            ],
            const Divider(color: Colors.white12),
            Text(
              l10n.checkPreliminary,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  },
);

class _DetailRow extends StatelessWidget {
  final ElementCheck check;
  const _DetailRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = check.level.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                checkKindName(l10n, check.kind),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              utilizationText(check.utilization),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: check.utilization.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            color: color,
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${checkLevelName(l10n, check.level)} · ${checkDemandCapacityText(check)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          checkAssumptionText(l10n, check.kind),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
