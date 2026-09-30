import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cantilever_analysis_models.dart';

/// Engineering engine for calculating cantilever deflections and slenderness
/// according to EN 1992-1-1 (Eurocode 2) and structural mechanics.
class DeflectionCalculator {
  const DeflectionCalculator._();

  /// Concrete unit weight in kN/m³
  static const double gammaConcrete = 25.0;

  /// Quasi-permanent combination coefficient for live load (Eurocode 0 Table A1.1, Category A - Domestic/Residential)
  static const double psi2 = 0.3;

  /// Concrete long-term creep coefficient (phi_infinity for typical indoor/semi-outdoor RH 70%)
  static const double creepPhi = 2.5;

  /// Cracking reduction factor for gross moment of inertia in serviceability limit state (EC2 SLS)
  static const double crackedInertiaFactor = 0.5;

  /// Computes the cantilever check for a single or corner cantilever.
  static CantileverZone evaluateCantilever({
    required String id,
    required CantileverType type,
    required String storeyName,
    required Offset supportEdgeStart,
    required Offset supportEdgeEnd,
    required Offset overhangTip,
    required double length, // Lx (m)
    double? lengthY, // Ly (m) for corner
    required double slabThickness, // h (m)
    double concreteE = 31000.0, // MPa (N/mm² or 31,000,000 kN/m²)
    double superimposedDeadLoad = 1.5, // kN/m²
    double liveLoad = 2.0, // kN/m²
    double facadeLoad = 3.5, // kN/m
    double? stackedColumnLoadKn,
    String? stackedColumnId,
  }) {
    // 1. Self weight of reinforced concrete slab
    final double g0 = gammaConcrete * slabThickness; // kN/m²
    final double totalDead = g0 + superimposedDeadLoad; // kN/m²

    // Quasi-permanent combination load (SLS deflections)
    final double qQp = totalDead + (psi2 * liveLoad); // kN/m²

    // 2. Cross section properties for 1.0 m wide slab strip
    const double b = 1.0; // m
    final double iGross = (b * math.pow(slabThickness, 3)) / 12.0; // m⁴
    final double iEff = iGross * crackedInertiaFactor; // m⁴

    // Concrete E in kN/m²
    final double eKnM2 = concreteE * 1000.0;

    // 3. Elastic deflection calculations (meters)
    double fElM = 0.0;
    double effectiveL = length;
    double slenderness = length / slabThickness;

    if (type == CantileverType.cornerBiaxial && lengthY != null && lengthY > 0) {
      // Corner biaxial cantilever:
      // Effective diagonal cantilever reach
      final double lDiag = math.sqrt(length * length + lengthY * lengthY);
      effectiveL = lDiag;
      slenderness = lDiag / slabThickness;

      // In a corner plate, torsional coupling increases deflection
      // Timoshenko / EC2 corner plate superposition:
      final double fX = (qQp * math.pow(length, 4)) / (8.0 * eKnM2 * iEff) +
          (facadeLoad * math.pow(length, 3)) / (3.0 * eKnM2 * iEff);
      final double fY = (qQp * math.pow(lengthY, 4)) / (8.0 * eKnM2 * iEff) +
          (facadeLoad * math.pow(lengthY, 3)) / (3.0 * eKnM2 * iEff);

      // Superposition with diagonal twisting coupling
      fElM = (fX + fY) * 1.15;
    } else {
      // Linear 1-way cantilever:
      // Distributed load deflection: q * L^4 / (8 * E * I)
      final double fDist = (qQp * math.pow(length, 4)) / (8.0 * eKnM2 * iEff);
      // Perimeter facade wall line load: P * L^3 / (3 * E * I)
      final double fPoint = (facadeLoad * math.pow(length, 3)) / (3.0 * eKnM2 * iEff);
      fElM = fDist + fPoint;
    }

    // Additional concentrated point load from upper floor column if transfer cantilever
    if (stackedColumnLoadKn != null && stackedColumnLoadKn > 0) {
      final double fColumn =
          (stackedColumnLoadKn * math.pow(length, 3)) / (3.0 * eKnM2 * iEff);
      fElM += fColumn;
    }

    // 4. Long-term total deflection including creep: f_tot = (1 + phi) * f_el
    final double fTotM = fElM * (1.0 + creepPhi);

    // Convert deflections to millimeters
    final double fElMm = fElM * 1000.0;
    final double fTotMm = fTotM * 1000.0;

    // 5. Code deflection limit: EN 1992-1-1 SLS Table 7.4N (L / 250 for cantilever tip)
    final double fLimMm = (effectiveL * 1000.0) / 250.0;

    // 6. Risk Level & Engineering Recommendations
    CantileverRiskLevel risk;
    final List<String> recs = [];

    final bool isTransfer = type == CantileverType.transferStacked;
    final bool isCorner = type == CantileverType.cornerBiaxial;

    if (isTransfer) {
      risk = CantileverRiskLevel.critical;
      recs.add('КРИТИЧНО: Засадена колона върху еркер!');
      recs.add('Задължително предвидете носеща конзолна стоманобетонна греда или ферма.');
      recs.add('Проверете плочата за срязване и пробиване (punching shear).');
    } else if (slenderness > 10.0 || fTotMm > fLimMm * 1.1) {
      risk = CantileverRiskLevel.critical;
      recs.add('Критично надвисване (L/h = ${slenderness.toStringAsFixed(1)} > 10)!');
      recs.add('Очаквано провисване ${fTotMm.toStringAsFixed(1)} mm надхвърля допустимото ${fLimMm.toStringAsFixed(1)} mm.');
      recs.add('Увеличете дебелината на плочата от ${(slabThickness * 100).toInt()} cm на минимум ${(effectiveL / 7.0 * 100).ceil()} cm.');
      if (isCorner) {
        recs.add('В ъгъла се препоръчва скрита диагонална стоманобетонна греда.');
      }
    } else if (slenderness > 7.0 || fTotMm > fLimMm * 0.85) {
      risk = CantileverRiskLevel.warning;
      recs.add('Повишено конзолно съотношение (L/h = ${slenderness.toStringAsFixed(1)}).');
      recs.add('Изисква се горна армировка с повишен диаметър срещу пукнатини по горната повърхност.');
      if (isCorner) {
        recs.add('Двойният ъглов еркер изисква кръстосана диагонална горна армировка.');
      }
    } else {
      risk = CantileverRiskLevel.safe;
      recs.add('Размерите и провисването са в рамките на нормативните граници (EC2).');
    }

    return CantileverZone(
      id: id,
      type: type,
      storeyName: storeyName,
      supportEdgeStart: supportEdgeStart,
      supportEdgeEnd: supportEdgeEnd,
      overhangTip: overhangTip,
      length: length,
      lengthY: lengthY,
      effectiveDiagonal: type == CantileverType.cornerBiaxial
          ? math.sqrt(length * length + (lengthY ?? 0.0) * (lengthY ?? 0.0))
          : null,
      slabThickness: slabThickness,
      slendernessRatio: slenderness,
      elasticDeflectionMm: fElMm,
      longTermDeflectionMm: fTotMm,
      limitDeflectionMm: fLimMm,
      riskLevel: risk,
      recommendations: recs,
      stackedColumnId: stackedColumnId,
    );
  }
}
