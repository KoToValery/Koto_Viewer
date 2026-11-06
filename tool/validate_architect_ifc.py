"""Independent schema/geometry checks for architectural exchange fixtures.

Run Flutter's architect_ifc_export_test.dart first to generate build artifacts.
Dependencies in the validation environment: ifcopenshell>=0.8, pytest, numpy.
This tool checks EXPRESS rules as well as the independently tessellated bodies;
it does not claim validation in a commercial BIM authoring application.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import ifcopenshell
import ifcopenshell.geom
import ifcopenshell.util.element
import ifcopenshell.validate
import numpy as np


def validate(path: Path) -> dict:
    model = ifcopenshell.open(str(path))
    logger = ifcopenshell.validate.json_logger()
    ifcopenshell.validate.validate(model, logger, express_rules=True)
    errors = [
        {"attribute": message.get("attribute"), "message": str(message["message"])}
        for message in logger.statements
    ]
    settings = ifcopenshell.geom.settings()
    settings.set(settings.USE_WORLD_COORDS, True)
    void_hosts = {relation.RelatingBuildingElement.id() for relation in model.by_type("IfcRelVoidsElement")}
    products = []
    for element in model.by_type("IfcProduct"):
        representation = element.Representation
        if not representation or not any(r.RepresentationIdentifier == "Body" for r in representation.Representations):
            continue
        bodies = [r for r in representation.Representations if r.RepresentationIdentifier == "Body"]
        if len(bodies) != 1:
            errors.append({"element": str(element), "message": f"expected one additive Body, got {len(bodies)}"})
        is_surface = any(item.is_a("IfcOpenShell") for item in model.traverse(representation))
        record = {"class": element.is_a(), "sourceId": getattr(element, "Tag", None),
                  "surfaceRepresentation": is_surface}
        try:
            shape = ifcopenshell.geom.create_shape(settings, element)
            vertices = np.array(shape.geometry.verts).reshape((-1, 3))
            faces = np.array(shape.geometry.faces).reshape((-1, 3))
            if len(vertices) == 0 or len(faces) == 0:
                raise ValueError("empty tessellation")
            if not np.isfinite(vertices).all():
                raise ValueError("non-finite tessellation")
            a, b, c = (vertices[faces[:, i]] for i in range(3))
            signed_volume = np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6
            area = np.linalg.norm(np.cross(b - a, c - a), axis=1).sum() / 2
            record.update({"vertices": len(vertices), "triangles": len(faces),
                           "volume": float(abs(signed_volume)),
                           "surfaceArea": float(area),
                           "min": vertices.min(axis=0).tolist(),
                           "max": vertices.max(axis=0).tolist()})
            if record["volume"] <= 1e-12 and not is_surface:
                errors.append({"element": str(element), "message": "zero-volume body"})
            # Verify normal import receives every component. Valid EXPRESS and
            # a nonempty product mesh did not catch alternative Body reps that
            # silently omitted 108 door / 88 window triangles. Void-cut hosts
            # legitimately differ from their uncut source items; their cut
            # result is checked separately by exact volumes below.
            if element.id() not in void_hosts:
                item_triangles, item_area = 0, 0.0
                for body in bodies:
                    for item in body.Items:
                        item_shape = ifcopenshell.geom.create_shape(settings, item)
                        item_geometry = getattr(item_shape, "geometry", item_shape)
                        iv = np.array(item_geometry.verts).reshape((-1, 3))
                        it = np.array(item_geometry.faces).reshape((-1, 3))
                        item_triangles += len(it)
                        ia, ib, ic = (iv[it[:, i]] for i in range(3))
                        item_area += np.linalg.norm(np.cross(ib - ia, ic - ia), axis=1).sum() / 2
                record.update({"componentTriangles": item_triangles, "componentSurfaceArea": float(item_area)})
                if len(faces) != item_triangles:
                    errors.append({"element": str(element),
                        "message": f"product retains {len(faces)} of {item_triangles} component triangles"})
                if abs(area - item_area) > max(1e-7, item_area * 1e-6):
                    errors.append({"element": str(element), "message": "product omits component surface area"})
        except Exception as error:
            errors.append({"element": str(element), "message": str(error)})
        products.append(record)

    all_guids = [root.GlobalId for root in model.by_type("IfcRoot")]
    if len(all_guids) != len(set(all_guids)):
        errors.append({"message": "duplicate GlobalId"})
    for relation in model.by_type("IfcRelVoidsElement"):
        if not relation.RelatedOpeningElement.Representation:
            errors.append({"message": "void has no geometry", "element": str(relation)})
    if model.by_type("IfcProject")[0].UnitsInContext.Units[0].Name != "METRE":
        errors.append({"message": "model units are not metres"})

    if "all_categories" in path.name:
        def product(source_id):
            return next(p for p in products if p["sourceId"] == source_id)

        # Slab: 6x5x.2 minus a 1x1x.2 opening; independently exercises the
        # relation-based subtraction instead of a twice-cut source mesh.
        if abs(product("slab-1")["volume"] - 5.8) > 1e-5:
            errors.append({"message": "slab void volume differs from 5.8 m3"})
        # x,-y,z and storey -.25m must be applied exactly once.
        if abs(product("slab-1")["min"][1] + 5) > 1e-6:
            errors.append({"message": "plan Y was not reflected into CAD coordinates"})
        if abs(product("slab-1")["min"][2] + .45) > 1e-6:
            errors.append({"message": "storey elevation or slab thickness applied incorrectly"})
        # The sloped roof is a 0.2m normal layer, not 0.2m vertical thickness.
        expected_roof_volume = 6 * 5 * .2 / np.cos(np.deg2rad(25))
        if abs(product("roof-1:body")["volume"] - expected_roof_volume) > 1e-5:
            errors.append({"message": "sloped roof normal thickness differs"})
        # This host has two filling relations and exactly one rectangular void
        # per filling; gross volume 6*.3*2.8, door .9*2, window1.2*1.4.
        wall_volume = 6 * .3 * 2.8 - .3 * (.9 * 2 + 1.2 * 1.4)
        if abs(product("wall-1")["volume"] - wall_volume) > 1e-5:
            errors.append({"message": "wall openings missing or subtracted twice"})
    if "topology" in path.name:
        if len(products) != 1 or abs(products[0]["volume"] - 1) > 1e-8:
            errors.append({"message": "T-junction/winding repair changed unit cube volume"})
        if any(product["surfaceRepresentation"] for product in products):
            errors.append({"message": "closed unit cube exported as an open surface"})
    if "mixed" in path.name:
        hybrid = "hybrid" in path.name
        expected_triangles, expected_area = (26, 13) if hybrid else (14, 7)
        if len(products) != 1 or products[0]["triangles"] != expected_triangles:
            errors.append({"message": "mixed product lost a closed cube or its open sheet"})
        if len(products) == 1 and abs(products[0]["surfaceArea"] - expected_area) > 1e-8:
            errors.append({"message": "mixed product surface area changed"})
    return {"file": str(path), "schema": model.schema,
            "schemaIdentifier": model.schema_identifier,
            "schemaVersion": model.schema_version,
            "validationSchemaTarget": "IFC4 ADD2 TC1" if model.schema == "IFC4" else "IFC2x3 TC1",
            "errors": errors,
            "products": products, "productsWithGeometry": len(products),
            "storeys": len(model.by_type("IfcBuildingStorey")),
            "voids": len(model.by_type("IfcRelVoidsElement"))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path)
    parser.add_argument("--output", type=Path,
                        default=Path("build/architect_export_validation/ifc_validation.json"))
    args = parser.parse_args()
    paths = args.files or sorted(Path("build/architect_export_validation").glob("architect_*.ifc"))
    if not paths:
        parser.error("No generated IFC fixtures; run architect_ifc_export_test.dart first")
    results = [validate(path) for path in paths]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    for result in results:
        print(f"{Path(result['file']).name}: {result['schema']}, "
              f"{result['productsWithGeometry']} bodies, "
              f"{len(result['errors'])} errors")
        for error in result["errors"][:8]:
            print(" ", error)
    return int(any(result["errors"] for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
