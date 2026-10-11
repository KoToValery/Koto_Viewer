import 'dart:math' as math;

/// Unique across rapid commands and separate application sessions.
class ArchitectElementId {
  static int _sequence = 0;
  static final _session = math.Random.secure()
      .nextInt(0x7fffffff)
      .toRadixString(16);
  static String next(String kind) =>
      '${kind}_${_session}_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
}
