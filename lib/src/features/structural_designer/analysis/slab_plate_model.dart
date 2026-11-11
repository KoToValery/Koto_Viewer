import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'structural_polygon_distance.dart';

// === SECTION: INDEX ===
// === SECTION: INPUT ===
// === SECTION: OUTPUT ===
// === SECTION: ACM ELEMENT ===
// === SECTION: BANDED CHOLESKY ===
// === SECTION: PLATE MODEL ===
//
// Linear Kirchhoff plate on a uniform square grid clipped to the slab outline
// and its openings. Rectangular ACM elements (Adini-Clough-Melosh, 12 DOF:
// w, dw/dx, dw/dy per node). Columns, walls and beams become w = 0 supports.
// The result is an elastic screening field: deflections, moments and the
// reaction carried by every support. It is not a reinforced-concrete design.

// === SECTION: INPUT ===

/// Slab region in CAD coordinates. Loads in kN/m2, thickness in metres.
class PlateRegion {
  final List<Offset> polygon;
  final List<List<Offset>> openings;
  final double thicknessM;
  final double loadUls;
  final double loadQuasiPermanent;
  const PlateRegion({
    required this.polygon,
    this.openings = const [],
    required this.thicknessM,
    required this.loadUls,
    required this.loadQuasiPermanent,
  });
}

/// Column footprint (point support) or wall/beam axis (line support), CAD.
class PlateSupport {
  final String id;
  final List<Offset>? footprint;
  final Offset? lineStart, lineEnd;
  final double halfWidthCad;
  const PlateSupport.footprint(this.id, List<Offset> polygon)
    : footprint = polygon,
      lineStart = null,
      lineEnd = null,
      halfWidthCad = 0;
  const PlateSupport.line(this.id, Offset a, Offset b, this.halfWidthCad)
    : footprint = null,
      lineStart = a,
      lineEnd = b;
  bool get isLine => lineStart != null;
}

/// Concentrated load in kN (columns or wall pieces standing on the slab).
class PlatePointLoad {
  final String sourceId;
  final Offset pointCad;
  final double uls, quasiPermanent;
  const PlatePointLoad(this.sourceId, this.pointCad, this.uls, this.quasiPermanent);
}

/// Line load in kN/m (facades).
class PlateLineLoad {
  final Offset a, b;
  final double uls, quasiPermanent;
  const PlateLineLoad(this.a, this.b, this.uls, this.quasiPermanent);
}

// === SECTION: OUTPUT ===

enum PlateStatus { solved, noSlab, invalidInput, unstable }

class PlateNodeResult {
  final Offset pointCad;
  final int component;

  /// Elastic deflection under G + psi2 Q, metres, positive downward.
  final double deflectionQp;

  /// Distance to the nearest supported node, metres.
  final double distanceToSupportM;
  const PlateNodeResult(this.pointCad, this.component, this.deflectionQp,
      this.distanceToSupportM);
}

class PlateCellResult {
  final Offset centerCad;
  final int component;
  final double thicknessM;

  /// ULS moments at the cell centre, kNm/m (Mx, My, Mxy in grid axes).
  final double mx, my, mxy;
  const PlateCellResult(this.centerCad, this.component, this.thicknessM,
      this.mx, this.my, this.mxy);
}

class PlateSolution {
  final PlateStatus status;
  final double spacingM;
  final Map<String, double> reactionUls, reactionQp;
  final List<PlateNodeResult> nodes;
  final List<PlateCellResult> cells;
  final List<List<Offset>> unsupportedCellsCad;
  final double unsupportedAreaM2;

  /// Applied loads that fell on unsupported or missing slab (kN, ULS).
  final double lostLoadUls;
  final Set<String> lostPointLoadIds;
  final double totalLoadUls;

