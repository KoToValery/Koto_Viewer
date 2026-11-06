import '../../../core/l10n/l10n_extensions.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';

String componentDimensionCm(num metres) =>
    (metres * 100).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

String componentLabel(AppLocalizations l, ArchitectComponentDefinition d) {
  if (d is ScriptedComponentDefinition) {
    return d.defaultName.isEmpty
        ? l.architectComponentCustomName
        : d.defaultName;
  }
  return switch (d.id) {
    'sanitary_toilet_wall_hung' => l.architectComponentToiletWall,
    'sanitary_toilet_floor_standing' => l.architectComponentToiletFloor,
    'sanitary_washbasin_cabinet' ||
    'sanitary_vanity' => l.architectComponentVanity,
    'sanitary_bathtub' => l.architectComponentBathtub,
    'sanitary_shower' => l.architectComponentShower,
    'sanitary_linear_drain' => l.architectComponentLinearDrain,
    'sanitary_floor_drain' => l.architectComponentFloorDrain,
    'furniture_bed_double' => l.architectComponentBedDouble,
    'furniture_bed_single' => l.architectComponentBedSingle,
    'furniture_wardrobe' => l.architectComponentWardrobe,
    'furniture_dining_table' ||
    'furniture_dining_set' => l.architectComponentDining,
    'furniture_sofa' => l.architectComponentSofa,
    'furniture_office_desk' => l.architectComponentDesk,
    'kitchen_base_cabinet' => l.architectComponentKitchenBase,
    'kitchen_sink_cabinet' ||
    'kitchen_sink_unit' => l.architectComponentKitchenSink,
    'kitchen_refrigerator' => l.architectComponentFridge,
    'kitchen_cooktop_oven' => l.architectComponentCooktop,
    'service_ventSingle' => l.architectServiceVentSingle,
    'service_ventDouble' => l.architectServiceVentDouble,
    'service_ventTransition' => l.architectServiceVentTransition,
    'service_compactVent' => l.architectServiceCompactVent,
    'service_compactTransition' => l.architectServiceCompactTransition,
    'service_combinedRiser' => l.architectServiceCombinedRiser,
    'service_sewer' => l.architectServiceSewer,
    'service_water' => l.architectServiceWater,
    'service_dryRiser' => l.architectServiceDryRiser,
    'service_sleeve' => l.architectServiceSleeve,
    'service_chimney' => l.architectServiceChimney,
    'service_vent' => l.architectServiceVent,
    'service_fireplace' => l.architectServiceFireplace,
    _ => l.architectComponentCustomName,
  };
}

String componentCategoryLabel(
  AppLocalizations l,
  ArchitectComponentCategory c,
) => switch (c) {
  ArchitectComponentCategory.sanitary => l.architectCategorySanitary,
  ArchitectComponentCategory.furniture => l.architectCategoryFurniture,
  ArchitectComponentCategory.kitchen => l.architectCategoryKitchen,
  ArchitectComponentCategory.storage => l.architectCategoryStorage,
  ArchitectComponentCategory.office => l.architectCategoryOffice,
  ArchitectComponentCategory.equipment => l.architectCategoryEquipment,
  ArchitectComponentCategory.lighting => l.architectCategoryLighting,
  ArchitectComponentCategory.outdoor => l.architectCategoryOutdoor,
  ArchitectComponentCategory.doors => l.architectToolDoor,
  ArchitectComponentCategory.windows => l.architectToolWindow,
  ArchitectComponentCategory.services => l.architectCategoryServices,
};

String? serviceComponentHelp(AppLocalizations l, String id) => switch (id) {
  'service_ventSingle' || 'service_ventDouble' => l.architectServiceVentHelp,
  'service_ventTransition' => l.architectServiceTransitionHelp,
  'service_compactVent' ||
  'service_compactTransition' => l.architectServiceCompactHelp,
  'service_combinedRiser' => l.architectServiceCombinedHelp,
  'service_sewer' ||
  'service_water' ||
  'service_sleeve' => l.architectServicePipeHelp,
  'service_dryRiser' => l.architectServiceDryHelp,
  'service_chimney' => l.architectServiceChimneyHelp,
  'service_vent' => l.architectServiceVentOutletHelp,
  'service_fireplace' => l.architectServiceFireplaceHelp,
  _ => null,
};
