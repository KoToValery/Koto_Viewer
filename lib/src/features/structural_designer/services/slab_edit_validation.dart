import '../analysis/slab_topology_analyzer.dart';
import '../models/slab_topology.dart';
import '../models/structural_element.dart';

/// Validates a single-slab edit before persistence. Linked edge transactions
/// use SlabEdgeOffset; isolated edits must not break an existing slab contact.
class SlabEditValidation {
  static bool accepts(
    List<StructuralSlab> before,
    StructuralSlab changed,
    double scale,
  ) {
    if (before.where((s) => s.id == changed.id).length != 1 ||
        before.map((s) => s.id).toSet().length != before.length) {
      return false;
    }
    final after = before.map((s) => s.id == changed.id ? changed : s).toList();
    final result = SlabTopologyAnalyzer.analyze(after, scale);
    if (result.issue != SlabTopologyIssue.none &&
        result.issue != SlabTopologyIssue.separateRegions) {
      return false;
    }
    final original = before.firstWhere((s) => s.id == changed.id);
    for (final other in before) {
      if (other.id == changed.id) continue;
      final oldPair = SlabTopologyAnalyzer.analyze([original, other], scale);
      if (oldPair.issue == SlabTopologyIssue.none &&
          SlabTopologyAnalyzer.analyze([changed, other], scale).issue !=
              SlabTopologyIssue.none) {
        return false;
      }
    }
    return true;
  }
}
