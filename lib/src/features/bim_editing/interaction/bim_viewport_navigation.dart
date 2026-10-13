import 'dart:ui';

/// Camera contract independent of native coordinate systems and painters.
abstract interface class BimViewportNavigation {
  Size get size;
  void resize(Size size);
  void panBy(Offset pixels);
  void navigate({
    required Offset previousFocal,
    required Offset focal,
    double scaleFactor = 1,
  });
}
