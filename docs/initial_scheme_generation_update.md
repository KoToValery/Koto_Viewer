# Initial structural scheme generation — 2026-10-08

Current implementation and measured comparisons: [Support placement update — 2026-10-10](bim_support_placement_optimization_2026_10_10.md).

The generator now keeps one preview and searches for a distinct next proposal on each press of **Next variant**. It uses a deterministic variant phase, ignores layout differences below 5 cm for duplicate detection, and searches at most twelve candidates per press. Changing spacing restarts the search. Existing and accepted elements remain fixed; only accepting the preview appends new native objects, using the existing Undo transaction.

## Placement order

1. Continue admissible lower supports.
2. Prioritize continuous detected wall runs within 1.5 m of typed stair/elevator openings. Try multiple wall windows and supplement with core columns. The former two-walls-per-direction limit does not suppress core walls.
3. Place columns at admissible axis intersections and wall junctions.
4. Sample solid wall runs and explicit axes for intermediate column candidates.
5. Repair coverage near slab boundaries/openings, inside slab fields, then at remaining distant candidates.

Every accepted section must fit the slab, avoid slab openings and occupied sections, and respect the separate column and parallel-wall spacing rules. Detected collinear wall gaps remain excluded. Explicit axes guide alignment; a generated section still requires an admissible detected wall strip. Undetected doors and architectural objects are not proven clear by an axis.

Coverage uses the nearest support footprint **within the same slab region**. Red samples exceed half the configured target spacing. This is a placement heuristic, not an effective span or cantilever calculation. Missing architectural/axis candidates leave visible residual gaps; the algorithm does not silently certify them. Sampling and element limits remain visible in the preview.

## Engineering scope

The existing preliminary seismic report is recalculated for the displayed proposal. No new EC2 compliance or deflection calculation is claimed. Full structural checks require a suitable structural model and design data. A geometric distance alone cannot establish deflection, punching resistance, seismic adequacy, or vertical load transfer.

Background references: [JRC Eurocode 8 worked examples](https://eurocodes.jrc.ec.europa.eu/publications/eurocode-8-seismic-design-buildings) and [The Concrete Centre: EC2 deflection](https://www.concretecentre.com/Codes/Design-Codes/Eurocode-2/Deflection.aspx). These references are not a declaration of compliance with a particular edition or National Annex.

## Validation

Regression coverage includes stair-core walls on four sides, blocked wall midpoints, long isolated axes and edge supports, wall gaps, separate slab regions, unit/order invariance, distinct alternatives, invalid settings, unchanged manual objects, JSON/export, acceptance, cancellation and Undo. Real-project engineering review remains necessary; automated tests use synthetic geometry.

## GitHub reconciliation

Reconciled onto `origin/main` at `3b2013d`, including the four commits following `00edf0e`. Preserved upstream stair-opening tools, foundations visibility, wall closure rendering and architectural hatch fills. The single-preview dialog retains the paired-wall and generous-density switches.

Core supports are placed first; the upstream distributed pairing and shortened-wall rescue passes follow. Pairing also tries alternative windows when a wall midpoint is blocked. Generous mode uses denser intermediate candidates and a tighter coverage target; sparse mode retains the user spacing. The expanded upstream element and attempt limits remain in force alongside bounded coverage sampling.

A CAD-unit invariance regression exposed rounding differences at half a 0.1 mm when generating IDs; coordinate formatting now normalizes sub-nanometre floating-point noise first. The original local changes remain recoverable in the named Git stash created before the fast-forward.
