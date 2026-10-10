import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/analysis/wall_axis_detector.dart';
import '../../structural_designer/analysis/geometric_window_detector.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/models/wall_axis_models.dart';
import '../models/bim_work_project.dart';
import 'bim_underlay_loader.dart';
import 'bim_underlay_conversion_service.dart';

/// Text representation of the same aligned detection inputs used by the screen.
/// Saved structural geometry is authoritative; inferred architecture is labelled.
class BimAnalysisSnapshot {
  static Map<String, Object?> build({
    required BimWorkProject project,
    required StructuralProject structural,
    required Map<String, DxfDocument> rawDocuments,
    required LoadedBimUnderlays aligned,
    required String unitsSource,
    required List<Map<String, Object?>> warnings,
  }) {
    List<double> point(Offset p) => [p.dx, p.dy];
    Map<String, Object?> segment(WallSegment s) => {
      'start': point(s.start),
      'end': point(s.end),
      'angleRad': s.angleRad,
      'offsetFromOrigin': s.offsetFromOrigin,
      'length': s.length,
      'sourceLayer': s.sourceLayer,
      'sourceColorIndex': s.sourceColorIndex,
      'sourceTrueColor': s.sourceTrueColor,
      'lineweight': s.lineweight,
    };
    final floors = <Map<String, Object?>>[];
    for (final s in project.storeys) {
      final raw = rawDocuments[s.storeyId],
          doc = aligned.underlaysByStorey[s.storeyId];
      double? sourceUnits, scale;
      Offset? translation;
      if (raw != null) {
        sourceUnits = BimUnderlayLoader.computeUnitsPerMeter(raw, raw.bounds);
        scale = aligned.cadUnitsPerMeter / sourceUnits;
        translation = s.controlPoint == null
            ? Offset.zero
            : aligned.referenceControlPoint - s.controlPoint! * scale;
        if (s.controlPoint == null) {
          warnings.add({
            'code': 'controlPointMissing',
            'storeyId': s.storeyId,
            'message': 'No storey control point; underlay translation is zero.',
          });
        }
        if (raw.unit == DxfUnit.unitless) {
          warnings.add({
            'code': 'sourceUnitsInferred',
            'storeyId': s.storeyId,
            'message': 'Source units were inferred from drawing bounds.',
          });
        }
      }
      final detection = doc == null
          ? WallAxisDetectionResult.empty
          : WallAxisDetector.detect(
              doc,
              forceScaleFactor: aligned.cadUnitsPerMeter / 1000,
            );
      final openings = doc == null
          ? <GeometricWindowOpening>[]
          : GeometricWindowDetector.detect(
              doc,
              detection.selectedWallPairs,
              aligned.cadUnitsPerMeter / 1000,
            );
      if (doc == null) {
        warnings.add({
          'code': 'underlayMissing',
          'storeyId': s.storeyId,
          'message': 'No architectural underlay is attached.',
        });
      } else if (detection.selectedWallPairs.isEmpty) {
        warnings.add({
          'code': 'wallCandidatesEmpty',
          'storeyId': s.storeyId,
          'message':
              'No wall-pair candidates detected; inspect architecture before generating supports.',
        });
      }
      final model = structural.storeys.firstWhere((f) => f.id == s.storeyId);
      floors.add({
        'storeyId': s.storeyId,
        'elevationM': s.elevation,
        'heightM': structural.resolveCeilingStorey(model).height,
        'underlayPath': s.underlayFileName,
        'geometryStatus': doc == null ? 'noUnderlay' : 'detected',
        'sourceCadUnitsPerMeter': sourceUnits,
        'sourceToProject': scale == null
            ? null
            : {'scale': scale, 'translation': point(translation!)},
        'sourceMetadata': raw == null ? null : BimUnderlayMetadata.read(raw),
        'sourceMetadataCoordinateSpace':
            'sourceCAD (including axes and inferred slab contours)',
        'placementInputs': {
          'coordinateSpace': 'projectCAD',
          'wallPairs': [
            for (final w in detection.selectedWallPairs)
              {
                'segmentA': segment(w.segmentA),
                'segmentB': segment(w.segmentB),
                'perpendicularDistance': w.perpendicularDistance,
                'overlapLength': w.overlapLength,
                'centerlineStart': point(w.centerlineStart),
                'centerlineEnd': point(w.centerlineEnd),
              },
          ],
          'wallOpenings': [
            for (final o in openings)
              {
                ...o.toJson(),
                'barrierPolygon': o.barrierPolygon.map(point).toList(),
              },
          ],
          'wallContourSegments': [
            for (final e in detection.wallContourSegments)
              [point(e.$1), point(e.$2)],
          ],
          'closureSegments': [
            for (final e in detection.closureSegments)
              [point(e.$1), point(e.$2)],
          ],
        },
        'layers': doc == null
            ? []
            : [
                for (final l in doc.layers.values)
                  {'name': l.name, 'visible': l.isVisible},
              ],
        'elementCounts': {
          'columns': model.columns.length,
          'shearWalls': model.shearWalls.length,
          'beams': model.beams.length,
          'ownedSlabs': model.slabs.length,
          'floorOwnedSlabs': model.slabs.where((s) => s.isFloorSlab).length,
          'ceilingSlabs': model.slabs.where((s) => !s.isFloorSlab).length,
        },
      });
    }
    return {
      'schemaVersion': 1,
      'structuralModelPath': 'structural.json',
      'projectFrame': {
        'cadUnitsPerMeter': aligned.cadUnitsPerMeter,
        'origin': point(aligned.referenceControlPoint),
        'unitsSource': unitsSource,
      },
      'units': {
        'pointsAndSupportSections': 'project CAD units',
        'slabThicknessAndElevations': 'metres',
        'angles': 'radians',
        'surfaceLoads': 'kN/m2',
        'facadeWallLoad': 'kN/m',
        'concreteE': 'MPa',
      },
      'sourceToProjectFormula':
          'projectPoint = sourcePoint * scale + translation',
      'projectToMetresFormula':
          'metrePoint = (projectPoint - projectFrame.origin) / projectFrame.cadUnitsPerMeter',
      'slabOwnership':
          'BIM slabs belong to the floor where they were created (isFloorSlab=true). Lower-storey plans can show them as ceiling references. Legacy isFloorSlab=false objects are ceiling-owned. Do not double-count references.',
      'gridAxes': structural.effectiveGridAxes.map((a) => a.toJson()).toList(),
      'detection':
          'WallAxisDetector and GeometricWindowDetector, with forced project CAD units per millimetre, matching the initial-scheme screen.',
      'generationSettings': null,
      'generationSettingsNote':
          'Dialog settings and transient unaccepted proposals are not persisted. The accepted saved model is preserved in structural.json.',
      'storeys': floors,
      'warnings': warnings,
    };
  }

