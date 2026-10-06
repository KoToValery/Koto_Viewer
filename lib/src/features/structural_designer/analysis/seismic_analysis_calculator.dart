import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import 'seismic_layout_properties.dart';

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
    int totalDisconnectedWallsCount = 0;
    int totalDisconnectedColsCount = 0;
    bool anyTorsionalSensitivity = false;
    bool anyStructuralEccentricity = false;
    bool anySoftStorey = false;
    bool anyWallDeficit = false;
    double maxGlobalEccRatio = 0.0;

    final List<double> storeyStiffnessList = [];

    // 1. Analyze each storey
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final storey = project.storeys[sIdx];
      final double hM = math.max(2.4, storey.height);

      // Floor slab area & bounding dimensions of the slab diaphragm
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

      // Check whether a physical slab diaphragm exists on this storey
      final bool hasSlabDiaphragm = storey.slabs.isNotEmpty && floorAreaM2 >= 1.0;

      // If no slab diaphragm exists at this level:
      // In accordance with Eurocode 8 and structural dynamics, CM, CR, and eccentricity
      // cannot be computed because horizontal seismic inertia forces and rigid-diaphragm
      // kinematics are defined by the floor slab.
      if (!hasSlabDiaphragm) {
        final List<String> floatingIds = [];
        final List<String> floatingNames = [];

        if (sIdx > 0) {
          final lowerStorey = project.storeys[sIdx - 1];
          for (int cIdx = 0; cIdx < storey.columns.length; cIdx++) {
            final col = storey.columns[cIdx];
            final cPos = col.center;
            bool hasSupportBelow = false;
            for (final lowerCol in lowerStorey.columns) {
              final dist = (lowerCol.center - cPos).distance / scale;
              if (dist <= 0.25) {
                hasSupportBelow = true;
                break;
              }
            }
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
              floatingNames.add(col.displayName);
              totalFloatingColsCount++;
            }
          }
        }

        storeyStiffnessList.add(0.0);

        final rec = StringBuffer();
        rec.write('Липсва подова плоча на този етаж. За изчисляване на Центъра на масите (CM), Центъра на коравината (CR) и сеизмичния ексцентрицитет е необходима плоча над колоните и шайбите, която да действа като хоризонтална диафрагма.');

        final risk = (floatingIds.isNotEmpty)
            ? SeismicRiskLevel.critical
            : SeismicRiskLevel.warning;

        storeyChecks.add(StoreySeismicCheck(
          storeyId: storey.id,
          storeyName: storey.name,
          storeyIndex: sIdx,
          hasSlabDiaphragm: false,
          hasLateralStiffness: false,
          centerOfMassCad: null,
          centerOfRigidityCad: null,
          eccentricityM: null,
          dimensionXM: 0.0,
          dimensionYM: 0.0,
          eccentricityRatioX: 0.0,
          eccentricityRatioY: 0.0,
          isTorsionallySensitive: false,
          wallAreaXM2: 0.0,
          wallAreaYM2: 0.0,
          floorAreaM2: 0.0,
          wallRatioX: 0.0,
          wallRatioY: 0.0,
          isWallCoverageSufficientX: false,
          isWallCoverageSufficientY: false,
          floatingColumnIds: floatingIds,
          floatingColumnNames: floatingNames,
          discontinuousWallIds: const [],
          disconnectedWallIds: const [],
          disconnectedWallNames: const [],
          disconnectedColumnIds: const [],
          disconnectedColumnNames: const [],
          lateralStiffnessIndex: 0.0,
          isSoftStorey: false,
          riskLevel: risk,
          architectRecommendation: rec.toString().trim(),
        ));
        continue;
      }

      final double dimXM = math.max(3.0, (maxX - minX) / scale);
      final double dimYM = math.max(3.0, (maxY - minY) / scale);

      // Filter connected vs disconnected columns (elements outside the slab diaphragm)
      final List<StructuralColumn> connectedCols = [];
      final List<String> disconnectedColIds = [];
      final List<String> disconnectedColNames = [];

      for (int cIdx = 0; cIdx < storey.columns.length; cIdx++) {
        final col = storey.columns[cIdx];
        if (isColumnConnectedToSlab(col, storey.slabs, scale)) {
          connectedCols.add(col);
        } else {
          disconnectedColIds.add(col.id);
          disconnectedColNames.add(col.displayName);
          totalDisconnectedColsCount++;
        }
      }

      // Filter connected vs disconnected shear walls (elements outside the slab diaphragm)
      final List<_ConnectedWallData> connectedWalls = [];
      final List<String> disconnectedWallIds = [];
      final List<String> disconnectedWallNames = [];

      for (int wIdx = 0; wIdx < storey.shearWalls.length; wIdx++) {
        final wall = storey.shearWalls[wIdx];
        final conn = getWallDiaphragmConnection(wall, storey.slabs, scale);
        if (conn.isConnected && conn.effectiveLengthM > 0.05) {
          connectedWalls.add(_ConnectedWallData(wall: wall, connection: conn));
        } else {
          disconnectedWallIds.add(wall.id);
          disconnectedWallNames.add('Ш${wIdx + 1}');
          totalDisconnectedWallsCount++;
        }
      }

      // A. Calculate Center of Mass (CM)
      // The floor slab accounts for almost the entire diaphragm mass (~85-95%+).
      // Only vertical elements connected to the slab contribute tributary mass to this level.
      double totalMass = 0.0;
      double sumMassX = 0.0;
      double sumMassY = 0.0;

      // Slab mass and centroid (accounting for openings)
      for (final slab in storey.slabs) {
        final aM2 = slab.netArea / (scale * scale);
        final cCad = _computeSlabNetCentroid(slab);
        final slabMass = aM2 * (25.0 * slab.thickness + project.deadLoadSuperimposed + 0.3 * project.liveLoad);
        totalMass += slabMass;
        sumMassX += slabMass * cCad.dx;
        sumMassY += slabMass * cCad.dy;
      }

      // Connected columns tributary mass
      for (final col in connectedCols) {
        final section = PolygonMassIntegrals.integrate(col.polygonVertices, col.center, scale);
        final colAreaM2 = col.shape == ColumnShape.circular
            ? math.pi * math.pow(col.width / scale, 2) / 4 : section.area;
        final centroid = col.shape == ColumnShape.circular || section.area <= 0 ? col.center
            : col.center + Offset(section.firstX / section.area, section.firstY / section.area) * scale;
        final colMass = colAreaM2 * hM * 25.0;
        totalMass += colMass;
        sumMassX += colMass * centroid.dx;
        sumMassY += colMass * centroid.dy;
      }

      // Connected shear walls tributary mass
      for (final cw in connectedWalls) {
        final wall = cw.wall;
        final conn = cw.connection;
        final wallMass = conn.effectiveLengthM * (wall.thickness / scale) * hM * 25.0;
        totalMass += wallMass;
        sumMassX += wallMass * conn.effectiveCenterCad.dx;
        sumMassY += wallMass * conn.effectiveCenterCad.dy;
      }

      final Offset cmCad;
      if (totalMass > 0) {
        cmCad = Offset(sumMassX / totalMass, sumMassY / totalMass);
      } else {
        cmCad = Offset((minX + maxX) / 2.0, (minY + maxY) / 2.0);
      }

      // Preliminary elastic layout model: shared E/end-restraint factors cancel.
      // A complete frame/shell model is still required for design verification.
      final supports = <LayoutSupport>[];
      double totalWallAreaX = 0, totalWallAreaY = 0;
      for (final cw in connectedWalls) {
        final wall = cw.wall;
        final length = cw.connection.effectiveLengthM;
        final thickness = wall.thickness / scale;
        final delta = wall.end - wall.start;
        final angle = math.atan2(delta.dy, delta.dx);
        supports.add(LayoutSupport.rotated(cw.connection.effectiveCenterCad / scale,
          thickness * math.pow(length, 3) / 12,
          length * math.pow(thickness, 3) / 12, angle));
        totalWallAreaX += length * thickness * math.cos(angle).abs();
        totalWallAreaY += length * thickness * math.sin(angle).abs();
      }
      var unsupportedSection = false;
      for (final col in connectedCols) {
        final w = col.width / scale, h = col.height / scale;
        if (col.shape == ColumnShape.lShape) {
          unsupportedSection = true;
          continue;
        }
        final ix = col.shape == ColumnShape.circular ? math.pi * math.pow(w, 4) / 64 : h * math.pow(w, 3) / 12;
        final iy = col.shape == ColumnShape.circular ? ix : w * math.pow(h, 3) / 12;
        supports.add(LayoutSupport.rotated(col.center / scale, ix, iy, col.rotationRad));
      }
      final rigidity = unsupportedSection ? null : LayoutRigidity.calculate(supports);
      final hasLateralStiffness = rigidity != null;
      final sumKx = rigidity?.kx ?? 0.0, sumKy = rigidity?.ky ?? 0.0;
      // Internal placeholder only: unavailable CR is exported as null below.
      final crCad = rigidity == null ? cmCad : rigidity.center * scale;
      final sumIpR = rigidity?.torsion ?? 0.0; // m^6 layout index, not m^4 + m^6.

      // Integrate the same distributed weights used for CM, about that CM.
      double polarWeight = 0;
      for (final slab in storey.slabs) {
        var polar = PolygonMassIntegrals.integrate(slab.polygon, cmCad, scale).polar;
        for (final opening in slab.openings) {
          polar -= PolygonMassIntegrals.integrate(opening, cmCad, scale).polar;
        }
        polarWeight += polar * (25 * slab.thickness + project.deadLoadSuperimposed + 0.3 * project.liveLoad);
      }
      for (final col in connectedCols) {
        if (col.shape == ColumnShape.circular) {
          final radius = col.width / scale / 2;
          final area = math.pi * radius * radius;
          polarWeight += 25 * hM * area * (radius*radius/2 + ((col.center-cmCad)/scale).distanceSquared);
        } else {
          polarWeight += 25 * hM * PolygonMassIntegrals.integrate(col.polygonVertices, cmCad, scale).polar;
        }
      }
      for (final cw in connectedWalls) {
        final length = cw.connection.effectiveLengthM, thickness = cw.wall.thickness / scale;
        final area = length * thickness;
        polarWeight += 25*hM*area*((length*length+thickness*thickness)/12 +
            ((cw.connection.effectiveCenterCad-cmCad)/scale).distanceSquared);
      }
      final ls = totalMass > 0 ? math.sqrt(math.max(0, polarWeight / totalMass)) : 0.0;
      final exM = (cmCad.dx-crCad.dx).abs()/scale;
      final eyM = (cmCad.dy-crCad.dy).abs()/scale;
      final eRatioX = exM/dimXM, eRatioY = eyM/dimYM;
      if (hasLateralStiffness) {
        maxGlobalEccRatio = math.max(maxGlobalEccRatio, math.max(eRatioX, eRatioY));
      }
      final rx = sumKy > 0 ? math.sqrt(sumIpR/sumKy) : 0.0;
      final ry = sumKx > 0 ? math.sqrt(sumIpR/sumKx) : 0.0;
      final isTorsionallyStiff = hasLateralStiffness && rx >= ls && ry >= ls;
      final hasSignificantEccentricity = hasLateralStiffness && (exM > .30*rx || eyM > .30*ry);
      if (hasSignificantEccentricity) anyStructuralEccentricity = true;
      // Symmetry alone does not exempt a torsionally flexible layout.
      final isTorsionallySensitive = hasLateralStiffness && !isTorsionallyStiff;
      if (isTorsionallySensitive) anyTorsionalSensitivity = true;
      // These two indicators alone cannot establish all EC8 plan regularity criteria.
      const isPlanRegularEC8 = false;

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
            floatingNames.add(col.displayName);
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
      if (disconnectedWallNames.isNotEmpty) {
        rec.write('Шайби ${disconnectedWallNames.join(", ")} са извън очертанията на плочата и не участват в пресмятането на коравината (CR) и сеизмичния център. ');
      }
      if (disconnectedColNames.isNotEmpty) {
        rec.write('Колони ${disconnectedColNames.join(", ")} са извън очертанията на плочата и не участват в подовата диафрагма. ');
      }
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
      } else if (isTorsionallyStiff && hasSignificantEccentricity) {
        rec.write('Торзионно устойчива схема (rx=${rx.toStringAsFixed(2)} m, ry=${ry.toStringAsFixed(2)} m ≥ ls=${ls.toStringAsFixed(2)} m), но структурният ексцентрицитет (${math.max(exM, eyM).toStringAsFixed(2)} m) надвишава 0.30·r. Изисква се 3D пространствен динамичен модален анализ съгласно Еврокод 8. ');
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
      if (floatingIds.isNotEmpty) {
        risk = SeismicRiskLevel.critical;
      } else if (!hasLateralStiffness || isTorsionallySensitive || !wallOkX || !wallOkY || hasSignificantEccentricity || eRatioX > 0.08 || eRatioY > 0.08 || disconnectedWallIds.isNotEmpty || disconnectedColIds.isNotEmpty) {
        risk = SeismicRiskLevel.warning;
      } else {
        risk = SeismicRiskLevel.regular;
      }

      storeyChecks.add(StoreySeismicCheck(
        storeyId: storey.id,
        storeyName: storey.name,
        storeyIndex: sIdx,
        hasSlabDiaphragm: true,
        centerOfMassCad: cmCad,
        centerOfRigidityCad: hasLateralStiffness ? crCad : null,
        hasLateralStiffness: hasLateralStiffness,
        eccentricityM: hasLateralStiffness ? Offset(exM, eyM) : null,
        dimensionXM: dimXM,
        dimensionYM: dimYM,
        eccentricityRatioX: eRatioX,
        eccentricityRatioY: eRatioY,
        isTorsionallySensitive: isTorsionallySensitive,
        torsionalRadiusX: rx,
        torsionalRadiusY: ry,
        massRadiusOfGyration: ls,
        torsionalRigidity: sumIpR,
        isTorsionallyStiff: isTorsionallyStiff,
        hasSignificantEccentricity: hasSignificantEccentricity,
        isPlanRegularEC8: isPlanRegularEC8,
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
        disconnectedWallIds: disconnectedWallIds,
        disconnectedWallNames: disconnectedWallNames,
        disconnectedColumnIds: disconnectedColIds,
        disconnectedColumnNames: disconnectedColNames,
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
        if (cur.hasSlabDiaphragm && kAbove > 1e-4) {
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
        hasSlabDiaphragm: cur.hasSlabDiaphragm,
        hasLateralStiffness: cur.hasLateralStiffness,
        centerOfMassCad: cur.centerOfMassCad,
        centerOfRigidityCad: cur.centerOfRigidityCad,
        eccentricityM: cur.eccentricityM,
        dimensionXM: cur.dimensionXM,
        dimensionYM: cur.dimensionYM,
        eccentricityRatioX: cur.eccentricityRatioX,
        eccentricityRatioY: cur.eccentricityRatioY,
        isTorsionallySensitive: cur.isTorsionallySensitive,
        torsionalRadiusX: cur.torsionalRadiusX,
        torsionalRadiusY: cur.torsionalRadiusY,
        massRadiusOfGyration: cur.massRadiusOfGyration,
        torsionalRigidity: cur.torsionalRigidity,
        isTorsionallyStiff: cur.isTorsionallyStiff,
        hasSignificantEccentricity: cur.hasSignificantEccentricity,
        isPlanRegularEC8: cur.isPlanRegularEC8,
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
        disconnectedWallIds: cur.disconnectedWallIds,
        disconnectedWallNames: cur.disconnectedWallNames,
        disconnectedColumnIds: cur.disconnectedColumnIds,
        disconnectedColumnNames: cur.disconnectedColumnNames,
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
        final wM = (scale > 1.5 && beam.width <= 2.0) ? beam.width : beam.width / scale;
        final dM = (scale > 1.5 && beam.depth <= 2.0) ? beam.depth : beam.depth / scale;

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
          final int roundedW = (wM * 100).round();
          final int roundedD = (dM * 100).round();
          beamRec = 'Сечение ${roundedW}x$roundedD cm е напълно оразмерено за отвор L = ${spanM.toStringAsFixed(2)} m.';
        }

        beamChecks.add(BeamSizingCheck(
          beamId: beam.id,
          beamName: beam.displayName,
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
    if (totalFloatingColsCount > 0 || anySoftStorey) {
      overallRisk = SeismicRiskLevel.critical;
    } else if (storeyChecks.any((c) => !c.hasLateralStiffness) || anyTorsionalSensitivity || anyWallDeficit || anyStructuralEccentricity || maxGlobalEccRatio > 0.08 || totalDisconnectedWallsCount > 0 || totalDisconnectedColsCount > 0) {
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
      totalDisconnectedWallsCount: totalDisconnectedWallsCount,
      totalDisconnectedColumnsCount: totalDisconnectedColsCount,
      hasTorsionalSensitivity: anyTorsionalSensitivity,
      hasStructuralEccentricity: anyStructuralEccentricity,
      hasSoftStorey: anySoftStorey,
      hasWallDeficit: anyWallDeficit,
      maxEccentricityRatio: maxGlobalEccRatio,
      overallRisk: overallRisk,
    );
  }

  /// Calculates the exact centroid of a slab polygon, taking into account any cutout openings.
  static Offset _computeSlabNetCentroid(StructuralSlab slab) {
    final grossArea = StructuralSlab.calculateArea(slab.polygon);
    if (grossArea < 1e-6) return slab.centroid;
    final grossCentroid = _computePolygonCentroid(slab.polygon);
    if (slab.openings.isEmpty) return grossCentroid;

    double netArea = grossArea;
    double sumAx = grossArea * grossCentroid.dx;
    double sumAy = grossArea * grossCentroid.dy;

    for (final op in slab.openings) {
      final opArea = StructuralSlab.calculateArea(op);
      if (opArea > 1e-6) {
        final opCentroid = _computePolygonCentroid(op);
        netArea -= opArea;
        sumAx -= opArea * opCentroid.dx;
        sumAy -= opArea * opCentroid.dy;
      }
    }

    if (netArea > 1e-6) {
      return Offset(sumAx / netArea, sumAy / netArea);
    }
    return grossCentroid;
  }

  /// Checks if a point lies inside any of the given slabs (with optional CAD tolerance).
  static bool isPointInsideSlabs(
    Offset pt,
    List<StructuralSlab> slabs, {
    double toleranceCad = 0.0,
  }) {
    for (final slab in slabs) {
      if (slab.polygon.length < 3) continue;
      if (toleranceCad <= 1e-4) {
        if (slab.containsPoint(pt)) return true;
      } else {
        final inflated = slab.bounds.inflate(toleranceCad);
        if (!inflated.contains(pt)) continue;
        if (slab.containsPoint(pt)) return true;
        // Edge tolerance: within tolerance of the slab perimeter and not inside cutout
        if (_distanceToPolygonPerimeter(pt, slab.polygon) <= toleranceCad) {
          bool inOpening = false;
          for (final op in slab.openings) {
            if (StructuralSlab.calculateArea(op) > 1e-4 && _isPointInPoly(pt, op)) {
              inOpening = true;
              break;
            }
          }
          if (!inOpening) return true;
        }
      }
    }
    return false;
  }

  /// Ray-casting test for point-in-polygon.
  static bool _isPointInPoly(Offset pt, List<Offset> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Shortest distance from [pt] to any edge of the polygon.
  static double _distanceToPolygonPerimeter(Offset pt, List<Offset> poly) {
    if (poly.length < 2) return double.infinity;
    double minDist = double.infinity;
    final int n = poly.length;
    for (int i = 0; i < n; i++) {
      final d = _distancePointToSegment(pt, poly[i], poly[(i + 1) % n]);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Determines if a column is covered by or connected to the floor slab diaphragm.
  static bool isColumnConnectedToSlab(
    StructuralColumn col,
    List<StructuralSlab> slabs,
    double scale,
  ) {
    if (slabs.isEmpty) return false;
    // CAD tolerance: half column dimension + 0.10m margin
    final double tolCad = math.max(col.width, col.height) * 0.55 + 0.10 * scale;
    if (isPointInsideSlabs(col.center, slabs, toleranceCad: tolCad)) {
      return true;
    }
    for (final v in col.polygonVertices) {
      if (isPointInsideSlabs(v, slabs, toleranceCad: 0.05 * scale)) {
        return true;
      }
    }
    return false;
  }

  /// Computes the connection of a shear wall to the floor slab diaphragm.
  /// If the shear wall is located outside the slab boundary, [isConnected] is false
  /// and [effectiveLengthM] is 0.0, excluding it from diaphragm rigidity and mass.
  static WallDiaphragmConnection getWallDiaphragmConnection(
    StructuralShearWall wall,
    List<StructuralSlab> slabs,
    double scale,
  ) {
    if (slabs.isEmpty) {
      return const WallDiaphragmConnection(
        isConnected: false,
        connectedFraction: 0.0,
        effectiveLengthM: 0.0,
        effectiveCenterCad: Offset.zero,
      );
    }

    final double totalLenCad = wall.length;
    final double tolCad = (wall.thickness * 0.55) + (0.12 * scale);

    if (totalLenCad < 1e-4) {
      final inside = isPointInsideSlabs(wall.start, slabs, toleranceCad: tolCad);
      return WallDiaphragmConnection(
        isConnected: inside,
        connectedFraction: inside ? 1.0 : 0.0,
        effectiveLengthM: inside ? (wall.thickness / scale) : 0.0,
        effectiveCenterCad: wall.start,
      );
    }

    const int samples = 11;
    int connectedCount = 0;
    double sumX = 0.0;
    double sumY = 0.0;

    for (int i = 0; i < samples; i++) {
      final t = i / (samples - 1);
      final pt = Offset(
        wall.start.dx + (wall.end.dx - wall.start.dx) * t,
        wall.start.dy + (wall.end.dy - wall.start.dy) * t,
      );
      if (isPointInsideSlabs(pt, slabs, toleranceCad: tolCad)) {
        connectedCount++;
        sumX += pt.dx;
        sumY += pt.dy;
      }
    }

    if (connectedCount == 0) {
      return const WallDiaphragmConnection(
        isConnected: false,
        connectedFraction: 0.0,
        effectiveLengthM: 0.0,
        effectiveCenterCad: Offset.zero,
      );
    }

    final fraction = connectedCount / samples;
    final effLenM = (totalLenCad / scale) * fraction;
    final effCenter = Offset(sumX / connectedCount, sumY / connectedCount);

    return WallDiaphragmConnection(
      isConnected: true,
      connectedFraction: fraction,
      effectiveLengthM: effLenM,
      effectiveCenterCad: effCenter,
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

/// Helper container for connected wall data in seismic analysis.
class _ConnectedWallData {
  final StructuralShearWall wall;
  final WallDiaphragmConnection connection;

  const _ConnectedWallData({required this.wall, required this.connection});
}

/// Result of evaluating whether and how much of a shear wall is connected to the slab diaphragm.
class WallDiaphragmConnection {
  final bool isConnected;
  final double connectedFraction;
  final double effectiveLengthM;
  final Offset effectiveCenterCad;

  const WallDiaphragmConnection({
    required this.isConnected,
    required this.connectedFraction,
    required this.effectiveLengthM,
    required this.effectiveCenterCad,
  });
}
