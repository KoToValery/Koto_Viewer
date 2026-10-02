import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';

/// Eurocode 8 (EC8 EN 1998-1) Seismic Regularity, Torsion, and Layout Engine.
///
/// Computes:
/// 1. Storey Center of Mass (CM) and Center of Rigidity (CR)
/// 2. Seismic eccentricity (e_x, e_y) and torsional sensitivity
/// 3. Shear wall percentage coverage in X and Y (>= 1.0 - 1.5%)
/// 4. Vertical regularity: floating / transfer columns and discontinuous walls
/// 5. Soft storey stiffness drops (K_k < 0.70 K_{k+1})
/// 6. Preliminary beam sizing (h = L/10 - L/12)
/// 7. Slab openings near critical support zones (< 4d)
class SeismicAnalysisCalculator {
  const SeismicAnalysisCalculator._();

  /// Analyzes seismic concept and regularity for the entire project according to Eurocode 8.
  static SeismicAnalysisReport analyzeProject(
    StructuralProject project, {
    double cadUnitsPerMeter = 1.0,
  }) {
    if (project.storeys.isEmpty) {
      return SeismicAnalysisReport.empty;
    }

    final scale = cadUnitsPerMeter;
    final int numStoreys = project.storeys.length;

    final List<StoreySeismicCheck> storeyChecks = [];
    final List<BeamSizingCheck> beamChecks = [];
    final List<OpeningProximityCheck> openingChecks = [];

    int totalFloatingColsCount = 0;
    int totalDiscontinuousWallsCount = 0;
    bool anyTorsionalSensitivity = false;
    bool anySoftStorey = false;
    bool anyWallDeficit = false;
    double maxGlobalEccRatio = 0.0;

    final List<double> storeyStiffnessList = [];

    // 1. Analyze each storey
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final storey = project.storeys[sIdx];
      final double hM = math.max(2.4, storey.height);

      // Floor area & bounding dimensions
      double floorAreaM2 = 0.0;
      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;

      for (final slab in storey.slabs) {
        floorAreaM2 += slab.netArea / (scale * scale);
        for (final p in slab.polygon) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
      }

      // If no slabs or too small, derive footprint from columns and walls
      if (floorAreaM2 <= 1.0) {
        for (final col in storey.columns) {
          final p = col.center;
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        for (final wall in storey.shearWalls) {
          for (final p in [wall.start, wall.end]) {
            if (p.dx < minX) minX = p.dx;
            if (p.dx > maxX) maxX = p.dx;
            if (p.dy < minY) minY = p.dy;
            if (p.dy > maxY) maxY = p.dy;
          }
        }
        if (minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite) {
          final w = (maxX - minX) / scale;
          final h = (maxY - minY) / scale;
          floorAreaM2 = math.max(12.0, w * h);
        } else {
          minX = 0;
          maxX = 10 * scale;
          minY = 0;
          maxY = 10 * scale;
          floorAreaM2 = 100.0;
        }
      }

      final double dimXM = math.max(3.0, (maxX - minX) / scale);
      final double dimYM = math.max(3.0, (maxY - minY) / scale);

      // A. Calculate Center of Mass (CM)
      double totalMass = 0.0;
      double sumMassX = 0.0;
      double sumMassY = 0.0;

      // Slab mass
      for (final slab in storey.slabs) {
        final aM2 = slab.netArea / (scale * scale);
        final cCad = _computePolygonCentroid(slab.polygon);
        final slabMass = aM2 * (25.0 * slab.thickness + project.deadLoadSuperimposed + 0.3 * project.liveLoad);
        totalMass += slabMass;
        sumMassX += slabMass * cCad.dx;
        sumMassY += slabMass * cCad.dy;
      }

      // Columns mass
      for (final col in storey.columns) {
        final colAreaM2 = (col.width / scale) * (col.height / scale);
        final colMass = colAreaM2 * hM * 25.0;
        totalMass += colMass;
        sumMassX += colMass * col.center.dx;
        sumMassY += colMass * col.center.dy;
      }

      // Shear walls mass
      for (final wall in storey.shearWalls) {
        final wallLenM = (wall.end - wall.start).distance / scale;
        final wallMass = wallLenM * (wall.thickness / scale) * hM * 25.0;
        final mid = (wall.start + wall.end) / 2.0;
        totalMass += wallMass;
        sumMassX += wallMass * mid.dx;
        sumMassY += wallMass * mid.dy;
      }

      final Offset cmCad;
      if (totalMass > 0) {
        cmCad = Offset(sumMassX / totalMass, sumMassY / totalMass);
      } else {
        cmCad = Offset((minX + maxX) / 2.0, (minY + maxY) / 2.0);
      }

      // B. Calculate Center of Rigidity (CR) & Shear Wall Areas
      double sumKx = 0.0;
      double sumKy = 0.0;
      double sumKxY = 0.0;
      double sumKyX = 0.0;

      double totalWallAreaX = 0.0;
      double totalWallAreaY = 0.0;

      // Shear walls rigidity contribution
      for (final wall in storey.shearWalls) {
        final lenM = math.max(0.40, (wall.end - wall.start).distance / scale);
        final tM = math.max(0.15, wall.thickness / scale);
        final mid = (wall.start + wall.end) / 2.0;

        // Strong axis moment of inertia: t * L^3 / 12
        final iStrong = (tM * math.pow(lenM, 3)) / 12.0;
        final iWeak = (lenM * math.pow(tM, 3)) / 12.0;

        final delta = wall.end - wall.start;
        final angle = math.atan2(delta.dy, delta.dx);
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);

        // Lateral stiffness along building axes
        final kX = (iStrong * cosA * cosA + iWeak * sinA * sinA);
        final kY = (iStrong * sinA * sinA + iWeak * cosA * cosA);

        sumKx += kX;
        sumKy += kY;
        sumKxY += kX * mid.dy;
        sumKyX += kY * mid.dx;

        totalWallAreaX += lenM * tM * cosA.abs();
        totalWallAreaY += lenM * tM * sinA.abs();
      }

      // Columns rigidity contribution
      for (final col in storey.columns) {
        final wM = math.max(0.20, col.width / scale);
        final hColM = math.max(0.20, col.height / scale);
        final pos = col.center;

        // Bending inertia: kX resists X force (depth in X is wM)
        final double iX = (hColM * math.pow(wM, 3)) / 12.0;
        final double iY = (wM * math.pow(hColM, 3)) / 12.0;

        sumKx += iX;
        sumKy += iY;
        sumKxY += iX * pos.dy;
        sumKyX += iY * pos.dx;
      }

      final Offset crCad;
      if (sumKx > 1e-6 && sumKy > 1e-6) {
        // x_CR is determined by ky (resistance to Y displacement at X distance)
        // y_CR is determined by kx (resistance to X displacement at Y distance)
        crCad = Offset(sumKyX / sumKy, sumKxY / sumKx);
      } else {
        crCad = cmCad;
      }

      // Eccentricity vector in meters
      final double exM = (cmCad.dx - crCad.dx).abs() / scale;
      final double eyM = (cmCad.dy - crCad.dy).abs() / scale;
      final double eRatioX = exM / dimXM;
      final double eRatioY = eyM / dimYM;
      final bool isTorsionallySensitive = (eRatioX > 0.15) || (eRatioY > 0.15);
      if (isTorsionallySensitive) anyTorsionalSensitivity = true;
      if (eRatioX > maxGlobalEccRatio) maxGlobalEccRatio = eRatioX;
      if (eRatioY > maxGlobalEccRatio) maxGlobalEccRatio = eRatioY;

      // Shear wall ratios (%)
      final double wallRatioX = (totalWallAreaX / floorAreaM2) * 100.0;
      final double wallRatioY = (totalWallAreaY / floorAreaM2) * 100.0;
      final bool wallOkX = wallRatioX >= 1.0;
      final bool wallOkY = wallRatioY >= 1.0;
      if (!wallOkX || !wallOkY) anyWallDeficit = true;

      // C. Floating / Transfer Columns Detection (EC8 §4.2.3.3)
      final List<String> floatingIds = [];
      final List<String> floatingNames = [];

      if (sIdx > 0) {
        final lowerStorey = project.storeys[sIdx - 1];
        for (int cIdx = 0; cIdx < storey.columns.length; cIdx++) {
          final col = storey.columns[cIdx];
          final cPos = col.center;
          bool hasSupportBelow = false;

          // Check if supported by lower column
          for (final lowerCol in lowerStorey.columns) {
            final dist = (lowerCol.center - cPos).distance / scale;
            if (dist <= 0.25) {
              hasSupportBelow = true;
              break;
            }
          }

          // Check if supported by lower shear wall
          if (!hasSupportBelow) {
            for (final lowerWall in lowerStorey.shearWalls) {
              final dist = _distancePointToSegment(cPos, lowerWall.start, lowerWall.end) / scale;
              if (dist <= 0.20) {
                hasSupportBelow = true;
                break;
              }
            }
          }

          if (!hasSupportBelow) {
            floatingIds.add(col.id);
            floatingNames.add('C${cIdx + 1}');
            totalFloatingColsCount++;
          }
        }
      }

      // D. Discontinuous Shear Walls Detection
      final List<String> discWallIds = [];
      if (sIdx > 0) {
        final lowerStorey = project.storeys[sIdx - 1];
        for (final wall in storey.shearWalls) {
          final mid = (wall.start + wall.end) / 2.0;
          bool hasWallBelow = false;
          for (final lowerWall in lowerStorey.shearWalls) {
            final dist = _distancePointToSegment(mid, lowerWall.start, lowerWall.end) / scale;
            if (dist <= 0.30) {
              hasWallBelow = true;
              break;
            }
          }
          if (!hasWallBelow) {
            discWallIds.add(wall.id);
            totalDiscontinuousWallsCount++;
          }
        }
      }

      // E. Lateral stiffness index
      final double latStiffness = (sumKx + sumKy) / math.pow(hM, 3);
      storeyStiffnessList.add(latStiffness);

      // Architect-facing spatial balancing recommendation
      final StringBuffer rec = StringBuffer();
      if (floatingIds.isNotEmpty) {
        rec.write('Колони ${floatingNames.join(", ")} са НАСАДЕНИ върху плочата (без колона отдолу). Това е сериозна сеизмична уязвимост! ');
      }
      if (isTorsionallySensitive) {
        rec.write('Силно усукване: ексцентрицитет ${math.max(exM, eyM).toStringAsFixed(2)} m (${(math.max(eRatioX, eRatioY) * 100).round()}%). ');
        if (crCad.dx < cmCad.dx) {
          rec.write('Препоръка: добавете шайба в източната (дясна) част. ');
        } else if (crCad.dx > cmCad.dx) {
          rec.write('Препоръка: добавете шайба в западната (лява) част. ');
        }
        if (crCad.dy < cmCad.dy) {
          rec.write('Препоръка: добавете шайба в северната част. ');
        } else if (crCad.dy > cmCad.dy) {
          rec.write('Препоръка: добавете шайба в южната част. ');
        }
      } else if (!wallOkX || !wallOkY) {
        if (!wallOkX && !wallOkY) {
          rec.write('Дефицит на шайби в двете направления (X: ${wallRatioX.toStringAsFixed(1)}%, Y: ${wallRatioY.toStringAsFixed(1)}% < 1.0%). Препоръчват се допълнителни шайби. ');
        } else if (!wallOkX) {
          rec.write('Дефицит на шайби по X (${wallRatioX.toStringAsFixed(1)}% < 1.0%). Препоръчва се шайба по направление X. ');
        } else {
          rec.write('Дефицит на шайби по Y (${wallRatioY.toStringAsFixed(1)}% < 1.0%). Препоръчва се шайба по направление Y. ');
        }
      } else {
        rec.write('Сеизмичният баланс и процентното покритие с шайби са отлични. ');
      }

      // Storey risk level
      final SeismicRiskLevel risk;
      if (floatingIds.isNotEmpty || isTorsionallySensitive) {
        risk = SeismicRiskLevel.critical;
      } else if (!wallOkX || !wallOkY || eRatioX > 0.08 || eRatioY > 0.08) {
        risk = SeismicRiskLevel.warning;
      } else {
        risk = SeismicRiskLevel.regular;
      }

      storeyChecks.add(StoreySeismicCheck(
        storeyId: storey.id,
        storeyName: storey.name,
        storeyIndex: sIdx,
        centerOfMassCad: cmCad,
        centerOfRigidityCad: crCad,
        eccentricityM: Offset(exM, eyM),
        dimensionXM: dimXM,
        dimensionYM: dimYM,
        eccentricityRatioX: eRatioX,
        eccentricityRatioY: eRatioY,
        isTorsionallySensitive: isTorsionallySensitive,
        wallAreaXM2: totalWallAreaX,
        wallAreaYM2: totalWallAreaY,
        floorAreaM2: floorAreaM2,
        wallRatioX: wallRatioX,
        wallRatioY: wallRatioY,
        isWallCoverageSufficientX: wallOkX,
        isWallCoverageSufficientY: wallOkY,
        floatingColumnIds: floatingIds,
        floatingColumnNames: floatingNames,
        discontinuousWallIds: discWallIds,
        lateralStiffnessIndex: latStiffness,
        isSoftStorey: false,
        riskLevel: risk,
        architectRecommendation: rec.toString().trim(),
      ));
    }

