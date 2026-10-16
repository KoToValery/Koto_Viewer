import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elevation.dart';

String architectElevationLabel(
  AppLocalizations l,
  ArchitectElevation elevation,
  double northAngle,
) => switch (elevation.compassDirection(northAngle)) {
  ArchitectCompassDirection.north => l.architectFacadeNorth,
  ArchitectCompassDirection.northEast => l.architectFacadeNorthEast,
  ArchitectCompassDirection.east => l.architectFacadeEast,
  ArchitectCompassDirection.southEast => l.architectFacadeSouthEast,
  ArchitectCompassDirection.south => l.architectFacadeSouth,
  ArchitectCompassDirection.southWest => l.architectFacadeSouthWest,
  ArchitectCompassDirection.west => l.architectFacadeWest,
  ArchitectCompassDirection.northWest => l.architectFacadeNorthWest,
};
