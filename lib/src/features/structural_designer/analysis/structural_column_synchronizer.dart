import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';

/// Intelligent column numbering and level synchronization engine for the BIM Structural Designer.
///
/// Ensures:
/// 1. Columns stacked vertically across storeys (within 20 cm tolerance) that share identical
///    cross-section dimensions and shape have the EXACT same column number (e.g. К1 across all levels).
/// 2. If a column's cross-section is reduced or altered on any storey, it automatically receives
///    a distinct column number (e.g. К5), and subsequent storeys continuing that new section
///    retain that same new number.
class StructuralColumnSynchronizer {
  const StructuralColumnSynchronizer._();

  /// Default center-to-center distance threshold in meters to consider columns in the same vertical stack.
  static const double defaultStackToleranceM = 0.20;

  /// Default cross-section dimension tolerance in meters (5 mm).
  static const double defaultDimensionToleranceM = 0.005;

  /// Checks whether two columns have identical cross-section shape and dimensions.
  static bool areColumnsIdenticalSection(
    StructuralColumn a,
    StructuralColumn b, {
    double dimToleranceM = defaultDimensionToleranceM,
  }) {
    if (a.shape != b.shape) return false;
    if ((a.width - b.width).abs() > dimToleranceM) return false;
    if ((a.height - b.height).abs() > dimToleranceM) return false;
    if ((a.thickness - b.thickness).abs() > dimToleranceM) return false;

    // Rotation difference (modulo 180 degrees for rectangular/symmetric cross-sections)
    final diff = ((a.rotationRad - b.rotationRad) % math.pi).abs();
    if (diff > 0.08 && (math.pi - diff).abs() > 0.08) {
      return false;
    }

    return true;
  }

  /// Checks whether two column centers align vertically in the building.
  static bool areColumnsVerticallyStacked(
    Offset centerA,
    Offset centerB, {
    double cadUnitsPerMeter = 1.0,
    double stackToleranceM = defaultStackToleranceM,
  }) {
    final distM = (centerA - centerB).distance / cadUnitsPerMeter;
    return distM <= stackToleranceM;
  }

  /// Detects the dominant column prefix used in [project] ('К' in Bulgarian, 'C' in English).
  static String detectProjectPrefix(StructuralProject project, {String defaultPrefix = 'К'}) {
    for (final s in project.storeys) {
      for (final col in s.columns) {
        final pfx = extractElementPrefix(col.displayName);
        if (pfx != null && pfx.isNotEmpty) return pfx;
      }
    }
    return defaultPrefix;
  }

