# Architectural starter wizard

The wizard has three steps: Units, Axes, Storeys. New wizard projects use centimetres and zero decimal places. Precision (0, 1, 2) is persisted per project, is editable in workspace settings and is used by distance displays and the drawing keypads. Geometry remains in metres; changing display precision does not round existing geometry.

Storeys start with one finished-floor reference at project zero. Elevations use signed metre marks (±0.00, +3.00); heights use the selected distance unit. Elevation marks retain at least two decimal places, increasing as needed for centimetre or millimetre input precision. Add Storey copies the previous height and places the new finished floor at the previous elevation plus its height. Editing a height moves all levels above it. Editing an elevation preserves other elevations and adjusts the adjacent heights. Levels must remain strictly ordered and heights finite and positive. The top storey height defines its upper reference even before another storey is added.

The user confirmed finished floor to finished floor as the height reference. It must not be described as clear room height. If the upper finished floor is at Z, its slab core top is Z minus the finish build-up above that core. The underside is lower by the core thickness and any layers below it. Clear height is measured from the lower finished floor to that underside or to a lower suspended ceiling. For example, a 3.00 m storey interval with 0.10 m upper finish build-up, 0.20 m slab and 0.02 m soffit finish gives 2.68 m clear height. These quantities belong to explicit slab/ceiling geometry and are not additional wizard fields. This change does not migrate existing slab offsets or infer a construction from a storey height.

No slab or empty-project ground plate is fabricated by the architectural 3D builder. Explicit slabs retain their geometry. Wall catalog configuration is removed from the wizard; detailed settings reorganization is the second stage.

Reference: [Graphisoft Story Settings](https://helpcenter.graphisoft.com/user-guide/137952/) defines elevation to Project Zero and Height to Story Above. The finished-floor reference is our confirmed project convention, not a claim that Archicad enforces that reference.

Visual checks: [Units](images/architect_starter_units_phone.png), [Storeys](images/architect_starter_storeys_phone.png).

Validation: 73 focused regression tests and the separate visual test passed; targeted Dart analysis is clean. Eight dimension-chain failures were reproduced on a separate HEAD snapshot. The older workspace-core test also references removed zone-editing APIs that this change does not touch.
