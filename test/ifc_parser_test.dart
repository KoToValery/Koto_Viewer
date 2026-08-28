import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/parser/ifc_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pure-Dart IFC (BIM) Parser & 3D Architectural Model Tests', () {
    const sampleIfc = r'''
ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('ViewDefinition [CoordinationView]'),'2;1');
FILE_NAME('Modern_Villa.ifc','2026-08-27T00:00:00',('Architect'),('Studio'),'Revit 2024','Windows','Auth');
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('0123456789ABCDEF012345',#2,'Modern Villa Residence',$,$,$,$,(#3),#4);
#10=IFCSITE('0123456789ABCDEF012346',$,'Site',$,$,#11,$,$,.ELEMENT.,$,$,$,$,$);
#20=IFCBUILDING('0123456789ABCDEF012347',$,'Main Building',$,$,#21,$,$,.ELEMENT.,$,$,$);

/* Storey 0: Ground Floor */
#30=IFCBUILDINGSTOREY('0123456789ABCDEF012348',$,'Ground Floor',$,$,#31,$,$,.ELEMENT.,0.0);
/* Storey 1: First Floor */
#40=IFCBUILDINGSTOREY('0123456789ABCDEF012349',$,'First Floor',$,$,#41,$,$,.ELEMENT.,3.2);

/* Placements */
#50=IFCCARTESIANPOINT((0.0, 0.0, 0.0));
#51=IFCDIRECTION((0.0, 0.0, 1.0));
#52=IFCDIRECTION((1.0, 0.0, 0.0));
#53=IFCAXIS2PLACEMENT3D(#50,#51,#52);
#54=IFCLOCALPLACEMENT($,#53);

/* Wall 1 on Ground Floor */
#100=IFCWALL('WALL_01_GUID',$,'Exterior North Wall',$,$,#54,#101,$);
#101=IFCPRODUCTDEFINITIONSHAPE($,$,(#102));
#102=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#103));
#103=IFCEXTRUDEDAREASOLID(#104,#53,#51,3.0);
#104=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,0.3,6.0);

/* Window 1 on Ground Floor */
#200=IFCWINDOW('WIN_01_GUID',$,'Living Room Window',$,$,#54,#201,$);
#201=IFCPRODUCTDEFINITIONSHAPE($,$,(#202));
#202=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#203));
#203=IFCEXTRUDEDAREASOLID(#204,#53,#51,1.5);
#204=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,0.1,1.8);

/* Furniture (Sofa) on Ground Floor */
#300=IFCFURNISHINGELEMENT('FURN_01_GUID',$,'L-Shape Sofa',$,$,#54,#301,$);
#301=IFCPRODUCTDEFINITIONSHAPE($,$,(#302));
#302=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#303));
#303=IFCEXTRUDEDAREASOLID(#304,#53,#51,0.85);
#304=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,1.2,2.4);

/* Slab on First Floor */
#400=IFCSLAB('SLAB_01_GUID',$,'First Floor Concrete Slab',$,$,#54,#401,$);
#401=IFCPRODUCTDEFINITIONSHAPE($,$,(#402));
#402=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#403));
#403=IFCEXTRUDEDAREASOLID(#404,#53,#51,0.25);
#404=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,8.0,10.0);

/* Relate elements to storeys */
#500=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL_01',$,$,$,(#100,#200,#300),#30);
#501=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL_02',$,$,$,(#400),#40);

ENDSEC;
END-ISO-10303-21;
''';

    test('Parses IFC header, schema, project name, and building storeys', () {
      final model = IfcParser.parseFromText(sampleIfc);

      expect(model.schema, 'IFC2X3');
      expect(model.projectName, 'Modern Villa Residence');
      expect(model.storeys.length, 2);

      expect(model.storeys[0].name, 'Ground Floor');
      expect(model.storeys[0].elevation, 0.0);

      expect(model.storeys[1].name, 'First Floor');
      expect(model.storeys[1].elevation, 3.2);
    });

    test('Parses building elements and identifies categories with architectural colors', () {
      final model = IfcParser.parseFromText(sampleIfc);

      expect(model.elements.length, 4);

      // Wall
      final wall = model.elements.firstWhere((e) => e.name == 'Exterior North Wall');
      expect(wall.category, 'Wall');
      expect(wall.storeyName, 'Ground Floor');
      expect(wall.color, const Color(0xFFE5E2DC));
      expect(wall.triangles.length, 12); // Extruded rectangle: 2 caps * 2 + 4 sides * 2 = 12 triangles

      // Window
      final window = model.elements.firstWhere((e) => e.name == 'Living Room Window');
      expect(window.category, 'Window');
      expect(window.storeyName, 'Ground Floor');
      expect(window.color, const Color(0x9972C4EE)); // Translucent glass

      // Furniture (explicitly requested by user)
      final sofa = model.elements.firstWhere((e) => e.name == 'L-Shape Sofa');
      expect(sofa.category, 'Furniture');
      expect(sofa.storeyName, 'Ground Floor');
      expect(sofa.color, const Color(0xFF4E7D96)); // Marine / Teal furniture

      // Slab
      final slab = model.elements.firstWhere((e) => e.name == 'First Floor Concrete Slab');
      expect(slab.category, 'Slab');
      expect(slab.storeyName, 'First Floor');
      expect(slab.color, const Color(0xFFB8BCC2)); // Concrete gray
    });

    test('Calculates watertight bounding boxes for extruded solids', () {
      final model = IfcParser.parseFromText(sampleIfc);
      final wall = model.elements.firstWhere((e) => e.name == 'Exterior North Wall');

      // Wall: width 0.3, depth 6.0, height 3.0
      expect(wall.bounds.sizeX, closeTo(0.3, 1e-4));
      expect(wall.bounds.sizeY, closeTo(6.0, 1e-4));
      expect(wall.bounds.sizeZ, closeTo(3.0, 1e-4));
    });

    test('Interactive Storey Filtering excludes triangles of hidden floors', () {
      final model = IfcParser.parseFromText(sampleIfc);
      final fullMesh = model.toMesh3D();
      final totalTris = fullMesh.triangles.length;

      // 4 elements * 12 triangles = 48
      expect(totalTris, 48);

      // Hide Ground Floor (should hide Wall, Window, Sofa)
      model.toggleStorey('Ground Floor', false);
      final firstFloorOnlyMesh = model.toMesh3D();
      expect(firstFloorOnlyMesh.triangles.length, 12); // only First Floor Slab remains

      // Restore all
      model.showAll();
      expect(model.toMesh3D().triangles.length, totalTris);
    });

    test('Interactive Category Filtering isolates or hides categories', () {
      final model = IfcParser.parseFromText(sampleIfc);

      // Isolate Furniture (only Sofa should be visible)
      model.isolateCategory('Furniture');
      final sofaOnlyMesh = model.toMesh3D();
      expect(sofaOnlyMesh.triangles.length, 12);

      // Show all again
      model.showAll();
      expect(model.toMesh3D().triangles.length, 48);

      // Hide Walls
      model.toggleCategory('Wall', false);
      final noWallsMesh = model.toMesh3D();
      expect(noWallsMesh.triangles.length, 36);
    });

    test('Background isolate parseFromFile successfully loads IFC file from disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('ifc_test_');
      final testFile = File('${tempDir.path}/villa.ifc');
      await testFile.writeAsString(sampleIfc);

      final model = await IfcParser.parseFromFile(testFile.path);

      expect(model.projectName, 'Modern Villa Residence');
      expect(model.elements.length, 4);
      expect(model.categories, containsAll(['Wall', 'Window', 'Furniture', 'Slab']));

      await tempDir.delete(recursive: true);
    });

    test('Decodes ISO-10303-21 Cyrillic escape sequences from Revit and ArchiCAD', () {
      // \X2\041F04300440044204350440\X0\ -> Партер (Ground floor in BG)
      expect(IfcParser.decodeIfcString(r'\X2\041F04300440044204350440\X0\'), 'Партер');

      // \X2\041504420430043600200031\X0\ -> Етаж 1
      expect(IfcParser.decodeIfcString(r'\X2\041504420430043600200031\X0\'), 'Етаж 1');

      // \X2\041004200425002D042104220415041D0418\X0\ -> АРХ-СТЕНИ (ArchiCAD layer)
      expect(IfcParser.decodeIfcString(r'\X2\041004200425002D042104220415041D0418\X0\'), 'АРХ-СТЕНИ');
    });

    test('Parses IFC with Cyrillic Storeys, Elements, and ArchiCAD Presentation Layers', () {
      const cyrillicIfc = r'''
ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('ViewDefinition [CoordinationView]'),'2;1');
FILE_NAME('Сграда_София.ifc','2026-08-27T00:00:00',('Архитект'),('Студио'),'ArchiCAD 27','Windows','Auth');
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('GUID_PROJ',#2,'\X2\04160438043B04380449043D04300020042104330440043004340430\X0\',$,$,$,$,(#3),#4);
#10=IFCBUILDINGSTOREY('GUID_S0',$,'\X2\041F04300440044204350440\X0\',$,$,#11,$,$,.ELEMENT.,0.0);

#50=IFCCARTESIANPOINT((0.0, 0.0, 0.0));
#51=IFCDIRECTION((0.0, 0.0, 1.0));
#52=IFCDIRECTION((1.0, 0.0, 0.0));
#53=IFCAXIS2PLACEMENT3D(#50,#51,#52);
#54=IFCLOCALPLACEMENT($,#53);

/* Wall with Cyrillic name */
#100=IFCWALL('W1',$,'\X2\041D043E04410435044904300020044104420435043D0430\X0\',$,$,#54,#101,$);
#101=IFCPRODUCTDEFINITIONSHAPE($,$,(#102));
#102=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#103));
#103=IFCEXTRUDEDAREASOLID(#104,#53,#51,2.8);
#104=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,0.25,5.0);

/* Furniture with UTF-8 Cyrillic name */
#200=IFCFURNISHINGELEMENT('F1',$,'Офис бюро',$,$,#54,#201,$);
#201=IFCPRODUCTDEFINITIONSHAPE($,$,(#202));
#202=IFCSHAPEREPRESENTATION(#4,'Body','SweptSolid',(#203));
#203=IFCEXTRUDEDAREASOLID(#204,#53,#51,0.75);
#204=IFCRECTANGLEPROFILEDEF(.AREA.,$,#53,0.8,1.6);

#300=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL_1',$,$,$,(#100,#200),#10);

/* ArchiCAD Presentation Layer assignments in Cyrillic */
#400=IFCPRESENTATIONLAYERASSIGNMENT('\X2\041004200425002D042104220415041D0418\X0\',$,(#100),$);
#401=IFCPRESENTATIONLAYERASSIGNMENT('ИНТЕРИОР - МЕБЕЛИ',$,(#200),$);
ENDSEC;
END-ISO-10303-21;
''';

      final model = IfcParser.parseFromText(cyrillicIfc);

      expect(model.projectName, 'Жилищна Сграда');
      expect(model.storeys.first.name, 'Партер');
      expect(model.elements.length, 2);

      final wall = model.elements.firstWhere((e) => e.category == 'Wall');
      expect(wall.name, 'Носеща стена');
      expect(wall.layer, 'АРХ-СТЕНИ');

      final furniture = model.elements.firstWhere((e) => e.category == 'Furniture');
      expect(furniture.name, 'Офис бюро');
      expect(furniture.layer, 'ИНТЕРИОР - МЕБЕЛИ');

      expect(model.layers, containsAll(['АРХ-СТЕНИ', 'ИНТЕРИОР - МЕБЕЛИ']));

      // Test layer isolation
      model.isolateLayer('ИНТЕРИОР - МЕБЕЛИ');
      final furnitureOnlyMesh = model.toMesh3D();
      expect(furnitureOnlyMesh.triangles.length, 12); // only furniture visible
    });

    test('Parses Archicad IFC with trailing dot numbers (0., 6000., 4000., 2800.) in full 3D dimensions (X, Y, Z > 0)', () {
      const archicadTrailingDotsIfc = '''
ISO-10303-21;
HEADER;
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('guid_p',\$,'Archicad Building',\$,\$,\$,\$,(#2),#3);
#2=IFCBUILDING('guid_b',\$,'Building',\$,\$,\$,\$,\$,.ELEMENT.,\$,\$,\$);
#3=IFCBUILDINGSTOREY('guid_s',\$,'Floor 1',\$,\$,#14,\$,\$,.ELEMENT.,0.);
#10=IFCCARTESIANPOINT((0., 0., 0.));
#11=IFCDIRECTION((0., 0., 1.));
#12=IFCDIRECTION((1., 0., 0.));
#13=IFCAXIS2PLACEMENT3D(#10,#11,#12);
#14=IFCLOCALPLACEMENT(\$,#13);

/* 2D profile points with Archicad trailing dots */
#20=IFCCARTESIANPOINT((0., 0.));
#21=IFCCARTESIANPOINT((6000., 0.));
#22=IFCCARTESIANPOINT((6000., 4000.));
#23=IFCCARTESIANPOINT((0., 4000.));
#25=IFCPOLYLINE((#20,#21,#22,#23,#20));
#30=IFCARBITRARYCLOSEDPROFILEDEF(.AREA.,\$,#25);
#40=IFCDIRECTION((0., 0., 1.));
#41=IFCAXIS2PLACEMENT3D(#10,#11,#12);
#50=IFCEXTRUDEDAREASOLID(#30,#41,#40,2800.);
#60=IFCSHAPEREPRESENTATION(#1,'Body','SweptSolid',(#50));
#70=IFCPRODUCTDEFINITIONSHAPE(\$,\$,(#60));
#80=IFCWALL('W_ARCH',\$,'Archicad Real Wall',\$,\$,#14,#70,\$);
#90=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL_A',\$,\$,\$,(#80),#3);
ENDSEC;
END-ISO-10303-21;
''';

      final model = IfcParser.parseFromText(archicadTrailingDotsIfc);
      final mesh = model.toMesh3D();

      expect(mesh.triangleCount, greaterThan(0));
      // Ensure the model is truly 3D and NOT collapsed to 1 dimension:
      expect(mesh.bounds.sizeX, closeTo(6000.0, 1.0));
      expect(mesh.bounds.sizeY, closeTo(4000.0, 1.0));
      expect(mesh.bounds.sizeZ, closeTo(2800.0, 1.0));
    });

    test('Parses Archicad layer assignments via shape representation and populates non-zero layerCounts', () {
      const archicadLayersIfc = '''
ISO-10303-21;
HEADER;
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('guid_p',\$,'Archicad Project',\$,\$,\$,\$,(#2),#3);
#2=IFCBUILDING('guid_b',\$,'Building',\$,\$,\$,\$,\$,.ELEMENT.,\$,\$,\$);
#3=IFCBUILDINGSTOREY('guid_s',\$,'0.00',\$,\$,#14,\$,\$,.ELEMENT.,0.);
#10=IFCCARTESIANPOINT((0., 0., 0.));
#11=IFCDIRECTION((0., 0., 1.));
#12=IFCDIRECTION((1., 0., 0.));
#13=IFCAXIS2PLACEMENT3D(#10,#11,#12);
#14=IFCLOCALPLACEMENT(\$,#13);

/* Column 1 */
#100=IFCCOLUMN('COL_1',\$,'Колона К1',\$,\$,#14,#101,\$);
#101=IFCPRODUCTDEFINITIONSHAPE(\$,\$,(#102));
#102=IFCSHAPEREPRESENTATION(#1,'Body','SweptSolid',(#103));
#103=IFCEXTRUDEDAREASOLID(#104,#13,#11,2800.);
#104=IFCRECTANGLEPROFILEDEF(.AREA.,\$,#13,400.,400.);

/* Slab 1 */
#200=IFCSLAB('SLAB_1',\$,'Плоча П1',\$,\$,#14,#201,\$);
#201=IFCPRODUCTDEFINITIONSHAPE(\$,\$,(#202));
#202=IFCSHAPEREPRESENTATION(#1,'Body','SweptSolid',(#203));
#203=IFCEXTRUDEDAREASOLID(#204,#13,#11,200.);
#204=IFCRECTANGLEPROFILEDEF(.AREA.,\$,#13,6000.,8000.);

#300=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL',\$,\$,\$,(#100,#200),#3);

/* Archicad assigns layers to the IfcShapeRepresentation (#102, #202), not the IfcProduct (#100, #200) */
#400=IFCPRESENTATIONLAYERASSIGNMENT('колони',\$,(#102),\$);
#401=IFCPRESENTATIONLAYERASSIGNMENT('плочи',\$,(#202),\$);
ENDSEC;
END-ISO-10303-21;
''';

      final model = IfcParser.parseFromText(archicadLayersIfc);

      expect(model.elements.length, 2);
      final col = model.elements.firstWhere((e) => e.name == 'Колона К1');
      expect(col.layer, 'колони');

      final slab = model.elements.firstWhere((e) => e.name == 'Плоча П1');
      expect(slab.layer, 'плочи');

      // Verify layerCounts has non-zero element count:
      expect(model.layerCounts['колони'], 1);
      expect(model.layerCounts['плочи'], 1);

      // Verify storey element count is also non-zero:
      expect(model.storeyCounts['0.00'], 2);
    });

    test('Parses IFCPRESENTATIONLAYERWITHSTYLE and automatically hides layers marked with LayerOn=.F.', () {
      const hiddenLayerIfc = '''
ISO-10303-21;
HEADER;
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('guid_p',\$,'Archicad Project',\$,\$,\$,\$,(#2),#3);
#2=IFCBUILDING('guid_b',\$,'Building',\$,\$,\$,\$,\$,.ELEMENT.,\$,\$,\$);
#3=IFCBUILDINGSTOREY('guid_s',\$,'0.00',\$,\$,#14,\$,\$,.ELEMENT.,0.);
#10=IFCCARTESIANPOINT((0., 0., 0.));
#11=IFCDIRECTION((0., 0., 1.));
#12=IFCDIRECTION((1., 0., 0.));
#13=IFCAXIS2PLACEMENT3D(#10,#11,#12);
#14=IFCLOCALPLACEMENT(\$,#13);

/* Visible Wall */
#100=IFCWALL('WALL_1',\$,'Visible Wall',\$,\$,#14,#101,\$);
#101=IFCPRODUCTDEFINITIONSHAPE(\$,\$,(#102));
#102=IFCSHAPEREPRESENTATION(#1,'Body','SweptSolid',(#103));
#103=IFCEXTRUDEDAREASOLID(#104,#13,#11,2800.);
#104=IFCRECTANGLEPROFILEDEF(.AREA.,\$,#13,400.,400.);

/* Hidden Furniture */
#200=IFCFURNISHINGELEMENT('FURN_1',\$,'Hidden Chair',\$,\$,#14,#201,\$);
#201=IFCPRODUCTDEFINITIONSHAPE(\$,\$,(#202));
#202=IFCSHAPEREPRESENTATION(#1,'Body','SweptSolid',(#203));
#203=IFCEXTRUDEDAREASOLID(#204,#13,#11,800.);
#204=IFCRECTANGLEPROFILEDEF(.AREA.,\$,#13,500.,500.);

#300=IFCRELCONTAINEDINSPATIALSTRUCTURE('REL',\$,\$,\$,(#100,#200),#3);

/* Layer assignments: Visible Wall layer is ON (.T.), Furniture layer is OFF (.F.) */
#400=IFCPRESENTATIONLAYERWITHSTYLE('Стени',\$,(#102),\$,.T.,.F.,.F.,\$);
#401=IFCPRESENTATIONLAYERWITHSTYLE('Мебели - Скрити',\$,(#202),\$,.F.,.F.,.F.,\$);
ENDSEC;
END-ISO-10303-21;
''';

      final model = IfcParser.parseFromText(hiddenLayerIfc);

      expect(model.hiddenLayers.contains('Мебели - Скрити'), isTrue);
      expect(model.hiddenLayers.contains('Стени'), isFalse);

      final mesh = model.toMesh3D();
      // Only the visible wall triangles should be present:
      final wall = model.elements.firstWhere((e) => e.name == 'Visible Wall');
      expect(mesh.triangleCount, wall.triangles.length);
    });
  });
}
