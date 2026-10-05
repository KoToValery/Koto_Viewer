import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_quadtree.dart';

/// Service responsible for applying affine translations and uniform scale
/// transformations to all entities in a [DxfDocument] to bring different floor
/// underlays into a unified project coordinate space.
class DxfDocumentTransformer {
  /// Transforms [source] document by [scale] and [translation].
  ///
  /// Mathematical formula:
  ///   p' = p * scale + translation
  ///
  /// Transforms [source] document so that [sourceControlPoint] aligns with [targetControlPoint]
  /// after applying uniform [scale].
  static DxfDocument transformBetweenControlPoints({
    required DxfDocument source,
    required Offset sourceControlPoint,
    required Offset targetControlPoint,
    double scale = 1.0,
    Rect? overrideBounds,
  }) {
    final translation = targetControlPoint - (sourceControlPoint * scale);
    return transform(
      source,
      translation: translation,
      scale: scale,
      overrideBounds: overrideBounds,
    );
  }

  /// Transforms [source] document by [scale] and [translation].
  ///
  /// Mathematical formula:
  ///   p' = p * scale + translation
  ///
  /// If [overrideBounds] is provided, it is set as the document's [bounds];
  /// otherwise the bounding box is computed from the transformed entities.
  static DxfDocument transform(
    DxfDocument source, {
    required Offset translation,
    double scale = 1.0,
    Rect? overrideBounds,
  }) {
    Offset tr(Offset p) =>
        Offset(p.dx * scale + translation.dx, p.dy * scale + translation.dy);

    double sc(double val) => val * scale;

    final transformedEntities = <DxfEntity>[];

    for (final entity in source.entities) {
      transformedEntities.add(_transformEntity(entity, tr, sc, scale));
    }

    // Compute bounding box if not overridden
    Rect bounds =
        overrideBounds ?? _computeBounds(transformedEntities, source.blocks);

    // Rebuild spatial index with transformed entities and bounds
    final spatialIndex = DxfQuadTree.build(
      transformedEntities,
      source.blocks,
      bounds,
    );

    // Transform layoutEntities
    final transformedLayoutEntities = <String, List<DxfEntity>>{};
    for (final entry in source.layoutEntities.entries) {
      if (entry.key == 'Model') {
        transformedLayoutEntities['Model'] = transformedEntities;
      } else {
        // Paper space entities generally stay untransformed or can be transformed
        transformedLayoutEntities[entry.key] = entry.value
            .map((e) => _transformEntity(e, tr, sc, scale))
            .toList();
      }
    }

    // Deep copy layers with their current properties
    final copiedLayers = <String, DxfLayer>{};
    for (final entry in source.layers.entries) {
      copiedLayers[entry.key] = entry.value.copyWith();
    }

    return DxfDocument(
      layers: copiedLayers,
      blocks: source.blocks,
      entities: transformedEntities,
      headerVars: Map<String, String>.from(source.headerVars),
      textStyles: source.textStyles,
      bounds: bounds,
      entityStats: source.entityStats,
      lineTypes: source.lineTypes,
      dimStyles: source.dimStyles,
      spatialIndex: spatialIndex,
      layouts: List<String>.from(source.layouts),
      layoutEntities: transformedLayoutEntities,
      layoutBounds: source.layoutBounds,
    );
  }

  static DxfEntity copyToLayer(DxfEntity entity, String layer) =>
      _transformEntity(entity, (p) => p, (v) => v, 1, layer: layer);