  const PlateSolution({
    required this.status,
    this.spacingM = 0,
    this.reactionUls = const {},
    this.reactionQp = const {},
    this.nodes = const [],
    this.cells = const [],
    this.unsupportedCellsCad = const [],
    this.unsupportedAreaM2 = 0,
    this.lostLoadUls = 0,
    this.lostPointLoadIds = const {},
    this.totalLoadUls = 0,
  });

  double get totalReactionUls =>
      reactionUls.values.fold(0.0, (sum, r) => sum + r);
}

// === SECTION: ACM ELEMENT ===

/// Unit-rigidity element matrices for a square cell of side [s].
class AcmElement {
  static const _terms = <(int, int)>[
    (0, 0), (1, 0), (0, 1), (2, 0), (1, 1), (0, 2),
    (3, 0), (2, 1), (1, 2), (0, 3), (3, 1), (1, 3),
  ];

  final double s;
  final double poisson;

  /// 12x12 stiffness for D = 1 (row-major).
  final Float64List stiffness;

  /// Consistent nodal load vector for q = 1.
  final Float64List load;

  /// Maps element DOFs to (wxx, wyy, wxy) at the cell centre: 3x12.
  final Float64List centreCurvature;

  AcmElement._(this.s, this.poisson, this.stiffness, this.load,
      this.centreCurvature);

  static double _pow(double v, int e) => e <= 0 ? 1 : math.pow(v, e).toDouble();

  factory AcmElement(double s, double poisson) {
    final h = s / 2;
    // Node order: (-h,-h), (h,-h), (h,h), (-h,h); DOFs (w, wx, wy).
    final nodes = [Offset(-h, -h), Offset(h, -h), Offset(h, h), Offset(-h, h)];
    final c = List.generate(12, (_) => List<double>.filled(12, 0));
    for (var n = 0; n < 4; n++) {
      final x = nodes[n].dx, y = nodes[n].dy;
      for (var p = 0; p < 12; p++) {
        final (a, b) = _terms[p];
        c[3 * n][p] = _pow(x, a) * _pow(y, b);
        c[3 * n + 1][p] = a == 0 ? 0 : a * _pow(x, a - 1) * _pow(y, b);
        c[3 * n + 2][p] = b == 0 ? 0 : b * _pow(x, a) * _pow(y, b - 1);
      }
    }
    final inv = _invert(c);
    // Gauss 3x3, exact for the degree-4 curvature products.
    final g = math.sqrt(3 / 5);
    final gp = [-g * h, 0.0, g * h];
    final gw = [5 / 9 * h, 8 / 9 * h, 5 / 9 * h];
    final kPoly = List.generate(12, (_) => List<double>.filled(12, 0));
    final fPoly = List<double>.filled(12, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final x = gp[i], y = gp[j], wt = gw[i] * gw[j];
        final pxx = List<double>.filled(12, 0);
        final pyy = List<double>.filled(12, 0);
        final pxy = List<double>.filled(12, 0);
        for (var p = 0; p < 12; p++) {
          final (a, b) = _terms[p];
          pxx[p] = a < 2 ? 0 : a * (a - 1) * _pow(x, a - 2) * _pow(y, b);
          pyy[p] = b < 2 ? 0 : b * (b - 1) * _pow(x, a) * _pow(y, b - 2);
          pxy[p] = a < 1 || b < 1
              ? 0
              : a * b * _pow(x, a - 1) * _pow(y, b - 1);
          fPoly[p] += wt * _pow(x, a) * _pow(y, b);
        }
        for (var p = 0; p < 12; p++) {
          for (var q = 0; q < 12; q++) {
            kPoly[p][q] += wt *
                (pxx[p] * pxx[q] +
                    pyy[p] * pyy[q] +
                    poisson * (pxx[p] * pyy[q] + pyy[p] * pxx[q]) +
                    2 * (1 - poisson) * pxy[p] * pxy[q]);
          }
        }
      }
    }
    final k = Float64List(144);
    for (var r = 0; r < 12; r++) {
      for (var col = 0; col < 12; col++) {
        var sum = 0.0;
        for (var p = 0; p < 12; p++) {
          if (inv[p][r] == 0) continue;
          for (var q = 0; q < 12; q++) {
            sum += inv[p][r] * kPoly[p][q] * inv[q][col];
          }
        }
        k[r * 12 + col] = sum;
      }
    }
    final f = Float64List(12);
    for (var r = 0; r < 12; r++) {
      var sum = 0.0;
      for (var p = 0; p < 12; p++) {
        sum += inv[p][r] * fPoly[p];
      }
      f[r] = sum;
    }
    // At (0,0): wxx = 2 c(x^2), wyy = 2 c(y^2), wxy = c(xy).
    final curvature = Float64List(36);
    for (var dof = 0; dof < 12; dof++) {
      curvature[dof] = 2 * inv[3][dof];
      curvature[12 + dof] = 2 * inv[5][dof];
      curvature[24 + dof] = inv[4][dof];
    }
    return AcmElement._(s, poisson, k, f, curvature);
  }

  static List<List<double>> _invert(List<List<double>> m) {
    final n = m.length;
    final a = [for (final row in m) [...row, ...List<double>.filled(n, 0)]];
    for (var i = 0; i < n; i++) {
      a[i][n + i] = 1;
    }
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;
      final d = a[col][col];
      for (var j = 0; j < 2 * n; j++) {
        a[col][j] /= d;
      }
      for (var r = 0; r < n; r++) {
        if (r == col || a[r][col] == 0) continue;
        final factor = a[r][col];
        for (var j = 0; j < 2 * n; j++) {
          a[r][j] -= factor * a[col][j];
        }
      }
    }
    return [for (final row in a) row.sublist(n)];
  }
}

