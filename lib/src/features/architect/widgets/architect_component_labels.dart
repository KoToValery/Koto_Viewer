import '../../../core/l10n/l10n_extensions.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';

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
};
