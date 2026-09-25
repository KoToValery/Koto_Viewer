import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_reader.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_writer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';

void main() {
  group('ATTRIB and ATTDEF Engine Modernization Tests', () {
    test('1. ATTDEF in BLOCK is parsed as DxfAttdef and non-constant is excluded from static block geometry', () {
      const dxfContent = '''  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
ROOM_TAG
 10
0.0
 20
0.0
 30
0.0
  0
LINE
  8
0
 10
0.0
 20
0.0
 11
10.0
 21
0.0
  0
ATTDEF
  8
0
  1
DEFAULT_ROOM
  2
ROOM_NAME
  3
Enter room name:
 10
5.0
 20
2.0
 40
2.5
 70
0
  0
ATTDEF
  8
0
  1
CONST_CODE
  2
BLDG_CODE
 10
5.0
 20
-2.0
 40
2.0
 70
2
  0
ENDBLK
  0
ENDSEC
  0
EOF''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.blocks.containsKey('ROOM_TAG'), isTrue);
      final block = doc.blocks['ROOM_TAG']!;

      final attdefs = block.entities.whereType<DxfAttdef>().toList();
      expect(attdefs.length, equals(2));

      final roomNameDef = attdefs.firstWhere((a) => a.tag == 'ROOM_NAME');
      expect(roomNameDef.text, equals('DEFAULT_ROOM'));
      expect(roomNameDef.prompt, equals('Enter room name:'));
      expect(roomNameDef.isConstant, isFalse);
      expect(roomNameDef.isInvisible, isFalse);

      final bldgCodeDef = attdefs.firstWhere((a) => a.tag == 'BLDG_CODE');
      expect(bldgCodeDef.text, equals('CONST_CODE'));
      expect(bldgCodeDef.isConstant, isTrue);

      // Verify compiled block: non-constant ATTDEF must NOT be in compiled.otherEntities (no ghost/duplicate text)
      final compiled = block.compiled;
      final renderedTexts = compiled.otherEntities.whereType<DxfText>().toList();
      // Only the constant one should be converted to DxfText
      expect(renderedTexts.length, equals(1));
      expect(renderedTexts.first.text, equals('CONST_CODE'));
    });

    test('2. INSERT with code 66 == 1 consumes subsequent ATTRIB entities until SEQEND', () {
      const dxfContent = '''  0
SECTION
  2
BLOCKS
  0
BLOCK
  2
TITLE_BLOCK
 10
0.0
 20
0.0
  0
ENDBLK
  0
ENDSEC
  0
SECTION
  2
ENTITIES
  0
INSERT
  8
TITLE_LAYER
  2
TITLE_BLOCK
 66
1
 10
100.0
 20
200.0
 30
0.0
 67
1
410
Layout1
  0
ATTRIB
  8
0
  1
Architecture Plan
  2
SHEET_TITLE
 10
120.0
 20
210.0
 40
5.0
 70
0
  0
ATTRIB
  8
0
  1
A-101
  2
SHEET_NO
 10
180.0
 20
210.0
 40
5.0
 70
0
  0
ATTRIB
  8
0
  1
Internal GUID 12345
  2
ASSET_GUID
 10
0.0
 20
0.0
 70
1
  0
SEQEND
  0
LINE
  8
WALLS
 10
0.0
 20
0.0
 11
50.0
 21
50.0
  0
ENDSEC
  0
EOF''';

      final doc = DxfParser.parseString(dxfContent);

      final inserts = doc.entities.whereType<DxfInsert>().toList();
      expect(inserts.length, equals(1));
      final insert = inserts.first;

      expect(insert.blockName, equals('TITLE_BLOCK'));
      expect(insert.isPaperSpace, isTrue);
      expect(insert.layoutName, equals('Layout1'));

      // Check attributes attached to the DxfInsert
      expect(insert.attributes.length, equals(3));
      expect(insert.attributeMap['SHEET_TITLE'], equals('Architecture Plan'));
      expect(insert.attributeMap['SHEET_NO'], equals('A-101'));
      expect(insert.attributeMap['ASSET_GUID'], equals('Internal GUID 12345'));

      final titleAttr = insert.attributes.firstWhere((a) => a.tag == 'SHEET_TITLE');
      expect(titleAttr.isInvisible, isFalse);
      expect(titleAttr.textEntity, isNotNull);
      expect(titleAttr.textEntity!.isPaperSpace, isTrue); // Inherited from INSERT
      expect(titleAttr.textEntity!.layoutName, equals('Layout1'));
      expect(titleAttr.textEntity!.layer, equals('TITLE_LAYER')); // Inherited from INSERT when 0

      final guidAttr = insert.attributes.firstWhere((a) => a.tag == 'ASSET_GUID');
      expect(guidAttr.isInvisible, isTrue);

      // Verify that the subsequent LINE after SEQEND was parsed correctly
      final lines = doc.entities.whereType<DxfLine>().toList();
      expect(lines.length, equals(1));
      expect(lines.first.layer, equals('WALLS'));

      // Verify that visible attribute texts are added to entities list for rendering
      final texts = doc.entities.whereType<DxfText>().toList();
      expect(texts.length, equals(2)); // SHEET_TITLE and SHEET_NO (guid is invisible)
      expect(texts.any((t) => t.text == 'Architecture Plan'), isTrue);
      expect(texts.any((t) => t.text == 'A-101'), isTrue);
    });

    test('3. KCAD Binary Format: Round-trip serialization preserves DxfInsert attributes and DxfAttdef', () {
      final originalInsert = DxfInsert(
        blockName: 'DOOR_TAG',
        insertPoint: const Offset(50.0, 75.0),
        scaleX: 1.5,
        scaleY: 1.5,
        rotationDeg: 45.0,
        attributes: const [
          DxfAttribute(tag: 'DOOR_NO', value: 'D-05', isInvisible: false),
          DxfAttribute(tag: 'FIRE_RATING', value: 'EI60', isInvisible: true),
        ],
      );

      final originalAttdef = const DxfAttdef(
        tag: 'ELEVATION',
        text: '+0.00',
        prompt: 'Enter elevation:',
        insertPoint: Offset(10.0, 20.0),
        height: 3.0,
        flags: 2, // Constant
      );

      final originalDoc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {'DOOR_TAG': DxfBlock(name: 'DOOR_TAG')},
        entities: [originalInsert, originalAttdef],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: const {'INSERT': 1, 'ATTDEF': 1},
      );

      // Write to KCAD v5 binary
      final kcadBytes = KcadWriter.write(originalDoc, compress: false);

      // Read back from KCAD
      final loadedDoc = KcadReader.read(kcadBytes);

      final loadedInserts = loadedDoc.entities.whereType<DxfInsert>().toList();
      expect(loadedInserts.length, equals(1));
      final loadedInsert = loadedInserts.first;

      expect(loadedInsert.blockName, equals('DOOR_TAG'));
      expect(loadedInsert.insertPoint.dx, closeTo(50.0, 0.001));
      expect(loadedInsert.insertPoint.dy, closeTo(75.0, 0.001));
      expect(loadedInsert.scaleX, closeTo(1.5, 0.001));
      expect(loadedInsert.rotationDeg, closeTo(45.0, 0.001));

      expect(loadedInsert.attributes.length, equals(2));
      expect(loadedInsert.attributeMap['DOOR_NO'], equals('D-05'));
      expect(loadedInsert.attributeMap['FIRE_RATING'], equals('EI60'));

      final loadedNo = loadedInsert.attributes.firstWhere((a) => a.tag == 'DOOR_NO');
      expect(loadedNo.isInvisible, isFalse);

      final loadedFire = loadedInsert.attributes.firstWhere((a) => a.tag == 'FIRE_RATING');
      expect(loadedFire.isInvisible, isTrue);

      final loadedAttdefs = loadedDoc.entities.whereType<DxfAttdef>().toList();
      expect(loadedAttdefs.length, equals(1));
      expect(loadedAttdefs.first.tag, equals('ELEVATION'));
      expect(loadedAttdefs.first.text, equals('+0.00'));
      expect(loadedAttdefs.first.prompt, equals('Enter elevation:'));
      expect(loadedAttdefs.first.isConstant, isTrue);
    });
  });
}
