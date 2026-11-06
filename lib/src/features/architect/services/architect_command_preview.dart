import '../../bim_editing/commands/bim_edit_history.dart';
import '../../bim_editing/interaction/bim_edit_session.dart';
import '../models/architect_project.dart';

/// One explicit edit command. Neither staging nor cancellation publishes data.
class ArchitectCommandPreview {
  final String action;
  final ArchitectProject document;
  final BimEditSession<ArchitectProject> _session;
  bool ready = false;

  ArchitectCommandPreview({
    required this.action,
    required this.document,
    required Object context,
    required ArchitectProject original,
  }) : _session = BimEditSession(context: context, original: original);

  ArchitectProject get original => _session.original;
  ArchitectProject get preview => _session.preview;

  bool stage(Object context, ArchitectProject next) {
    ready = false;
    if (!_session.update(context, (_) => next)) return false;
    final before = original.toJson()
      ..remove('updatedAt')
      ..remove('activeStoreyId');
    final after = next.toJson()
      ..remove('updatedAt')
      ..remove('activeStoreyId');
    ready = !bimValuesEqual(before, after);
    return true;
  }

  ArchitectProject? confirm(Object context) =>
      _session.finish(context, changed: ready);

  void cancel() {
    _session.cancel();
    ready = false;
  }
}