// === SECTION: BANDED CHOLESKY ===

/// Symmetric positive definite band matrix, lower half stored row-wise.
class BandMatrix {
  final int n, band;
  final Float64List data;
  BandMatrix(this.n, this.band) : data = Float64List(n * (band + 1));

  int _index(int i, int j) => i * (band + 1) + (j - i + band);

  void add(int i, int j, double v) {
    if (j > i) {
      final t = i;
      i = j;
      j = t;
    }
    data[_index(i, j)] += v;
  }

  /// In-place L L^T. Returns false on a non-positive pivot (mechanism).
  bool factorize() {
    var maxDiagonal = 0.0;
    for (var i = 0; i < n; i++) {
      maxDiagonal = math.max(maxDiagonal, data[_index(i, i)].abs());
    }
    final tolerance = maxDiagonal * 1e-11;
    final w = band + 1;
    for (var i = 0; i < n; i++) {
      final iStart = math.max(0, i - band);
      for (var j = iStart; j <= i; j++) {
        final kStart = math.max(iStart, j - band);
        var sum = data[i * w + (j - i + band)];
        final rowI = i * w - i + band, rowJ = j * w - j + band;
        for (var k = kStart; k < j; k++) {
          sum -= data[rowI + k] * data[rowJ + k];
        }
        if (i == j) {
          if (!(sum > tolerance)) return false;
          data[rowI + i] = math.sqrt(sum);
        } else {
          data[rowI + j] = sum / data[rowJ + j];
        }
      }
    }
    return true;
  }

  void solveInPlace(Float64List b) {
    final w = band + 1;
    for (var i = 0; i < n; i++) {
      var sum = b[i];
      final row = i * w - i + band;
      for (var k = math.max(0, i - band); k < i; k++) {
        sum -= data[row + k] * b[k];
      }
      b[i] = sum / data[row + i];
    }
    for (var i = n - 1; i >= 0; i--) {
      var sum = b[i];
      for (var k = i + 1; k <= math.min(n - 1, i + band); k++) {
        sum -= data[k * w - k + band + i] * b[k];
      }
      b[i] = sum / data[i * w - i + band + i];
    }
  }
}

// === SECTION: PLATE MODEL ===

class SlabPlateModel {
  /// Node budget keeps a phone solve in the tens-of-milliseconds range.
  static const maxNodes = 3600;
  static const poissonConcrete = 0.2;

