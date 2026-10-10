# Stair openings: direct generation

The BIM editor now exposes **Generate stair openings** in the menu and in the
Staircase opening palette. One click detects closed arrival-plan CAD contours,
adds typed polygon holes to their actual slabs and saves the project. There is
no scope setup, circulation drawing, preview selection or separate polygon
confirmation. Repeating the action preserves existing cuts. One Undo reverses
all cuts added by the operation.

The lowest level stays solid. A lower flight can locate the stair on the next
plan, but only an observed contour on that arrival plan can become a hole.
No bounding rectangle is substituted and no opening is carried into a roof.
Existing manual holes, multiple staircases and legacy lower-owned floor plates
are supported. Invalid or out-of-slab contours are skipped.

Column generation checks physical arrival openings, with no review flag or
mandatory circulation zones. A missing detected opening produces one short
message naming the level and a Generate button. Successful cutting continues
straight into the normal column-generation dialog. First-level slab geometry
never requires an arbitrary staircase opening.

Existing optional stair zones remain compatible with saved projects. Physical
arrival holes themselves also reserve space for support footprints, including
on a level whose overhead roof slab is solid.

Tests cover the original BIM staircase lines, a concave CAD contour, two stair
families, manual holes, repeated operation, first-level and roof exemptions,
invalid placement, support exclusion, direct UI generation, column continuation
and Undo.
