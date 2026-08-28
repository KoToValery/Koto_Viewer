import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';

/// An efficient 2D Spatial Index using Quadtree for high-performance CAD entity queries
/// and viewport culling on drawings with 10,000+ to 200,000+ entities.
class DxfQuadTree {
  final Rect bounds;
  final int maxDepth;
  final int maxItemsPerNode;
  final DxfQuadTreeNode root;
  final List<DxfEntity> unindexedEntities = [];

  DxfQuadTree({
    required this.bounds,
    this.maxDepth = 8,
    this.maxItemsPerNode = 32,
  }) : root = DxfQuadTreeNode(bounds: bounds, depth: 0);

  /// Factory to construct and populate a QuadTree from a DxfDocument.
  static DxfQuadTree build(
    List<DxfEntity> entities,
    Map<String, DxfBlock> blocks,
    Rect docBounds, {
    int maxDepth = 8,
    int maxItemsPerNode = 32,
  }) {
    // Ensure bounds are non-empty
    Rect validBounds = docBounds;
    if (validBounds.isEmpty || validBounds.width <= 0 || validBounds.height <= 0) {
      validBounds = const Rect.fromLTWH(0, 0, 1000, 1000);
    }
    // Expand slightly to prevent edge clipping
    validBounds = validBounds.inflate(validBounds.longestSide * 0.05 + 1.0);

    final tree = DxfQuadTree(
      bounds: validBounds,
      maxDepth: maxDepth,
      maxItemsPerNode: maxItemsPerNode,
    );

    for (final entity in entities) {
      final rawBox = entity.getBoundingBox(blocks);
      if (rawBox != null && rawBox.isFinite) {
        final double minX = math.min(rawBox.left, rawBox.right) - 1.0;
        final double maxX = math.max(rawBox.left, rawBox.right) + 1.0;
        final double minY = math.min(rawBox.top, rawBox.bottom) - 1.0;
        final double maxY = math.max(rawBox.top, rawBox.bottom) + 1.0;
        final entityBox = Rect.fromLTRB(minX, minY, maxX, maxY);
        tree.insert(entity, entityBox);
      } else {
        tree.unindexedEntities.add(entity);
      }
    }

    return tree;
  }

  /// Inserts an entity with its computed CAD bounding box.
  void insert(DxfEntity entity, Rect entityBox) {
    if (!bounds.overlaps(entityBox)) {
      unindexedEntities.add(entity);
      return;
    }
    root.insert(
      entity,
      entityBox,
      maxDepth: maxDepth,
      maxItemsPerNode: maxItemsPerNode,
    );
  }

  /// Queries all entities whose bounding boxes intersect with [searchBounds].
  List<DxfEntity> query(Rect searchBounds) {
    final results = <DxfEntity>[];
    final visited = <DxfEntity>{};

    root.query(searchBounds, results, visited);

    // Also include unindexed entities (e.g. entities without bounding boxes)
    for (final entity in unindexedEntities) {
      if (visited.add(entity)) {
        results.add(entity);
      }
    }

    return results;
  }
}

/// A node in the DxfQuadTree.
class DxfQuadTreeNode {
  final Rect bounds;
  final int depth;
  final List<({DxfEntity entity, Rect box})> items = [];

  DxfQuadTreeNode? nw;
  DxfQuadTreeNode? ne;
  DxfQuadTreeNode? sw;
  DxfQuadTreeNode? se;

  DxfQuadTreeNode({
    required this.bounds,
    required this.depth,
  });

  bool get isLeaf => nw == null;

  void insert(
    DxfEntity entity,
    Rect entityBox, {
    required int maxDepth,
    required int maxItemsPerNode,
  }) {
    if (isLeaf) {
      items.add((entity: entity, box: entityBox));
      if (items.length > maxItemsPerNode && depth < maxDepth) {
        _subdivide();
      }
      return;
    }

    // Try placing in a child quadrant
    final placed = _insertIntoChild(entity, entityBox, maxDepth: maxDepth, maxItemsPerNode: maxItemsPerNode);
    if (!placed) {
      // Straddles multiple quadrants; retain at this node level
      items.add((entity: entity, box: entityBox));
    }
  }

  void _subdivide() {
    final double midX = bounds.left + bounds.width / 2.0;
    final double midY = bounds.top + bounds.height / 2.0;

    nw = DxfQuadTreeNode(
      bounds: Rect.fromLTRB(bounds.left, midY, midX, bounds.bottom),
      depth: depth + 1,
    );
    ne = DxfQuadTreeNode(
      bounds: Rect.fromLTRB(midX, midY, bounds.right, bounds.bottom),
      depth: depth + 1,
    );
    sw = DxfQuadTreeNode(
      bounds: Rect.fromLTRB(bounds.left, bounds.top, midX, midY),
      depth: depth + 1,
    );
    se = DxfQuadTreeNode(
      bounds: Rect.fromLTRB(midX, bounds.top, bounds.right, midY),
      depth: depth + 1,
    );

    final currentItems = List<({DxfEntity entity, Rect box})>.from(items);
    items.clear();

    for (final item in currentItems) {
      final placed = _insertIntoChild(item.entity, item.box, maxDepth: 100, maxItemsPerNode: 100);
      if (!placed) {
        items.add(item);
      }
    }
  }

  bool _insertIntoChild(
    DxfEntity entity,
    Rect entityBox, {
    required int maxDepth,
    required int maxItemsPerNode,
  }) {
    if (nw != null && _containsBox(nw!.bounds, entityBox)) {
      nw!.insert(entity, entityBox, maxDepth: maxDepth, maxItemsPerNode: maxItemsPerNode);
      return true;
    }
    if (ne != null && _containsBox(ne!.bounds, entityBox)) {
      ne!.insert(entity, entityBox, maxDepth: maxDepth, maxItemsPerNode: maxItemsPerNode);
      return true;
    }
    if (sw != null && _containsBox(sw!.bounds, entityBox)) {
      sw!.insert(entity, entityBox, maxDepth: maxDepth, maxItemsPerNode: maxItemsPerNode);
      return true;
    }
    if (se != null && _containsBox(se!.bounds, entityBox)) {
      se!.insert(entity, entityBox, maxDepth: maxDepth, maxItemsPerNode: maxItemsPerNode);
      return true;
    }
    return false;
  }

  static bool _containsBox(Rect parent, Rect child) {
    return child.left >= parent.left &&
        child.right <= parent.right &&
        child.top >= parent.top &&
        child.bottom <= parent.bottom;
  }

  void query(Rect searchBounds, List<DxfEntity> results, Set<DxfEntity> visited) {
    if (!bounds.overlaps(searchBounds)) return;

    for (final item in items) {
      if (item.box.overlaps(searchBounds)) {
        if (visited.add(item.entity)) {
          results.add(item.entity);
        }
      }
    }

    if (!isLeaf) {
      nw?.query(searchBounds, results, visited);
      ne?.query(searchBounds, results, visited);
      sw?.query(searchBounds, results, visited);
      se?.query(searchBounds, results, visited);
    }
  }
}
