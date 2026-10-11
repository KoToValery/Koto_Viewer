import 'package:flutter/painting.dart';
import '../models/structural_element.dart';

/// One outdoor slab colour, including saved projects with older palette values.
class SlabColors {
  static const balcony = Color(0xFF00E676);

  static Color forSlab(StructuralSlab slab, {required Color fallback}) {
    if (const {
      SlabZoneKind.balcony,
      SlabZoneKind.terrace,
      SlabZoneKind.loggia,
    }.contains(slab.effectiveZoneKind)) {
      return balcony;
    }
    return slab.colorValue == null ? fallback : Color(slab.colorValue!);
  }
}
