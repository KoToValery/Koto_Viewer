import '../models/architect_hatch_pattern.dart';
import '../models/architect_project.dart';
import 'architect_command_controller.dart';

class SaveArchitectHatchPattern extends ArchitectModelCommand {
  final ArchitectHatchPattern pattern;
  const SaveArchitectHatchPattern(this.pattern);
  @override
  ArchitectProject apply(ArchitectProject project) {
    pattern.validate();
    if (pattern.isPreset) return project;
    return project.copyWith(
      hatchPatterns: [
        ...project.hatchPatterns.where((p) => p.id != pattern.id),
        pattern,
      ],
    );
  }
}
