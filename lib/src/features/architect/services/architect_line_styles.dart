import '../models/architect_line_style.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

/// Adds a reusable project pattern without changing already drawn elements.
class SaveArchitectLineStyle extends ArchitectModelCommand {
  final ArchitectLineStyle style;
  const SaveArchitectLineStyle(this.style);
  @override
  ArchitectProject apply(ArchitectProject project) {
    style.validate();
    if (style.isPreset) return project;
    return project.copyWith(
      lineStyles: [...project.lineStyles.where((s) => s.id != style.id), style],
    );
  }
}