  static const readme = """# Koto BIM — пакет за анализ / Analysis package

Започнете с package.json, structural.json и analysis.json. Всички JSON файлове са UTF-8.

- structural.json е пълният авторитетен модел: етажи, плочи, типизирани отвори, колони, шайби, греди, оси, материали и зададени товари. Файлът *_model.bim.json е негово съвместимо копие.
- project.json описва етажите, подложките и подравняването; пътищата са относителни към корена на ZIP.
- analysis.json съдържа явни единици, координатна система, трансформации и детектирани стенни кандидати/архитектурни отвори в четим вид. Приетите плочи и отвори се четат от structural.json. sourceMetadata съдържа предположенията от подложката и е в нейните локални CAD координати.
- package.json свързва етажите с DXF файловете и описва всеки файл чрез размер и SHA-256. Не включва собствена контролна сума.
- underlays/ и другите посочени относителни пътища пазят оригиналните и обработените подложки. KCAD е бинарният формат на приложението; за алгоритъма използвайте четимите JSON входове.
- DXF чертежите са производни изгледи в локалните координати на съответната подложка. Те може да показват и подова плоча от долния етаж: не я броете повторно в товарите.

Координати и размери на опорите: CAD единици на проекта. Дебелини на плочи, височини и коти: метри. Товари: kN/m² или kN/m, модул на бетона: MPa, ъгли на модела: радиани.
projectPoint = sourcePoint * scale + translation
metrePoint = (projectPoint - projectFrame.origin) / projectFrame.cadUnitsPerMeter

warnings посочва липсваща архитектура, неподтвърдено подравняване, предположени единици или недостъпен производен DXF. KCAD подложка без оригинален DXF запазва модела, източниците и JSON геометрията, но може да няма производен DXF. Проверете тези записи преди инженерно сравнение. Не е необходимо DWG/KCAD да бъде отворен за прочитане на входните данни на генератора.

Настройките на диалога и неприетият предварителен вариант не се пазят от приложението и не са включени. Записаните елементи се запазват без промяна. Не променяйте structural.json чрез копиране на предположените контури от sourceMetadata; това са различни данни.

English: structural.json is the authoritative accepted model; analysis.json exposes aligned placement inputs and explicit mixed units. sourceMetadata stays in source CAD coordinates. Paths are package-relative. Check warnings and hashes in package.json. Transient generation settings are not persisted; this package records the accepted model and a fresh detection snapshot, not an exact replay of an unaccepted dialog preview.
""";
}