    // 2. Soft Storey Check between storeys
    final List<StoreySeismicCheck> updatedStoreyChecks = [];
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final cur = storeyChecks[sIdx];
      double? ratioToAbove;
      bool isSoft = false;
      if (sIdx < numStoreys - 1) {
        final kAbove = storeyStiffnessList[sIdx + 1];
        if (kAbove > 1e-4) {
          ratioToAbove = storeyStiffnessList[sIdx] / kAbove;
          if (ratioToAbove < 0.70) {
            isSoft = true;
            anySoftStorey = true;
          }
        }
      }

      var finalRisk = cur.riskLevel;
      if (isSoft && finalRisk != SeismicRiskLevel.critical) {
        finalRisk = SeismicRiskLevel.critical;
      }

      String finalRec = cur.architectRecommendation;
      if (isSoft) {
        finalRec = 'ВНИМАНИЕ: МЕК ЕТАЖ! Коравината на този етаж е с над 30% по-ниска от горния. $finalRec';
      }

      updatedStoreyChecks.add(StoreySeismicCheck(
        storeyId: cur.storeyId,
        storeyName: cur.storeyName,
        storeyIndex: cur.storeyIndex,
        centerOfMassCad: cur.centerOfMassCad,
        centerOfRigidityCad: cur.centerOfRigidityCad,
        eccentricityM: cur.eccentricityM,
        dimensionXM: cur.dimensionXM,
        dimensionYM: cur.dimensionYM,
        eccentricityRatioX: cur.eccentricityRatioX,
        eccentricityRatioY: cur.eccentricityRatioY,
        isTorsionallySensitive: cur.isTorsionallySensitive,
        wallAreaXM2: cur.wallAreaXM2,
        wallAreaYM2: cur.wallAreaYM2,
        floorAreaM2: cur.floorAreaM2,
        wallRatioX: cur.wallRatioX,
        wallRatioY: cur.wallRatioY,
        isWallCoverageSufficientX: cur.isWallCoverageSufficientX,
        isWallCoverageSufficientY: cur.isWallCoverageSufficientY,
        floatingColumnIds: cur.floatingColumnIds,
        floatingColumnNames: cur.floatingColumnNames,
        discontinuousWallIds: cur.discontinuousWallIds,
        lateralStiffnessIndex: cur.lateralStiffnessIndex,
        stiffnessRatioToAbove: ratioToAbove,
        isSoftStorey: isSoft,
        riskLevel: finalRisk,
        architectRecommendation: finalRec,
      ));
    }

    // 3. Preliminary Beam Sizing Check (h = L/10 - L/12)
    for (final storey in project.storeys) {
      for (int bIdx = 0; bIdx < storey.beams.length; bIdx++) {
        final beam = storey.beams[bIdx];
        final spanM = (beam.end - beam.start).distance / scale;
        final wM = beam.width;
        final dM = beam.depth;

        final minDepthM = (spanM / 12.0);
        final optimalDepthM = (spanM / 10.0);
        final bool isDepthOk = dM >= (minDepthM - 0.02);
        final bool isWidthOk = wM >= 0.25;

        final String beamRec;
        if (!isDepthOk) {
          final recH = (optimalDepthM * 100).round();
          beamRec = 'За отвор L = ${spanM.toStringAsFixed(2)} m, височина ${(dM * 100).round()} cm е недостатъчна. Препоръчва се греда ${(wM * 100).round()}x$recH cm.';
        } else if (!isWidthOk) {
          beamRec = 'Ширина ${(wM * 100).round()} cm е под сеизмичния минимум (25 cm по EC8). Препоръчва се 25x${(dM * 100).round()} cm.';
        } else {
          beamRec = 'Сечение ${(wM * 100).round()}x${(dM * 100).round()} cm е напълно оразмерено за отвор L = ${spanM.toStringAsFixed(2)} m.';
        }

        beamChecks.add(BeamSizingCheck(
          beamId: beam.id,
          beamName: 'Греда B${bIdx + 1}',
          storeyId: storey.id,
          storeyName: storey.name,
          spanM: spanM,
          currentWidthM: wM,
          currentDepthM: dM,
          recommendedMinDepthM: minDepthM,
          recommendedOptimalDepthM: optimalDepthM,
          isDepthSufficient: isDepthOk,
          isWidthSufficient: isWidthOk,
          recommendation: beamRec,
        ));
      }
    }

    // 4. Openings Proximity Check
    for (final storey in project.storeys) {
      for (final slab in storey.slabs) {
        for (int opIdx = 0; opIdx < slab.openings.length; opIdx++) {
          final op = slab.openings[opIdx];
          final opCentroid = _computePolygonCentroid(op);

          double minSupportDist = double.infinity;
          String? nearestSupport;

          for (int cIdx = 0; cIdx < storey.columns.length; cIdx++) {
            final col = storey.columns[cIdx];
            final dist = (col.center - opCentroid).distance / scale;
            if (dist < minSupportDist) {
              minSupportDist = dist;
              nearestSupport = 'Колона C${cIdx + 1}';
            }
          }

          final bool isTooClose = minSupportDist < 0.70; // 4d ~ 0.70m
          final String opRec = isTooClose
              ? 'Отворът е на ${minSupportDist.toStringAsFixed(2)} m от $nearestSupport (< 0.70 m), нарушава конуса на пробиване и изисква специално окантване!'
              : 'Отворът е на безопасно разстояние (${minSupportDist.toStringAsFixed(2)} m от $nearestSupport).';

          openingChecks.add(OpeningProximityCheck(
            openingId: '${slab.id}_op_$opIdx',
            storeyId: storey.id,
            storeyName: storey.name,
            distanceToSupportM: minSupportDist,
            nearestSupportName: nearestSupport,
            isTooClose: isTooClose,
            recommendation: opRec,
          ));
        }
      }
    }

    final SeismicRiskLevel overallRisk;
    if (totalFloatingColsCount > 0 || anyTorsionalSensitivity || anySoftStorey) {
      overallRisk = SeismicRiskLevel.critical;
    } else if (anyWallDeficit || maxGlobalEccRatio > 0.08) {
      overallRisk = SeismicRiskLevel.warning;
    } else {
      overallRisk = SeismicRiskLevel.regular;
    }

    return SeismicAnalysisReport(
      storeyChecks: updatedStoreyChecks,
      beamChecks: beamChecks,
      openingChecks: openingChecks,
      totalFloatingColumnsCount: totalFloatingColsCount,
      totalDiscontinuousWallsCount: totalDiscontinuousWallsCount,
      hasTorsionalSensitivity: anyTorsionalSensitivity,
      hasSoftStorey: anySoftStorey,
      hasWallDeficit: anyWallDeficit,
      maxEccentricityRatio: maxGlobalEccRatio,
      overallRisk: overallRisk,
    );
  }

  static Offset _computePolygonCentroid(List<Offset> poly) {
    if (poly.isEmpty) return Offset.zero;
    if (poly.length == 1) return poly.first;
    if (poly.length == 2) return (poly[0] + poly[1]) / 2.0;

    double signedArea = 0.0;
    double cx = 0.0;
    double cy = 0.0;
    final int n = poly.length;

    for (int i = 0; i < n; i++) {
      final p0 = poly[i];
      final p1 = poly[(i + 1) % n];
      final a = p0.dx * p1.dy - p1.dx * p0.dy;
      signedArea += a;
      cx += (p0.dx + p1.dx) * a;
      cy += (p0.dy + p1.dy) * a;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 1e-6) {
      double sx = 0.0, sy = 0.0;
      for (final p in poly) {
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / n, sy / n);
    }

    return Offset(cx / (6.0 * signedArea), cy / (6.0 * signedArea));
  }

  static double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (p - a).distance;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + clampedT * ab.dx, a.dy + clampedT * ab.dy);
    return (p - proj).distance;
  }
}
