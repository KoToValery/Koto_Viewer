import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'dart:typed_data';
import '../lib/src/features/dxf_3d_viewer/parser/three_mf_parser.dart';
import '../lib/src/features/dxf_3d_viewer/models/mesh_3d.dart';

void main() {
  test('Parses 3MF file correctly from bytes', () {
    // Create a mock 3dmodel.model XML content
    const xmlContent = '''
<model>
  <resources>
    <object id="1" type="model">
      <mesh>
        <vertices>
          <vertex x="0" y="0" z="0"/>
          <vertex x="1" y="0" z="0"/>
          <vertex x="0" y="1" z="0"/>
          <vertex x="0" y="0" z="1"/>
        </vertices>
        <triangles>
          <triangle v1="0" v2="1" v3="2"/>
          <triangle v1="0" v2="2" v3="3"/>
        </triangles>
      </mesh>
    </object>
  </resources>
</model>
''';

    // Create a ZIP archive in memory
    final archive = Archive();
    final file = ArchiveFile('3D/3dmodel.model', xmlContent.length, xmlContent.codeUnits);
    archive.addFile(file);
    final List<int>? zipData = ZipEncoder().encode(archive);
    
    expect(zipData, isNotNull);
    
    final Uint8List bytes = Uint8List.fromList(zipData!);

    // Parse the bytes
    final Mesh3D mesh = ThreeMfParser.parseFromBytes(bytes);

    // Verify the results
    expect(mesh, isNotNull);
    expect(mesh.triangles, isNotEmpty);
    expect(mesh.triangles.length, equals(2));
    
    // Verify bounding box
    final bounds = mesh.bounds;
    expect(bounds.sizeX, greaterThan(0));
    expect(bounds.sizeY, greaterThan(0));
    expect(bounds.sizeZ, greaterThan(0));
    
    expect(bounds.min.x, equals(0));
    expect(bounds.max.x, equals(1));
    expect(bounds.min.y, equals(0));
    expect(bounds.max.y, equals(1));
    expect(bounds.min.z, equals(0));
    expect(bounds.max.z, equals(1));
  });
}