  /// Finds the next available column name in the entire project, higher than all existing indices.
  static String generateNextProjectColumnName(
    StructuralProject project, {
    String? preferredPrefix,
  }) {
    final prefix = preferredPrefix ?? detectProjectPrefix(project);
    int maxNum = 0;
    for (final s in project.storeys) {
      for (final col in s.columns) {
        final num = extractElementNumber(col.displayName);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    return '$prefix${maxNum + 1}';
  }

  /// Checks if a candidate column placed at [pos] matches an identical column on any other storey.
  /// If an identical column exists in the same vertical stack, returns its name.
  /// If a vertically stacked column exists but has DIFFERENT dimensions, returns null.
  static String? findMatchingColumnName(
    StructuralProject project,
    Offset pos,
    StructuralColumn candidate, {
    double cadUnitsPerMeter = 1.0,
  }) {
    for (final s in project.storeys) {
      for (final col in s.columns) {
        if (areColumnsVerticallyStacked(pos, col.center, cadUnitsPerMeter: cadUnitsPerMeter)) {
          if (areColumnsIdenticalSection(candidate, col)) {
            return col.displayName;
          }
        }
      }
    }
    return null;
  }

  /// Synchronizes column designations across all storeys in [project].
  ///
  /// Returns a tuple containing:
  /// - The updated [StructuralProject] with harmonized column names.
  /// - The total number of columns whose names were updated.
  static (StructuralProject, int) synchronize(
    StructuralProject project, {
    double cadUnitsPerMeter = 1.0,
    String? preferredPrefix,
  }) {
    if (project.storeys.isEmpty) return (project, 0);

    final prefix = preferredPrefix ?? detectProjectPrefix(project);

    // 1. Sort storeys by elevation ascending (foundation/ground to roof)
    final sortedIndices = List<int>.generate(project.storeys.length, (i) => i)
      ..sort((a, b) => project.storeys[a].elevation.compareTo(project.storeys[b].elevation));

    // Working copy of storeys: storeyIndex -> List<StructuralColumn>
    final updatedStoreyColumns = <int, List<StructuralColumn>>{
      for (int i = 0; i < project.storeys.length; i++)
        i: List<StructuralColumn>.from(project.storeys[i].columns),
    };

    // 2. Identify all vertical column stacks across the building
    // A stack is a collection of (storeyIndex, columnIndex) pairs at the same (X, Y) location.
    final processed = <(int, int)>{};
    final stacks = <List<(int, int)>>[];

    for (final sIdx in sortedIndices) {
      final cols = updatedStoreyColumns[sIdx]!;
      for (int cIdx = 0; cIdx < cols.length; cIdx++) {
        if (processed.contains((sIdx, cIdx))) continue;

        final currentStack = <(int, int)>[(sIdx, cIdx)];
        processed.add((sIdx, cIdx));
        final baseCenter = cols[cIdx].center;

        // Search in all subsequent storeys (and other storeys) for matching vertical columns
        for (final otherSIdx in sortedIndices) {
          if (otherSIdx == sIdx) continue;
          final otherCols = updatedStoreyColumns[otherSIdx]!;
          for (int ocIdx = 0; ocIdx < otherCols.length; ocIdx++) {
            if (processed.contains((otherSIdx, ocIdx))) continue;
            if (areColumnsVerticallyStacked(
              baseCenter,
              otherCols[ocIdx].center,
              cadUnitsPerMeter: cadUnitsPerMeter,
            )) {
              currentStack.add((otherSIdx, ocIdx));
              processed.add((otherSIdx, ocIdx));
            }
          }
        }

        // Sort entries in the stack by storey elevation
        currentStack.sort((a, b) => project.storeys[a.$1].elevation.compareTo(project.storeys[b.$1].elevation));
        stacks.add(currentStack);
      }
    }

    // 3. Keep track of already assigned column numbers to ensure no collisions
    final usedNumbers = <int>{};
    int maxAssignedNumber = 0;

    // Collect pre-existing valid column numbers from base storeys where possible
    for (final stack in stacks) {
      for (final ref in stack) {
        final col = updatedStoreyColumns[ref.$1]![ref.$2];
        final num = extractElementNumber(col.displayName);
        if (num != null) {
          usedNumbers.add(num);
          if (num > maxAssignedNumber) maxAssignedNumber = num;
        }
      }
    }

    int getNextAvailableNumber() {
      int next = 1;
      while (usedNumbers.contains(next)) {
        next++;
      }
      usedNumbers.add(next);
      if (next > maxAssignedNumber) maxAssignedNumber = next;
      return next;
    }

    int renamesCount = 0;

    // 4. Renumber each stack based on cross-section equality
    for (final stack in stacks) {
      // Map cross-section signature to an assigned column number within this vertical stack
      final sectionToNumberMap = <String, int>{};

      for (final ref in stack) {
        final col = updatedStoreyColumns[ref.$1]![ref.$2];

        // Unique cross-section key based on geometry
        final wRound = (col.width * 1000).round();
        final hRound = (col.height * 1000).round();
        final tRound = (col.thickness * 1000).round();
        final rotRound = ((col.rotationRad % math.pi) * 100).round();
        final sectionKey = '${col.shape}_${wRound}x${hRound}x${tRound}_r$rotRound';

        int? assignedNum = sectionToNumberMap[sectionKey];

        if (assignedNum == null) {
          // If this is the first section of the stack and it already has a valid unique number, try to preserve it
          final existingNum = extractElementNumber(col.displayName);
          if (existingNum != null && !sectionToNumberMap.values.contains(existingNum)) {
            assignedNum = existingNum;
            usedNumbers.add(existingNum);
            sectionToNumberMap[sectionKey] = assignedNum;
          } else {
            assignedNum = getNextAvailableNumber();
            sectionToNumberMap[sectionKey] = assignedNum;
          }
        }

        final targetName = '$prefix$assignedNum';
        if (col.displayName != targetName) {
          updatedStoreyColumns[ref.$1]![ref.$2] = col.copyWith(name: targetName);
          renamesCount++;
        }
      }
    }

    // 5. Construct updated project
    final updatedStoreys = List<StoreyLevel>.generate(project.storeys.length, (i) {
      return project.storeys[i].copyWith(columns: updatedStoreyColumns[i]!);
    });

    final updatedProject = project.copyWith(storeys: updatedStoreys);
    return (updatedProject, renamesCount);
  }
}
