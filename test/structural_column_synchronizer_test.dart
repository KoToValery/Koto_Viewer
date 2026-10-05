import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_column_synchronizer.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  group('StructuralColumnSynchronizer', () {
    test('Synchronizes identical columns across storeys to share the same name', () {
      // Storey 1 (Ground)
      final col1_L1 = StructuralColumn(
        id: 'c1_l1',
        name: 'К1',
        center: const Offset(2.0, 2.0),
        width: 0.25,
        height: 0.25,
      );
      final col2_L1 = StructuralColumn(
        id: 'c2_l1',
        name: 'К2',
        center: const Offset(5.0, 5.0),
        width: 0.25,
        height: 0.50,
      );

      // Storey 2 (First floor) - identical positions and cross-sections, but temporary/unsynced names
      final col1_L2 = StructuralColumn(
        id: 'c1_l2',
        name: 'К_temp1',
        center: const Offset(2.0, 2.0),
        width: 0.25,
        height: 0.25,
      );
      final col2_L2 = StructuralColumn(
        id: 'c2_l2',
        name: 'К_temp2',
        center: const Offset(5.0, 5.0),
        width: 0.25,
        height: 0.50,
      );

      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'storey_1',
            name: 'Ниво 1',
            elevation: 0.0,
            height: 3.0,
            columns: [col1_L1, col2_L1],
          ),
          StoreyLevel(
            id: 'storey_2',
            name: 'Ниво 2',
            elevation: 3.0,
            height: 3.0,
            columns: [col1_L2, col2_L2],
          ),
        ],
      );

      final (syncedProject, count) = StructuralColumnSynchronizer.synchronize(project);
      expect(count, greaterThan(0));

      final syncedL1 = syncedProject.storeys[0].columns;
      final syncedL2 = syncedProject.storeys[1].columns;

      expect(syncedL1[0].displayName, 'К1');
      expect(syncedL2[0].displayName, 'К1');

      expect(syncedL1[1].displayName, 'К2');
      expect(syncedL2[1].displayName, 'К2');
    });

    test('Assigns distinct name when column cross-section changes on an upper level, and propagates up', () {
      // Storey 1: Col A is 25x50 (К1), Col B is 25x25 (К2)
      final colA_L1 = StructuralColumn(
        id: 'ca_l1',
        name: 'К1',
        center: const Offset(2.0, 2.0),
        width: 0.25,
        height: 0.50,
      );
      final colB_L1 = StructuralColumn(
        id: 'cb_l1',
        name: 'К2',
        center: const Offset(8.0, 8.0),
        width: 0.25,
        height: 0.25,
      );

      // Storey 2: Col A is reduced from 25x50 down to 25x25 at same position (2, 2)
      // Col B remains 25x25 at (8, 8)
      final colA_L2 = StructuralColumn(
        id: 'ca_l2',
        name: 'К1',
        center: const Offset(2.0, 2.0),
        width: 0.25,
        height: 0.25, // Dim changed!
      );
      final colB_L2 = StructuralColumn(
        id: 'cb_l2',
        name: 'К2',
        center: const Offset(8.0, 8.0),
        width: 0.25,
        height: 0.25,
      );

      // Storey 3: Col A continues at 25x25 at (2, 2)
      final colA_L3 = StructuralColumn(
        id: 'ca_l3',
        name: 'К1',
        center: const Offset(2.0, 2.0),
        width: 0.25,
        height: 0.25, // Still 25x25
      );

      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'storey_1',
            name: 'Ниво 1',
            elevation: 0.0,
            height: 3.0,
            columns: [colA_L1, colB_L1],
          ),
          StoreyLevel(
            id: 'storey_2',
            name: 'Ниво 2',
            elevation: 3.0,
            height: 3.0,
            columns: [colA_L2, colB_L2],
          ),
          StoreyLevel(
            id: 'storey_3',
            name: 'Ниво 3',
            elevation: 6.0,
            height: 3.0,
            columns: [colA_L3],
          ),
        ],
      );

      final (syncedProject, _) = StructuralColumnSynchronizer.synchronize(project);

      final l1Cols = syncedProject.storeys[0].columns;
      final l2Cols = syncedProject.storeys[1].columns;
      final l3Cols = syncedProject.storeys[2].columns;

      // On L1: ca is К1 (25x50), cb is К2 (25x25)
      expect(l1Cols[0].displayName, 'К1');
      expect(l1Cols[1].displayName, 'К2');

      // On L2: cb is identical to L1 cb, so retains К2
      expect(l2Cols[1].displayName, 'К2');

      // On L2: ca changed section (25x25), so must NOT be К1.
      expect(l2Cols[0].displayName, isNot('К1'));
      final newCaName = l2Cols[0].displayName;

      // On L3: ca has identical section to L2 ca (25x25), so must share the new name!
      expect(l3Cols[0].displayName, newCaName);
    });

    test('findMatchingColumnName finds vertical column match within tolerance and dimensions', () {
      final baseCol = StructuralColumn(
        id: 'c_base',
        name: 'К5',
        center: const Offset(10.0, 10.0),
        width: 0.30,
        height: 0.60,
      );

      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'storey_1',
            name: 'Ниво 1',
            elevation: 0.0,
            height: 3.0,
            columns: [baseCol],
          ),
        ],
      );

      // Candidate with identical size at (10.02, 10.01) within 0.20m tolerance
      final candidateMatch = StructuralColumn(
        id: 'c_cand1',
        center: const Offset(10.02, 10.01),
        width: 0.30,
        height: 0.60,
      );
      final match1 = StructuralColumnSynchronizer.findMatchingColumnName(
        project,
        const Offset(10.02, 10.01),
        candidateMatch,
      );
      expect(match1, 'К5');

      // Different dimensions (0.25 x 0.60) -> no match
      final candidateDiff = StructuralColumn(
        id: 'c_cand2',
        center: const Offset(10.0, 10.0),
        width: 0.25,
        height: 0.60,
      );
      final matchDiffDim = StructuralColumnSynchronizer.findMatchingColumnName(
        project,
        const Offset(10.0, 10.0),
        candidateDiff,
      );
      expect(matchDiffDim, isNull);

      // Distant position -> no match
      final candidateFar = StructuralColumn(
        id: 'c_cand3',
        center: const Offset(15.0, 10.0),
        width: 0.30,
        height: 0.60,
      );
      final matchFar = StructuralColumnSynchronizer.findMatchingColumnName(
        project,
        const Offset(15.0, 10.0),
        candidateFar,
      );
      expect(matchFar, isNull);
    });

    test('areColumnsIdenticalSection handles rotation symmetry', () {
      final col0 = StructuralColumn(
        id: 'c0',
        center: Offset.zero,
        width: 0.25,
        height: 0.50,
        rotationRad: 0.0,
      );
      // 180 degrees rotated is identical rectangle
      final col180 = StructuralColumn(
        id: 'c180',
        center: Offset.zero,
        width: 0.25,
        height: 0.50,
        rotationRad: 3.14159,
      );
      // 90 degrees rotated is orthogonal rectangle (different orientation)
      final col90 = StructuralColumn(
        id: 'c90',
        center: Offset.zero,
        width: 0.25,
        height: 0.50,
        rotationRad: 3.14159 / 2,
      );

      expect(StructuralColumnSynchronizer.areColumnsIdenticalSection(col0, col180), isTrue);
      expect(StructuralColumnSynchronizer.areColumnsIdenticalSection(col0, col90), isFalse);
    });
  });
}
