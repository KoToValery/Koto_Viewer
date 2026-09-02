import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:flutter/material.dart';

/// **Validates: Requirements 1.1, 1.2, 2.1, 2.2**
///
/// Tests for Task 3.2: Enhanced header variable extraction
/// Verifies that DxfDocument helper methods correctly extract and parse
/// header variables: $DIMSCALE, $LTSCALE, $MEASUREMENT, $INSUNITS
void main() {
  group('DxfDocument Header Variable Helper Methods', () {
    test('getDimensionScale returns value from \$DIMSCALE header variable', () {
      // Create a simple DXF with $DIMSCALE header variable
      final dxfContent = '''0
SECTION
2
HEADER
9
\$DIMSCALE
40
2.5
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify the helper method extracts and parses the value correctly
      expect(doc.getDimensionScale(), 2.5);
    });

    test('getDimensionScale returns 1.0 default when \$DIMSCALE not present', () {
      // Create a simple DXF without $DIMSCALE
      final dxfContent = '''0
SECTION
2
HEADER
9
\$ACADVER
1
AC1015
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify default value is returned
      expect(doc.getDimensionScale(), 1.0);
    });

    test('getLineTypeScale returns value from \$LTSCALE header variable', () {
      // Create a simple DXF with $LTSCALE header variable
      final dxfContent = '''0
SECTION
2
HEADER
9
\$LTSCALE
40
1.75
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify the helper method extracts and parses the value correctly
      expect(doc.getLineTypeScale(), 1.75);
    });

    test('getLineTypeScale returns 1.0 default when \$LTSCALE not present', () {
      // Create a simple DXF without $LTSCALE
      final dxfContent = '''0
SECTION
2
HEADER
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify default value is returned
      expect(doc.getLineTypeScale(), 1.0);
    });

    test('getMeasurementSystem returns value from \$MEASUREMENT header variable', () {
      // Create a simple DXF with $MEASUREMENT = 1 (Metric)
      final dxfContent = '''0
SECTION
2
HEADER
9
\$MEASUREMENT
70
1
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify the helper method extracts and parses the value correctly
      expect(doc.getMeasurementSystem(), 1);
    });

    test('getMeasurementSystem returns 1 (Metric) default when \$MEASUREMENT not present', () {
      // Create a simple DXF without $MEASUREMENT
      final dxfContent = '''0
SECTION
2
HEADER
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify default value is 1 (Metric)
      expect(doc.getMeasurementSystem(), 1);
    });

    test('getMeasurementSystem returns 0 for Imperial units', () {
      // Create a simple DXF with $MEASUREMENT = 0 (Imperial)
      final dxfContent = '''0
SECTION
2
HEADER
9
\$MEASUREMENT
70
0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify the helper method returns 0 for Imperial
      expect(doc.getMeasurementSystem(), 0);
    });

    test('All three helper methods work together with multiple header variables', () {
      // Create a DXF with all three header variables
      final dxfContent = '''0
SECTION
2
HEADER
9
\$DIMSCALE
40
2.0
9
\$LTSCALE
40
1.5
9
\$MEASUREMENT
70
1
9
\$INSUNITS
70
4
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify all helper methods work correctly
      expect(doc.getDimensionScale(), 2.0);
      expect(doc.getLineTypeScale(), 1.5);
      expect(doc.getMeasurementSystem(), 1);
      
      // Also verify direct access to headerVars
      expect(doc.headerVars['\$DIMSCALE'], '2.0');
      expect(doc.headerVars['\$LTSCALE'], '1.5');
      expect(doc.headerVars['\$MEASUREMENT'], '1');
      expect(doc.headerVars['\$INSUNITS'], '4');
    });

    test('Helper methods handle invalid numeric values gracefully', () {
      // Create a DXF with invalid numeric values
      final dxfContent = '''0
SECTION
2
HEADER
9
\$DIMSCALE
40
invalid
9
\$LTSCALE
40
not_a_number
9
\$MEASUREMENT
70
abc
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify helper methods return defaults for invalid values
      expect(doc.getDimensionScale(), 1.0);
      expect(doc.getLineTypeScale(), 1.0);
      expect(doc.getMeasurementSystem(), 1);
    });
  });

  group('Header Variable Extraction from Real Files', () {
    test('Verify headerVars map contains all header variables after parsing', () {
      // Create a comprehensive DXF with multiple header variables
      final dxfContent = '''0
SECTION
2
HEADER
9
\$ACADVER
1
AC1027
9
\$DIMSCALE
40
2.5
9
\$LTSCALE
40
1.0
9
\$MEASUREMENT
70
1
9
\$INSUNITS
70
6
9
\$DWGCODEPAGE
3
ANSI_1252
0
ENDSEC
0
SECTION
2
ENTITIES
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      
      // Verify all header variables are in the map
      expect(doc.headerVars.containsKey('\$ACADVER'), true);
      expect(doc.headerVars.containsKey('\$DIMSCALE'), true);
      expect(doc.headerVars.containsKey('\$LTSCALE'), true);
      expect(doc.headerVars.containsKey('\$MEASUREMENT'), true);
      expect(doc.headerVars.containsKey('\$INSUNITS'), true);
      expect(doc.headerVars.containsKey('\$DWGCODEPAGE'), true);
      
      // Verify values are stored correctly
      expect(doc.headerVars['\$ACADVER'], 'AC1027');
      expect(doc.headerVars['\$DIMSCALE'], '2.5');
      expect(doc.headerVars['\$LTSCALE'], '1.0');
      expect(doc.headerVars['\$MEASUREMENT'], '1');
      expect(doc.headerVars['\$INSUNITS'], '6');
      expect(doc.headerVars['\$DWGCODEPAGE'], 'ANSI_1252');
    });
  });
}
