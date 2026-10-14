import 'package:flutter/widgets.dart';

/// Renders the fitted native scene. Input and camera limits belong to the
/// shared viewport and its navigation adapter, never to this widget.
class BimTransformRenderer extends StatelessWidget {
  const BimTransformRenderer({
    super.key,
    required this.transformationController,
    required this.child,
  });

  final TransformationController transformationController;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: transformationController,
    child: child,
    builder: (context, child) => Transform(
      transform: transformationController.value,
      alignment: Alignment.topLeft,
      child: child,
    ),
  );
}
