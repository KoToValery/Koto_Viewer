/// A flat selection group. Geometry and wall junctions remain independent.
class ArchitectElementGroup {
  final String id;
  final Set<String> elementIds;
  const ArchitectElementGroup({required this.id, required this.elementIds});
  Map<String, dynamic> toJson() => {
    'id': id,
    'elementIds': elementIds.toList(),
  };
  factory ArchitectElementGroup.fromJson(Map<String, dynamic> json) =>
      ArchitectElementGroup(
        id: json['id'] as String? ?? '',
        elementIds: Set.unmodifiable(
          (json['elementIds'] as List? ?? []).whereType<String>(),
        ),
      );

  static List<ArchitectElementGroup> normalize(
    List<ArchitectElementGroup> groups,
    Set<String> valid,
  ) {
    final used = <String>{}, ids = <String>{};
    final result = <ArchitectElementGroup>[];
    for (final group in groups) {
      if (group.id.isEmpty ||
          valid.contains(group.id) ||
          ids.contains(group.id)) {
        continue;
      }
      final members = group.elementIds
          .where((id) => valid.contains(id) && !used.contains(id))
          .toSet();
      if (members.length < 2) continue;
      result.add(
        ArchitectElementGroup(
          id: group.id,
          elementIds: Set.unmodifiable(members),
        ),
      );
      used.addAll(members);
      ids.add(group.id);
    }
    return List.unmodifiable(result);
  }

  static List<ArchitectElementGroup> copies(
    List<ArchitectElementGroup> groups,
    Map<String, String> ids,
    String Function() newId,
  ) => [
    for (final group in groups)
      if (group.elementIds.every(ids.containsKey))
        ArchitectElementGroup(
          id: newId(),
          elementIds: Set.unmodifiable(group.elementIds.map((id) => ids[id]!)),
        ),
  ];
}
