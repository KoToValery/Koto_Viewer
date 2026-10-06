enum SlabTopologyIssue {
  none,
  invalidGeometry,
  overlappingSlabs,
  separateRegions,
  computationLimit,
}

/// Geometric regions, not a certification of rigid diaphragm behaviour.
class SlabTopology {
  final SlabTopologyIssue issue;
  final int regionCount;
  /// Original slab indices in each component; no geometric copies or ID assumptions.
  final List<List<int>> regions;
  const SlabTopology(this.issue, this.regionCount, {this.regions = const []});
  bool get allowsSingleDiaphragm => issue == SlabTopologyIssue.none;
}