  static DxfEntity _transformEntity(
    DxfEntity entity,
    Offset Function(Offset) tr,
    double Function(double) sc,
    double scale, {
    String? layer,
  }) {
    if (entity is DxfLine) {
      return DxfLine(
        p1: tr(entity.p1),
        p2: tr(entity.p2),
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfPoint) {
      return DxfPoint(
        point: tr(entity.point),
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfCircle) {
      return DxfCircle(
        center: tr(entity.center),
        radius: sc(entity.radius),
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfArc) {
      return DxfArc(
        center: tr(entity.center),
        radius: sc(entity.radius),
        startAngleDeg: entity.startAngleDeg,
        endAngleDeg: entity.endAngleDeg,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfEllipse) {
      return DxfEllipse(
        center: tr(entity.center),
        majorAxisEndOffset: entity.majorAxisEndOffset * scale,
        minorRatio: entity.minorRatio,
        startParam: entity.startParam,
        endParam: entity.endParam,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfLwPolyline) {
      return DxfLwPolyline(
        vertices: entity.vertices.map((v) {
          final tp = tr(Offset(v.x, v.y));
          return DxfPolylineVertex(
            x: tp.dx,
            y: tp.dy,
            bulge: v.bulge,
            startWidth: sc(v.startWidth),
            endWidth: sc(v.endWidth),
            flags: v.flags,
          );
        }).toList(),
        isClosed: entity.isClosed,
        elevation: entity.elevation,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfPolyline) {
      return DxfPolyline(
        vertices: entity.vertices.map((v) {
          final tp = tr(Offset(v.x, v.y));
          return DxfPolylineVertex(
            x: tp.dx,
            y: tp.dy,
            bulge: v.bulge,
            startWidth: sc(v.startWidth),
            endWidth: sc(v.endWidth),
            flags: v.flags,
          );
        }).toList(),
        isClosed: entity.isClosed,
        is3D: entity.is3D,
        flags: entity.flags,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfSpline) {
      return DxfSpline(
        degree: entity.degree,
        controlPoints: entity.controlPoints.map(tr).toList(),
        fitPoints: entity.fitPoints.map(tr).toList(),
        knots: entity.knots,
        weights: entity.weights,
        isClosed: entity.isClosed,
        isRational: entity.isRational,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfText) {
      return DxfText(
        text: entity.text,
        tag: entity.tag,
        insertPoint: tr(entity.insertPoint),
        alignPoint: entity.alignPoint != null ? tr(entity.alignPoint!) : null,
        height: sc(entity.height),
        rotationDeg: entity.rotationDeg,
        hAlign: entity.hAlign,
        vAlign: entity.vAlign,
        style: entity.style,
        isInvisible: entity.isInvisible,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfMText) {
      return DxfMText(
        rawText: entity.rawText,
        cleanText: entity.cleanText,
        insertPoint: tr(entity.insertPoint),
        height: sc(entity.height),
        refWidth: entity.refWidth != null ? sc(entity.refWidth!) : null,
        rotationDeg: entity.rotationDeg,
        attachmentPoint: entity.attachmentPoint,
        directionVector: entity.directionVector,
        style: entity.style,
        widthFactor: entity.widthFactor,
        lineSpacingFactor: entity.lineSpacingFactor,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfSolid) {
      return DxfSolid(
        p0: tr(entity.p0),
        p1: tr(entity.p1),
        p2: tr(entity.p2),
        p3: tr(entity.p3),
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfHatch) {
      return DxfHatch(
        boundaryPaths: entity.boundaryPaths
            .map((loop) => loop.map(tr).toList())
            .toList(),
        patternName: entity.patternName,
        isSolid: entity.isSolid,
        patternAngle: entity.patternAngle,
        patternScale: sc(entity.patternScale),
        transparency: entity.transparency,
        patternLines: entity.patternLines,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfAttdef) {
      return DxfAttdef(
        tag: entity.tag,
        text: entity.text,
        prompt: entity.prompt,
        insertPoint: tr(entity.insertPoint),
        alignPoint: entity.alignPoint != null ? tr(entity.alignPoint!) : null,
        height: sc(entity.height),
        rotationDeg: entity.rotationDeg,
        hAlign: entity.hAlign,
        vAlign: entity.vAlign,
        style: entity.style,
        flags: entity.flags,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfInsert) {
      final transformedAttrs = entity.attributes.map((a) {
        return DxfAttribute(
          tag: a.tag,
          value: a.value,
          prompt: a.prompt,
          isInvisible: a.isInvisible,
          isConstant: a.isConstant,
          insertPoint: tr(a.insertPoint),
          alignPoint: a.alignPoint != null ? tr(a.alignPoint!) : null,
          height: sc(a.height),
          rotationDeg: a.rotationDeg,
          hAlign: a.hAlign,
          vAlign: a.vAlign,
          style: a.style,
        );
      }).toList();

      return DxfInsert(
        blockName: entity.blockName,
        insertPoint: tr(entity.insertPoint),
        scaleX: entity.scaleX * scale,
        scaleY: entity.scaleY * scale,
        scaleZ: entity.scaleZ * scale,
        rotationDeg: entity.rotationDeg,
        rowCount: entity.rowCount,
        colCount: entity.colCount,
        rowSpacing: sc(entity.rowSpacing),
        colSpacing: sc(entity.colSpacing),
        attributes: transformedAttrs,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfDimension) {
      return DxfDimension(
        dimType: entity.dimType,
        defPoint1: tr(entity.defPoint1),
        defPoint2: entity.defPoint2 != null ? tr(entity.defPoint2!) : null,
        defPoint3: entity.defPoint3 != null ? tr(entity.defPoint3!) : null,
        textPoint: tr(entity.textPoint),
        rotationDeg: entity.rotationDeg,
        textOverride: entity.textOverride,
        blockName: entity.blockName,
        styleName: entity.styleName,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfLeader) {
      return DxfLeader(
        vertices: entity.vertices.map(tr).toList(),
        hasArrowhead: entity.hasArrowhead,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfMLeader) {
      return DxfMLeader(
        leaderLines: entity.leaderLines
            .map((line) => line.map(tr).toList())
            .toList(),
        connectionPoint: entity.connectionPoint != null
            ? tr(entity.connectionPoint!)
            : null,
        doglegDirection: entity.doglegDirection,
        doglegLength: sc(entity.doglegLength),
        textPosition: entity.textPosition != null
            ? tr(entity.textPosition!)
            : null,
        rawText: entity.rawText,
        cleanText: entity.cleanText,
        textHeight: sc(entity.textHeight),
        textWidth: entity.textWidth != null ? sc(entity.textWidth!) : null,
        hasArrowhead: entity.hasArrowhead,
        arrowheadSize: sc(entity.arrowheadSize),
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    } else if (entity is DxfViewport) {
      return DxfViewport(
        center: tr(entity.center),
        width: sc(entity.width),
        height: sc(entity.height),
        viewCenter: tr(entity.viewCenter),
        viewHeight: sc(entity.viewHeight),
        status: entity.status,
        viewportId: entity.viewportId,
        twistAngleDeg: entity.twistAngleDeg,
        layer: layer ?? entity.layer,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        lineType: entity.lineType,
        lineWeight: entity.lineWeight,
        lineTypeScale: entity.lineTypeScale,
        isPaperSpace: entity.isPaperSpace,
        layoutName: entity.layoutName,
      );
    }

    return entity;
  }

  static Rect _computeBounds(
    List<DxfEntity> entities,
    Map<String, DxfBlock> blocks,
  ) {
    if (entities.isEmpty) {
      return const Rect.fromLTWH(0, 0, 100, 100);
    }

    Rect? totalBounds;
    for (final entity in entities) {
      if (entity.isPaperSpace) continue;
      final b = entity.getBoundingBox(blocks);
      if (b != null && !b.isEmpty && b.isFinite) {
        totalBounds = totalBounds == null ? b : totalBounds.expandToInclude(b);
      }
    }

    return totalBounds ?? const Rect.fromLTWH(0, 0, 100, 100);
  }
}