  static PlateSolution solve({
    required List<PlateRegion> regions,
    required List<PlateSupport> supports,
    List<PlatePointLoad> pointLoads = const [],
    List<PlateLineLoad> lineLoads = const [],
    required double cadUnitsPerMeter,
    required double elasticModulusKpa,
    double spacingM = 0.5,
    double poisson = poissonConcrete,
  }) {
    final scale = cadUnitsPerMeter;
    final valid = regions
        .where((r) =>
            r.polygon.length >= 3 &&
            r.thicknessM.isFinite &&
            r.thicknessM > 0.03 &&
            r.loadUls.isFinite &&
            r.loadQuasiPermanent.isFinite)
        .toList();
    if (valid.isEmpty) return const PlateSolution(status: PlateStatus.noSlab);
    if (!scale.isFinite || scale <= 0 || !elasticModulusKpa.isFinite ||
        elasticModulusKpa <= 0) {
      return const PlateSolution(status: PlateStatus.invalidInput);
    }

    // Local frame: origin at the first vertex, axes along the longest edge,
    // so orthogonal plans at any rotation mesh without stair-stepping.
    final origin = valid.first.polygon.first;
    var angle = 0.0, longest = -1.0;
    for (final r in valid) {
      for (var i = 0; i < r.polygon.length; i++) {
        final d = r.polygon[(i + 1) % r.polygon.length] - r.polygon[i];
        if (d.distance > longest) {
          longest = d.distance;
          angle = math.atan2(d.dy, d.dx);
        }
      }
    }
    final ca = math.cos(angle), sa = math.sin(angle);
    Offset toLocal(Offset p) {
      final d = (p - origin) / scale;
      return Offset(d.dx * ca + d.dy * sa, -d.dx * sa + d.dy * ca);
    }

    Offset toCad(Offset p) =>
        origin + Offset(p.dx * ca - p.dy * sa, p.dx * sa + p.dy * ca) * scale;

    final localRegions = [
      for (final r in valid)
        (
          r,
          r.polygon.map(toLocal).toList(),
          [for (final o in r.openings) if (o.length >= 3) o.map(toLocal).toList()],
        ),
    ];
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final (_, poly, _) in localRegions) {
      for (final p in poly) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    var s = spacingM;
    int nx, ny;
    while (true) {
      nx = math.max(1, ((maxX - minX) / s).ceil());
      ny = math.max(1, ((maxY - minY) / s).ceil());
      if ((nx + 1) * (ny + 1) <= maxNodes) break;
      s *= 1.25;
    }
    final element = AcmElement(s, poisson);

    // --- Cells ---------------------------------------------------------
    final cellRegion = Int32List(nx * ny)..fillRange(0, nx * ny, -1);
    final regionMeshArea = List<double>.filled(localRegions.length, 0);
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        final c = Offset(minX + (i + .5) * s, minY + (j + .5) * s);
        for (var r = 0; r < localRegions.length; r++) {
          final (_, poly, holes) = localRegions[r];
          if (StructuralPolygonDistance.inside(c, poly) &&
              !holes.any((h) => StructuralPolygonDistance.inside(c, h))) {
            cellRegion[i * ny + j] = r;
            regionMeshArea[r] += s * s;
            break;
          }
        }
      }
    }
    int nodeOf(int i, int j) => i * (ny + 1) + j;
    final nodeCount = (nx + 1) * (ny + 1);
    Offset nodeLocal(int node) =>
        Offset(minX + (node ~/ (ny + 1)) * s, minY + (node % (ny + 1)) * s);
    List<int> cellNodes(int i, int j) =>
        [nodeOf(i, j), nodeOf(i + 1, j), nodeOf(i + 1, j + 1), nodeOf(i, j + 1)];

    final nodeActive = Uint8List(nodeCount);
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (cellRegion[i * ny + j] < 0) continue;
        for (final n in cellNodes(i, j)) {
          nodeActive[n] = 1;
        }
      }
    }
    if (!nodeActive.contains(1)) {
      return const PlateSolution(status: PlateStatus.noSlab);
    }

    // --- Components (cells sharing a node act as one plate) ------------
    final parent = List<int>.generate(nodeCount, (k) => k);
    int find(int k) {
      while (parent[k] != k) {
        parent[k] = parent[parent[k]];
        k = parent[k];
      }
      return k;
    }

    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (cellRegion[i * ny + j] < 0) continue;
        final ns = cellNodes(i, j);
        for (final n in ns.skip(1)) {
          final a = find(ns.first), b = find(n);
          if (a != b) parent[a] = b;
        }
      }
    }

    // --- Supports --------------------------------------------------------
    final nodeSupport = List<String?>.filled(nodeCount, null);
    int? nearestActive(Offset p, double radius) {
      int? best;
      var bestD = radius;
      final ci = ((p.dx - minX) / s).round(), cj = ((p.dy - minY) / s).round();
      final reach = (radius / s).ceil() + 1;
      for (var i = ci - reach; i <= ci + reach; i++) {
        for (var j = cj - reach; j <= cj + reach; j++) {
          if (i < 0 || j < 0 || i > nx || j > ny) continue;
          final n = nodeOf(i, j);
          if (nodeActive[n] == 0) continue;
          final d = (nodeLocal(n) - p).distance;
          if (d <= bestD) {
            bestD = d;
            best = n;
          }
        }
      }
      return best;
    }

    Iterable<int> nodesIn(double x0, double y0, double x1, double y1) sync* {
      final i0 = math.max(0, ((x0 - minX) / s).floor());
      final i1 = math.min(nx, ((x1 - minX) / s).ceil());
      final j0 = math.max(0, ((y0 - minY) / s).floor());
      final j1 = math.min(ny, ((y1 - minY) / s).ceil());
      for (var i = i0; i <= i1; i++) {
        for (var j = j0; j <= j1; j++) {
          final n = nodeOf(i, j);
          if (nodeActive[n] == 1) yield n;
        }
      }
    }

    for (final support in supports) {
      var claimed = 0;
      if (support.isLine) {
        final a = toLocal(support.lineStart!), b = toLocal(support.lineEnd!);
        final tol = math.max(support.halfWidthCad / scale, .5 * s) + 1e-9;
        for (final n in nodesIn(math.min(a.dx, b.dx) - tol,
            math.min(a.dy, b.dy) - tol, math.max(a.dx, b.dx) + tol,
            math.max(a.dy, b.dy) + tol)) {
          if (nodeSupport[n] != null) continue;
          if (StructuralPolygonDistance.pointToSegment(nodeLocal(n), a, b) <= tol) {
            nodeSupport[n] = support.id;
            claimed++;
          }
        }
      } else {
        final poly = support.footprint!.map(toLocal).toList();
        if (poly.length < 3) continue;
        var x0 = double.infinity, y0 = double.infinity;
        var x1 = -double.infinity, y1 = -double.infinity;
        for (final p in poly) {
          x0 = math.min(x0, p.dx);
          y0 = math.min(y0, p.dy);
          x1 = math.max(x1, p.dx);
          y1 = math.max(y1, p.dy);
        }
        for (final n in nodesIn(x0, y0, x1, y1)) {
          if (nodeSupport[n] == null &&
              StructuralPolygonDistance.inside(nodeLocal(n), poly)) {
            nodeSupport[n] = support.id;
            claimed++;
          }
        }
        if (claimed == 0) {
          final centre = Offset((x0 + x1) / 2, (y0 + y1) / 2);
          final n = nearestActive(centre, .75 * s);
          if (n != null && nodeSupport[n] == null) nodeSupport[n] = support.id;
        }
      }
    }

    // Stable components need three non-collinear supported nodes.
    final componentSupports = <int, List<Offset>>{};
    for (var n = 0; n < nodeCount; n++) {
      if (nodeActive[n] == 1 && nodeSupport[n] != null) {
        componentSupports.putIfAbsent(find(n), () => []).add(nodeLocal(n));
      }
    }
    bool stable(int root) {
      final pts = componentSupports[root];
      if (pts == null || pts.length < 3) return false;
      final a = pts.first;
      var far = a;
      for (final p in pts) {
        if ((p - a).distance > (far - a).distance) far = p;
      }
      final u = far - a;
      if (u.distance < 1e-9) return false;
      for (final p in pts) {
        final v = p - a;
        if ((u.dx * v.dy - u.dy * v.dx).abs() / u.distance > .25 * s) return true;
      }
      return false;
    }

    final componentIds = <int, int>{};
    final stableRoots = <int>{};
    for (var n = 0; n < nodeCount; n++) {
      if (nodeActive[n] == 0) continue;
      final root = find(n);
      componentIds.putIfAbsent(root, () => componentIds.length);
      if (stable(root)) stableRoots.add(root);
    }

    // --- Cells kept, unsupported cells reported ---------------------------
    final unsupportedCells = <List<Offset>>[];
    var unsupportedArea = 0.0;
    var lostLoad = 0.0;
    final keptCell = Uint8List(nx * ny);
    // Staircase cell edges are corrected so the total load equals the drawn
    // net area. Overlapping zones would distort the factor; then keep 1.0.
    final regionScale = [
      for (var r = 0; r < localRegions.length; r++)
        () {
          if (regionMeshArea[r] <= 0) return 0.0;
          final f = _netAreaM2(localRegions[r].$2, localRegions[r].$3) /
              regionMeshArea[r];
          return f >= .7 && f <= 1.3 ? f : 1.0;
        }(),
    ];
    var totalLoad = 0.0;
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        final r = cellRegion[i * ny + j];
        if (r < 0) continue;
        final cellLoad = localRegions[r].$1.loadUls * s * s * regionScale[r];
        totalLoad += cellLoad;
        if (stableRoots.contains(find(nodeOf(i, j)))) {
          keptCell[i * ny + j] = 1;
        } else {
          unsupportedArea += s * s * regionScale[r];
          lostLoad += cellLoad;
          unsupportedCells.add([
            for (final n in cellNodes(i, j)) toCad(nodeLocal(n)),
          ]);
        }
      }
    }

    // --- DOF numbering (shorter grid direction varies fastest) -----------
    final order = <int>[];
    if (nx >= ny) {
      for (var i = 0; i <= nx; i++) {
        for (var j = 0; j <= ny; j++) {
          order.add(nodeOf(i, j));
        }
      }
    } else {
      for (var j = 0; j <= ny; j++) {
        for (var i = 0; i <= nx; i++) {
          order.add(nodeOf(i, j));
        }
      }
    }
    final nodeInModel = Uint8List(nodeCount);
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (keptCell[i * ny + j] == 0) continue;
        for (final n in cellNodes(i, j)) {
          nodeInModel[n] = 1;
        }
      }
    }
    final dof = Int32List(nodeCount * 3)..fillRange(0, nodeCount * 3, -1);
    var dofCount = 0;
    for (final n in order) {
      if (nodeInModel[n] == 0) continue;
      for (var k = 0; k < 3; k++) {
        if (k == 0 && nodeSupport[n] != null) continue;
        dof[n * 3 + k] = dofCount++;
      }
    }

    final fUls = Float64List(dofCount), fQp = Float64List(dofCount);
    final nodeLoadUls = Float64List(nodeCount), nodeLoadQp = Float64List(nodeCount);
    final lostIds = <String>{};

    void addNodeLoad(int node, double uls, double qp) {
      nodeLoadUls[node] += uls;
      nodeLoadQp[node] += qp;
      final d = dof[node * 3];
      if (d >= 0) {
        fUls[d] += uls;
        fQp[d] += qp;
      }
    }

    int? modelNodeNear(Offset local) {
      final n = nearestActive(local, .75 * s);
      return n != null && nodeInModel[n] == 1 ? n : null;
    }

    for (final load in pointLoads) {
      final local = toLocal(load.pointCad);
      final n = modelNodeNear(local);
      totalLoad += load.uls;
      if (n == null) {
        lostLoad += load.uls;
        lostIds.add(load.sourceId);
      } else {
        addNodeLoad(n, load.uls, load.quasiPermanent);
      }
    }
    for (final load in lineLoads) {
      final a = toLocal(load.a), b = toLocal(load.b);
      final length = (b - a).distance;
      if (length < 1e-9) continue;
      final pieces = math.max(1, (length / (s / 2)).ceil());
      for (var k = 0; k < pieces; k++) {
        final p = a + (b - a) * ((k + .5) / pieces);
        final uls = load.uls * length / pieces;
        final qp = load.quasiPermanent * length / pieces;
        totalLoad += uls;
        final n = modelNodeNear(p);
        if (n == null) {
          lostLoad += uls;
        } else {
          addNodeLoad(n, uls, qp);
        }
      }
    }

    if (dofCount == 0) {
      return PlateSolution(
        status: PlateStatus.unstable,
        spacingM: s,
        unsupportedCellsCad: unsupportedCells,
        unsupportedAreaM2: unsupportedArea,
        lostLoadUls: lostLoad,
        lostPointLoadIds: lostIds,
        totalLoadUls: totalLoad,
      );
    }

    // --- Assembly ----------------------------------------------------------
    double rigidity(double t) =>
        elasticModulusKpa * t * t * t / (12 * (1 - poisson * poisson));
    var band = 0;
    final elementDofs = Int32List(12);
    void gatherDofs(int i, int j) {
      final ns = cellNodes(i, j);
      for (var a = 0; a < 4; a++) {
        for (var k = 0; k < 3; k++) {
          elementDofs[a * 3 + k] = dof[ns[a] * 3 + k];
        }
      }
    }

    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (keptCell[i * ny + j] == 0) continue;
        gatherDofs(i, j);
        var lo = 1 << 30, hi = -1;
        for (final d in elementDofs) {
          if (d < 0) continue;
          lo = math.min(lo, d);
          hi = math.max(hi, d);
        }
        if (hi >= 0) band = math.max(band, hi - lo);
      }
    }
    final matrix = BandMatrix(dofCount, band);
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (keptCell[i * ny + j] == 0) continue;
        final region = localRegions[cellRegion[i * ny + j]].$1;
        final r = cellRegion[i * ny + j];
        final dScale = rigidity(region.thicknessM);
        final qU = region.loadUls * regionScale[r];
        final qQ = region.loadQuasiPermanent * regionScale[r];
        gatherDofs(i, j);
        for (var a = 0; a < 12; a++) {
          final da = elementDofs[a];
          if (da < 0) continue;
          fUls[da] += element.load[a] * qU;
          fQp[da] += element.load[a] * qQ;
          for (var b = 0; b <= a; b++) {
            final db = elementDofs[b];
            if (db < 0) continue;
            final v = element.stiffness[a * 12 + b] * dScale;
            if (da == db && a != b) {
              matrix.add(da, db, 2 * v);
            } else {
              matrix.add(da, db, v);
            }
          }
        }
      }
    }
    if (!matrix.factorize()) {
      return PlateSolution(
        status: PlateStatus.unstable,
        spacingM: s,
        unsupportedCellsCad: unsupportedCells,
        unsupportedAreaM2: unsupportedArea,
        lostLoadUls: lostLoad,
        lostPointLoadIds: lostIds,
        totalLoadUls: totalLoad,
      );
    }
    final uUls = Float64List.fromList(fUls), uQp = Float64List.fromList(fQp);
    matrix.solveInPlace(uUls);
    matrix.solveInPlace(uQp);

    // --- Post-processing ---------------------------------------------------
    // Reaction at a supported node: R = F - K u (upward, positive).
    final residualUls = Float64List(nodeCount), residualQp = Float64List(nodeCount);
    final cells = <PlateCellResult>[];
    final ue = Float64List(12), ueQ = Float64List(12);
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < ny; j++) {
        if (keptCell[i * ny + j] == 0) continue;
        final r = cellRegion[i * ny + j];
        final region = localRegions[r].$1;
        final dScale = rigidity(region.thicknessM);
        final qU = region.loadUls * regionScale[r];
        final qQ = region.loadQuasiPermanent * regionScale[r];
        gatherDofs(i, j);
        for (var a = 0; a < 12; a++) {
          final d = elementDofs[a];
          ue[a] = d < 0 ? 0 : uUls[d];
          ueQ[a] = d < 0 ? 0 : uQp[d];
        }
        final ns = cellNodes(i, j);
        for (var a = 0; a < 4; a++) {
          if (nodeSupport[ns[a]] == null) continue;
          final row = a * 3;
          var ku = 0.0, kq = 0.0;
          for (var b = 0; b < 12; b++) {
            final kv = element.stiffness[row * 12 + b] * dScale;
            ku += kv * ue[b];
            kq += kv * ueQ[b];
          }
          residualUls[ns[a]] += element.load[row] * qU - ku;
          residualQp[ns[a]] += element.load[row] * qQ - kq;
        }
        var wxx = 0.0, wyy = 0.0, wxy = 0.0;
        for (var b = 0; b < 12; b++) {
          wxx += element.centreCurvature[b] * ue[b];
          wyy += element.centreCurvature[12 + b] * ue[b];
          wxy += element.centreCurvature[24 + b] * ue[b];
        }
        cells.add(PlateCellResult(
          toCad(Offset(minX + (i + .5) * s, minY + (j + .5) * s)),
          componentIds[find(ns.first)]!,
          region.thicknessM,
          -dScale * (wxx + poisson * wyy),
          -dScale * (wyy + poisson * wxx),
          -dScale * (1 - poisson) * wxy,
        ));
      }
    }
    final reactionUls = <String, double>{}, reactionQp = <String, double>{};
    final supportNodes = <Offset>[];
    for (var n = 0; n < nodeCount; n++) {
      final id = nodeSupport[n];
      if (id == null || nodeInModel[n] == 0) continue;
      reactionUls[id] =
          (reactionUls[id] ?? 0) + residualUls[n] + nodeLoadUls[n];
      reactionQp[id] = (reactionQp[id] ?? 0) + residualQp[n] + nodeLoadQp[n];
      supportNodes.add(nodeLocal(n));
    }

    final nodes = <PlateNodeResult>[];
    for (var n = 0; n < nodeCount; n++) {
      if (nodeInModel[n] == 0) continue;
      final p = nodeLocal(n);
      var dMin = double.infinity;
      for (final q in supportNodes) {
        final d = (q - p).distanceSquared;
        if (d < dMin) dMin = d;
      }
      final d = dof[n * 3];
      nodes.add(PlateNodeResult(toCad(p), componentIds[find(n)]!,
          d < 0 ? 0 : uQp[d], math.sqrt(dMin)));
    }

    return PlateSolution(
      status: PlateStatus.solved,
      spacingM: s,
      reactionUls: reactionUls,
      reactionQp: reactionQp,
      nodes: nodes,
      cells: cells,
      unsupportedCellsCad: unsupportedCells,
      unsupportedAreaM2: unsupportedArea,
      lostLoadUls: lostLoad,
      lostPointLoadIds: lostIds,
      totalLoadUls: totalLoad,
    );
  }

  static double _area(List<Offset> ring) {
    var a = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final p = ring[i], q = ring[(i + 1) % ring.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    return a.abs() / 2;
  }

  static double _netAreaM2(List<Offset> poly, List<List<Offset>> holes) =>
      math.max(0, _area(poly) - holes.fold(0.0, (s, h) => s + _area(h)));
}
