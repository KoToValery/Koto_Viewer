import 'dart:ui';
import '../../bim_editing/interaction/bim_polygon_editor.dart';
import '../rendering/architect_snap_helper.dart';
export '../../bim_editing/interaction/bim_polygon_editor.dart';

class ArchitectPolygonEditor extends BimPolygonEditor<ArchitectSnapResult> {
  ArchitectPolygonEditor()
    : super(pointOf: (snap) => snap.point, isSnapped: (snap) => snap.isSnapped);
  static Offset vertexNormal(List<Offset> polygon, int i) =>
      BimPolygonEditor.vertexNormal(polygon, i);
  static Offset offsetVertexHandle(List<Offset> polygon, int i, double scale) =>
      BimPolygonEditor.offsetVertexHandle(polygon, i, scale);
  static Offset offsetEdgeHandle(List<Offset> polygon, int i, double scale) =>
      BimPolygonEditor.offsetEdgeHandle(polygon, i, scale);
}
