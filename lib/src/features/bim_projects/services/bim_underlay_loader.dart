import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_quadtree.dart';
import 'bim_underlay_conversion_service.dart';
import '../../structural_designer/analysis/structural_underlay_filter.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';
import 'dxf_document_transformer.dart';

/// Container for all parsed and aligned floor underlays of a BiM project.
class LoadedBimUnderlays {
  final Map<String, DxfDocument> underlaysByStorey;
  final Rect projectBounds;
  final Offset referenceControlPoint;
  final double cadUnitsPerMeter;

  const LoadedBimUnderlays({
    required this.underlaysByStorey,
    required this.projectBounds,
    required this.referenceControlPoint,
    required this.cadUnitsPerMeter,
  });
}

/// Service that parses, scales, aligns, and configures all floor underlays
/// for a BiM work project into a common project coordinate space.
class BimUnderlayLoader {
  /// Computes the CAD units per meter factor for a document and its bounding box.
  static double computeUnitsPerMeter(DxfDocument doc, Rect bounds) {
    final unit = doc.unit;
    if (unit != DxfUnit.unitless && unit.toMeters > 0) {
      return 1.0 / unit.toMeters;
    }
    final maxDim = math.max(bounds.width, bounds.height);
    if (maxDim > 500.0) {
      return 1000.0; // millimeters
    } else if (maxDim > 60.0) {
      return 100.0; // centimeters
    }
    return 1.0; // meters
  }

  /// Loads and aligns all underlay files defined in [project].
  static Future<LoadedBimUnderlays> loadAndAlign({
    required BimWorkProject project,
    BimProjectLibraryService? libraryService,
    bool isBulgarian = true,
  }) async {
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final rawDocs = <String, DxfDocument>{};

    project = await lib.prepareUnderlays(project, loadedDocuments: rawDocs);
    return alignDocuments(project: project, rawDocuments: rawDocs);
  }

  /// Read-only alignment of an already captured revision, also used by export.
  /// Unlike loadAndAlign this does not migrate or publish library files.
  static LoadedBimUnderlays alignDocuments({
    required BimWorkProject project,
    required Map<String, DxfDocument> rawDocuments,
  }) {
    final rawDocs = rawDocuments;
    if (rawDocs.isEmpty) {
      const defaultBounds = Rect.fromLTWH(0, 0, 100, 100);
      return LoadedBimUnderlays(
        underlaysByStorey: const {},
        projectBounds: defaultBounds,
        referenceControlPoint: project.structuralOrigin ?? Offset.zero,
        cadUnitsPerMeter: project.structuralUnitsPerMeter ?? 1.0,
      );
    }

    // 2. Identify reference storey & reference control point
    final refStorey = project.referenceStorey;
    final refDoc =
        (refStorey != null && rawDocs.containsKey(refStorey.storeyId))
        ? rawDocs[refStorey.storeyId]!
        : rawDocs.values.first;

    final refUnitsPerMeter =
        project.structuralUnitsPerMeter ??
        computeUnitsPerMeter(refDoc, refDoc.bounds);
    final refCp =
        project.structuralOrigin ??
        ((refStorey != null && refStorey.controlPoint != null)
            ? refStorey.controlPoint!
            : (refDoc.bounds.center));

    // 3. First pass: determine scales and translations, find combined bounds
    final transformedDocs = <String, DxfDocument>{};
    Rect? combinedBounds;

    for (final storey in project.storeys) {
      final doc = rawDocs[storey.storeyId];
      if (doc == null) continue;

      // Determine unit scale factor
      final currentUnitsPerMeter = computeUnitsPerMeter(doc, doc.bounds);
      double scale = 1.0;
      if (currentUnitsPerMeter > 0 && refUnitsPerMeter > 0) {
        scale = refUnitsPerMeter / currentUnitsPerMeter;
      }

      // Determine translation vector: T = refCp - (cp * scale)
      Offset translation = Offset.zero;
      if (storey.controlPoint != null) {
        final scaledCp = storey.controlPoint! * scale;
        translation = refCp - scaledCp;
      }

      final transformed = DxfDocumentTransformer.transform(
        doc,
        translation: translation,
        scale: scale,
      );

      // Restore layer visibility if saved; if not saved yet (initial startup),
      // apply automatic underlay filter to all storeys so every layout starts filtered!
      if (storey.layerVisibility.isNotEmpty) {
        for (final entry in storey.layerVisibility.entries) {
          if (transformed.layers.containsKey(entry.key)) {
            transformed.layers[entry.key]!.isVisible = entry.value;
          }
        }
      } else if (BimUnderlayMetadata.read(transformed) == null) {
        // Initial start: apply automatic filtering to all floor layouts
        final visibleLayerNames = StructuralUnderlayFilter.filterLayers(
          layers: transformed.layers.values,
          entities: transformed.entities,
          blocks: transformed.blocks,
        );
        if (visibleLayerNames.isNotEmpty) {
          for (final layer in transformed.layers.values) {
            layer.isVisible = visibleLayerNames.contains(layer.name);
          }
        }
      } else {
        BimUnderlayMetadata.setFiltered(transformed, true);
      }

      final metadata = BimUnderlayMetadata.read(doc);
      if (metadata != null) {
        // Candidate contours stay in source CAD coordinates.
        metadata['sourceToProject'] = {
          'scale': scale,
          'translation': [translation.dx, translation.dy],
        };
        metadata['axes'] = BimUnderlayMetadata.axes(doc)
            .map(
              (a) => a
                  .copyWith(
                    start: a.start * scale + translation,
                    end: a.end * scale + translation,
                  )
                  .toJson(),
            )
            .toList();
        transformed.headerVars[BimUnderlayMetadata.key] = jsonEncode(metadata);
      }

      transformedDocs[storey.storeyId] = transformed;
      combinedBounds = combinedBounds == null
          ? transformed.bounds
          : combinedBounds.expandToInclude(transformed.bounds);
    }

    final finalProjectBounds = combinedBounds ?? refDoc.bounds;

    // 4. Second pass: unify bounds across all transformed documents so framing matches
    final alignedDocs = <String, DxfDocument>{};
    for (final entry in transformedDocs.entries) {
      final spatialIndex = (entry.value.bounds == finalProjectBounds)
          ? entry.value.spatialIndex
          : DxfQuadTree.build(
              entry.value.entities,
              entry.value.blocks,
              finalProjectBounds,
            );

      alignedDocs[entry.key] = DxfDocument(
        layers: entry.value.layers,
        blocks: entry.value.blocks,
        entities: entry.value.entities,
        headerVars: entry.value.headerVars,
        textStyles: entry.value.textStyles,
        bounds: finalProjectBounds,
        entityStats: entry.value.entityStats,
        lineTypes: entry.value.lineTypes,
        dimStyles: entry.value.dimStyles,
        spatialIndex: spatialIndex,
        layouts: entry.value.layouts,
        layoutEntities: entry.value.layoutEntities,
        layoutBounds: entry.value.layoutBounds,
      );
    }

    return LoadedBimUnderlays(
      underlaysByStorey: alignedDocs,
      projectBounds: finalProjectBounds,
      referenceControlPoint: refCp,
      cadUnitsPerMeter: refUnitsPerMeter,
    );
  }
}
