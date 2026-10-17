import '../../../core/l10n/generated/app_localizations.dart';
import 'cad_3d_camera.dart';
import 'cad_3d_mesh_painter.dart';

extension Cad3DShadingLabel on Cad3DShadingMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    Cad3DShadingMode.cadShadedEdges => l10n.shadingShadedEdges,
    Cad3DShadingMode.smoothShaded => l10n.cad3dShadingSmooth,
    Cad3DShadingMode.flatShaded => l10n.cad3dShadingFlat,
    Cad3DShadingMode.wireframe => l10n.shadingWireframe,
    Cad3DShadingMode.xray => l10n.cad3dShadingXray,
  };
}

extension Cad3DViewLabel on Cad3DViewPreset {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    Cad3DViewPreset.isometric => l10n.cad3dViewIsometric,
    Cad3DViewPreset.top => l10n.cad3dViewTop,
    Cad3DViewPreset.front => l10n.cad3dViewFront,
    Cad3DViewPreset.right => l10n.cad3dViewRight,
    Cad3DViewPreset.bottom => l10n.cad3dViewBottom,
    Cad3DViewPreset.back => l10n.cad3dViewBack,
  };
}

extension Cad3DThemeLabel on Cad3DTheme {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    Cad3DTheme.darkCad => l10n.cadThemeDarkCad,
    Cad3DTheme.blueprint => l10n.cad3dThemeBlueprint,
    Cad3DTheme.lightStudio => l10n.cad3dThemeStudio,
    Cad3DTheme.pureBlack => l10n.cad3dThemeBlack,
    Cad3DTheme.pureWhite => l10n.cad3dThemeWhite,
  };
}
