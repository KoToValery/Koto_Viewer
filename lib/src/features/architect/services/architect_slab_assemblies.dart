import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_slab_assembly.dart';
import 'architect_element_id.dart';

class ArchitectSlabAssemblies {
  static ArchitectSlabAssembly? of(
    ArchitectProject project,
    ArchitectSlab slab,
  ) => project.slabAssemblies.where((a) => a.id == slab.assemblyId).firstOrNull;

  /// Called at transaction boundaries: reserve durable, content-based numbers.
  static ArchitectProject resolve(ArchitectProject project) {
    final numbers = Map<String, int>.of(project.slabCompositionNumbers);
    var next = numbers.values.fold(0, math.max) + 1;
    if (project.slabAssemblies.map((a) => a.id).toSet().length !=
            project.slabAssemblies.length ||
        project.sections.map((s) => s.id).toSet().length !=
            project.sections.length) {
      throw ArgumentError('Duplicate assembly or section IDs');
    }
    for (final section in project.sections) {
      final points = [
        section.start,
        section.end,
        ...section.details.map((d) => d.textOffset),
      ];
      if (section.id.isEmpty ||
          !section.length.isFinite ||
          section.length < .001 ||
          points.any((p) => !p.dx.isFinite || !p.dy.isFinite) ||
          section.details.map((d) => d.id).toSet().length !=
              section.details.length ||
          section.details.any(
            (d) =>
                d.id.isEmpty ||
                d.slabId.isEmpty ||
                !d.station.isFinite ||
                !d.fallbackElevation.isFinite,
          )) {
        throw ArgumentError('Invalid building section');
      }
    }
    for (final a in project.slabAssemblies) {
      a.validate();
    }
    for (final storey in project.storeys) {
      for (final slab in storey.slabs) {
        if (!slab.thickness.isFinite ||
            slab.thickness <= 0 ||
            !slab.coreTopOffset.isFinite ||
            (slab.slopeDirection != null && !slab.slopeDirection!.isFinite)) {
          throw ArgumentError('Invalid slab dimensions');
        }
        final a = of(project, slab);
        if (slab.assemblyId != null && a == null) {
          throw ArgumentError('Unknown slab assembly');
        }
        if (a?.hasSlope == true && slab.slopeDirection == null) {
          throw ArgumentError('Sloping assembly requires a direction');
        }
        final key =
            (a ??
                    const ArchitectSlabAssembly(
                      id: 'bare',
                      usage: SlabUsage.intermediate,
                    ))
                .signature(slab.thickness);
        numbers.putIfAbsent(key, () => next++);
      }
    }
    return project.copyWith(slabCompositionNumbers: numbers);
  }

  static int? number(ArchitectProject project, ArchitectSlab slab) =>
      project.slabCompositionNumbers[(of(project, slab) ??
              const ArchitectSlabAssembly(
                id: 'bare',
                usage: SlabUsage.intermediate,
              ))
          .signature(slab.thickness)];

  static ArchitectProject assign(
    ArchitectProject project,
    String storeyId,
    String slabId,
    ArchitectSlabAssembly assembly, {
    required bool onlyThis,
    required double thickness,
    required double coreTopOffset,
    double? direction,
  }) {
    assembly.validate();
    final storey = project.storeys.firstWhere((s) => s.id == storeyId);
    storey.slabs.firstWhere((s) => s.id == slabId);
    final targetId =
        onlyThis && project.slabAssemblies.any((a) => a.id == assembly.id)
        ? ArchitectElementId.next('assembly')
        : assembly.id;
    final changed = assembly.copyWith(id: targetId);
    final assemblies = [
      ...project.slabAssemblies.where((a) => a.id != targetId),
      changed,
    ];
    final stores = [
      for (final s in project.storeys)
        s.copyWith(
          slabs: [
            for (final slab in s.slabs)
              if (s.id == storeyId && slab.id == slabId)
                slab.copyWith(
                  assemblyId: targetId,
                  thickness: thickness,
                  coreTopOffset: coreTopOffset,
                  slopeDirection: direction,
                )
              else if (slab.assemblyId == targetId &&
                  changed.hasSlope &&
                  slab.slopeDirection == null)
                slab.copyWith(slopeDirection: direction)
              else
                slab,
          ],
        ),
    ];
    return resolve(
      project.copyWith(storeys: stores, slabAssemblies: assemblies),
    );
  }
}

/// Personal copies never act as a live dependency of saved project assemblies.
class ArchitectSlabLibrary {
  static const storageKey = 'architect_slab_assemblies_v1';
  static Future<List<ArchitectSlabAssembly>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(storageKey);
    if (data == null) return [];
    final result = <ArchitectSlabAssembly>[];
    try {
      for (final entry in jsonDecode(data) as List) {
        try {
          final a = ArchitectSlabAssembly.fromJson(
            Map<String, dynamic>.from(entry as Map),
          );
          a.validate();
          result.add(a);
        } on Object {
          /* A corrupt library entry must not hide valid entries. */
        }
      }
    } on Object {
      return [];
    }
    return result;
  }

  static Future<bool> save(ArchitectSlabAssembly assembly) async {
    assembly.validate();
    final entries = await load();
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      storageKey,
      jsonEncode([
        ...entries.where((a) => a.id != assembly.id).map((a) => a.toJson()),
        assembly.toJson(),
      ]),
    );
  }
}
