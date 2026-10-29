/// User intent is independent of the tool exposed by a picked element.
enum ArchitectInteractionMode {
  navigation,
  contextEdit,
  singleSelect,
  multiSelect,
  drawing;

  bool get isManualSelection => this == singleSelect || this == multiSelect;
}
