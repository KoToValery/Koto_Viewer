/// A confirmed vertical stair scope. Openings stay on their actual slab owners;
/// circulation polygons are stored independently on each storey.
class StaircaseCore {
  final String id;
  final String name;
  final String startStoreyId;
  final String endStoreyId;
  const StaircaseCore({
    required this.id,
    required this.name,
    required this.startStoreyId,
    required this.endStoreyId,
  });
  StaircaseCore copyWith({
    String? name,
    String? startStoreyId,
    String? endStoreyId,
  }) => StaircaseCore(
    id: id,
    name: name ?? this.name,
    startStoreyId: startStoreyId ?? this.startStoreyId,
    endStoreyId: endStoreyId ?? this.endStoreyId,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startStoreyId': startStoreyId,
    'endStoreyId': endStoreyId,
  };
  factory StaircaseCore.fromJson(Map<String, dynamic> json) => StaircaseCore(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    startStoreyId: json['startStoreyId'] as String,
    endStoreyId: json['endStoreyId'] as String,
  );
}
