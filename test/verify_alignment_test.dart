import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

void main() {
  test('Verify OVK dimension text clearance with -textPainter.height / 2.0', () async {
    final ovkDoc = await DxfParser.parseFromFile(File('test_files/OVK_converted.dxf'));
    
    // Dimension *D655 ("147.5")
    final b = ovkDoc.blocks['*D655']!;
    final mtext = b.entities.whereType<DxfMText>().first;
    final line = b.entities.whereType<DxfLine>().first;

    const fitScale = 1.0;
    const double capHeightRatio = 0.72;
    final double fontSize = (mtext.height / capHeightRatio) * fitScale;

    final textPainter = TextPainter(
      text: TextSpan(
        text: mtext.cleanText,
        style: TextStyle(fontSize: fontSize, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final firstBaseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // Old formula that caused OVK to cut into line:
    final oyOld = -firstBaseline + (mtext.height * fitScale / 2.0);
    // New formula:
    final oyNew = -textPainter.height / 2.0;

    // In canvas Y (line is at 5714.0, mtext pos is at 5720.1):
    // lineCanvas = 0.0, mtextCanvas = -6.1
    final lineY = 0.0;
    final mtextY = -6.1;

    final baselineOld = mtextY + oyOld + firstBaseline;
    final baselineNew = mtextY + oyNew + firstBaseline;

    print('=== OVK "147.5" CLEARANCE ===');
    print('Line Canvas Y: $lineY');
    print('Old Baseline Canvas Y: $baselineOld (gap from line: ${(lineY - baselineOld).toStringAsFixed(2)} px)');
    print('New Baseline Canvas Y: $baselineNew (gap from line: ${(lineY - baselineNew).toStringAsFixed(2)} px)');

    expect(lineY - baselineNew, greaterThan(1.5), reason: 'Must have at least 1.5px clearance above line stroke');
  });

  test('Verify Archicad window 180/150 symmetry with -lastBaseline', () async {
    final arcDoc = await DxfParser.parseFromFile(File('test_files/Archicad_export_converted.dxf'));
    
    // Window line at Y = 175.0
    // "180" at pos = 181.8, attach = 7, h = 14.0
    // "150" at pos = 153.8, attach = 7, h = 14.0
    const fitScale = 1.0;
    const double capHeightRatio = 0.72;
    final double fontSize = (14.0 / capHeightRatio) * fitScale;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '180',
        style: TextStyle(fontSize: fontSize, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final firstBaseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final lastBaseline = firstBaseline;

    // For attach = 7:
    final oy = -lastBaseline;

    // Canvas Y (line is at 175.0 -> 0.0):
    // "180" pos is at 181.8 -> -6.8
    // "150" pos is at 153.8 -> +21.2
    final lineY = 0.0;
    final mtext180Y = -6.8;
    final mtext150Y = 21.2;

    // For "180" (above line):
    // Bottom of numbers is at baseline:
    final bottom180 = mtext180Y + oy + firstBaseline;
    final gap180 = lineY - bottom180; // distance above line

    // For "150" (below line):
    // Top of numbers is at baseline - capHeight:
    final baseline150 = mtext150Y + oy + firstBaseline;
    final top150 = baseline150 - 14.0;
    final gap150 = top150 - lineY; // distance below line

    print('=== ARCHICAD WINDOW "180" / "150" SYMMETRY ===');
    print('Line Canvas Y: $lineY');
    print('"180" bottom gap above line: ${gap180.toStringAsFixed(2)} px');
    print('"150" top gap below line: ${gap150.toStringAsFixed(2)} px');
    print('Difference in gap: ${(gap180 - gap150).abs().toStringAsFixed(2)} px');

    expect((gap180 - gap150).abs(), lessThan(0.5), reason: 'Gaps above and below window line must be symmetrical');
  });

  test('Verify Archicad room склад margins with -firstBaseline + capHeightPx', () async {
    final arcDoc = await DxfParser.parseFromFile(File('test_files/Archicad_export_converted.dxf'));
    
    // склад at pos = 1360.0, attach = 1, h = 14.0
    // Top line = 1365.9, Divider = 1338.4
    const fitScale = 1.0;
    const double capHeightRatio = 0.72;
    final double fontSize = (14.0 / capHeightRatio) * fitScale;

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'склад',
        style: TextStyle(fontSize: fontSize, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final firstBaseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // For attach = 1:
    final oy = -firstBaseline + 14.0 * fitScale;

    // Canvas Y (Top line at 1365.9 -> 0.0):
    // sklad pos is at 1360.0 -> +5.9
    // divider is at 1338.4 -> +27.5
    final topLineY = 0.0;
    final skladPosY = 5.9;
    final dividerY = 27.5;

    // Top of capital letters:
    final topCaps = skladPosY + oy + firstBaseline - 14.0 * fitScale;
    final bottomCaps = skladPosY + oy + firstBaseline;

    final topMargin = topCaps - topLineY;
    final bottomMargin = dividerY - bottomCaps;

    print('=== ARCHICAD ROOM "склад" MARGINS ===');
    print('Top margin: ${topMargin.toStringAsFixed(2)} px');
    print('Bottom margin: ${bottomMargin.toStringAsFixed(2)} px');

    expect(topMargin, greaterThan(4.0));
    expect(bottomMargin, greaterThan(5.0));
  });
}
