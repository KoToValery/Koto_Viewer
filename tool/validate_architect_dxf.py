"""Independent CAD validation of architect_dxf_export_test.dart artifacts.

Run the Flutter test first, then: python tool/validate_architect_dxf.py
Test-only dependency: ezdxf. No Python or ezdxf is used by the app.
Native viewport semantics follow Autodesk's DXF VIEWPORT specification:
https://help.autodesk.com/cloudhelp/2024/ENU/AutoCAD-DXF/files/GUID-2602B0FB-02E4-4B9A-B03C-B1D904753D34.htm
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

import ezdxf
from ezdxf.math import Vec3
from ezdxf.render.hatching import hatch_entity
from ezdxf.xclip import XClip


def validate(directory: Path) -> dict:
    files = sorted(directory.glob("*.dxf"))
    assert files, f"No DXF artifacts in {directory}"
    report = {"ezdxf": ezdxf.__version__, "files": []}
    for path in files:
        doc = ezdxf.readfile(path)
        audit = doc.audit()
        assert not audit.errors and not audit.fixes, (
            path.name, [(e.code, e.message) for e in audit.errors + audit.fixes]
        )
        assert doc.dxfversion == "AC1027", path.name
        entities = [e for e in doc.entitydb.values() if e.is_alive]
        assert not any(e.dxftype() in {"IMAGE", "PDFUNDERLAY"} for e in entities)
        text = [e for e in entities if e.dxftype() == "MTEXT"]
        hatches = [e for e in entities if e.dxftype() == "HATCH"]
        for hatch in hatches:
            assert len(hatch.paths), (path.name, hatch.dxf.handle)
            if hatch.pattern:
                # Exercises native pattern serialization and numerical geometry.
                list(hatch_entity(hatch))
        for entity in entities:
            if entity.dxftype() == "INSERT" and entity.has_extension_dict:
                clip = XClip(entity)
                if clip.has_clipping_path:
                    assert clip.is_clipping_enabled
                    assert len(clip.get_block_clipping_path().vertices) >= 3
        paper_layouts = [l for l in doc.layouts if l.name != "Model"]
        viewports = [v for l in paper_layouts for v in l.query("VIEWPORT") if v.dxf.id > 1]
        for layout in paper_layouts:
            if not len(layout):
                continue
            assert layout.dxf.plot_paper_units == 1  # mm, independent of model units
            assert layout.dxf.paper_width > 0 and layout.dxf.paper_height > 0
        for index, viewport in enumerate(viewports):
            assert viewport.get_scale() > 0
            assert viewport.dxf.flags & 16384  # User's viewport scale is locked.
            assert f"KOTO_VIEW_{index + 1}" not in viewport.frozen_layers
            for other in range(len(viewports)):
                if other != index:
                    assert f"KOTO_VIEW_{other + 1}" in viewport.frozen_layers
                    prefix = f"KOTO_VIEW_{other + 1}_"
                    assert all(layer.dxf.name in viewport.frozen_layers for layer in doc.layers
                        if layer.dxf.name.startswith(prefix))
            if viewport.dxf.flags & 65536:
                polygon = doc.entitydb[viewport.dxf.clipping_boundary_handle]
                assert polygon.dxftype() == "LWPOLYLINE" and polygon.closed
                assert len(polygon) >= 3
        report["files"].append({"name": path.name, "units": doc.units,
            "auditErrors": 0, "auditFixes": 0, "nativeText": len(text),
            "nativeHatches": len(hatches), "paperViewports": len(viewports)})

    units = {"meters": 6, "centimeters": 5, "millimeters": 4, "feet": 2, "inches": 1}
    for name, expected in units.items():
        doc = ezdxf.readfile(directory / f"source_{name}.dxf")
        assert doc.units == expected
        assert any("Дневна" in e.text for e in doc.modelspace().query("MTEXT"))

    path = directory / "sheet_native.dxf"
    expected = json.loads(path.with_suffix(".expected.json").read_text(encoding="utf-8"))
    doc = ezdxf.readfile(path)
    layout = doc.layouts.get("A-01")
    assert layout.dxf.paper_width == expected["paperWidth"]
    assert layout.dxf.paper_height == expected["paperHeight"]
    viewports = [v for v in layout.query("VIEWPORT") if v.dxf.id > 1]
    assert [v.get_scale() for v in viewports] == expected["viewportScales"]
    result = viewports[0].get_transformation_matrix().transform(Vec3(expected["pointModel"]))
    assert result.distance(Vec3(expected["pointPaper"])) < 1e-9
    assert len(doc.entitydb[viewports[0].dxf.clipping_boundary_handle]) == 6

    doc = ezdxf.readfile(directory / "native_clips_hatches.dxf")
    insert = doc.modelspace().query("INSERT").first
    assert XClip(insert).is_clipping_enabled
    assert len(doc.modelspace().query("HATCH").first.paths) == 2
    assert "Кирилица" in doc.blocks[insert.dxf.name].query("MTEXT").first.text
    return report


def render(directory: Path) -> None:
    """Render DXF paper and the publisher PDF at equal paper size/resolution."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from ezdxf.addons.drawing import Frontend, RenderContext
    from ezdxf.addons.drawing.matplotlib import MatplotlibBackend
    from ezdxf.addons.drawing.properties import LayoutProperties
    from ezdxf.fonts import fonts

    class ViewportFrontend(Frontend):
        def draw_viewport(self, viewport):
            # ezdxf 1.4.x passes viewport layer overrides to top-level entities,
            # but recursive INSERT rendering reads self.ctx. Keep that context
            # consistent so nested native blocks obey the same frozen layers.
            previous = self.ctx
            try:
                self.ctx = previous.from_viewport(viewport)
                super().draw_viewport(viewport)
            finally:
                self.ctx = previous

    font_directory = Path(__file__).resolve().parents[1] / "assets" / "fonts"
    fonts.font_manager.build([str(font_directory)], support_dirs=False)
    for name in ("sheet_native", "phone_sheet"):
        doc = ezdxf.readfile(directory / f"{name}.dxf")
        layout = doc.layouts.get("A-01")
        width, height = layout.dxf.paper_width, layout.dxf.paper_height
        figure = plt.figure(figsize=(width / 25.4, height / 25.4), dpi=100)
        axis = figure.add_axes((0, 0, 1, 1))
        properties = LayoutProperties.from_layout(layout)
        properties.set_colors("#FFFFFF", "#000000")
        # Plotting omits nonprinting viewport boundaries, while still drawing
        # the model visible through each viewport on that nonprinting layer.
        def plotted(entity):
            return entity.dxftype() == "VIEWPORT" or bool(doc.layers.get(entity.dxf.layer).dxf.plot)
        ViewportFrontend(RenderContext(doc), MatplotlibBackend(axis)).draw_layout(
            layout, finalize=False, layout_properties=properties, filter_func=plotted)
        axis.set_xlim(0, width)
        axis.set_ylim(0, height)
        axis.set_aspect("equal")
        axis.axis("off")
        figure.savefig(directory / f"{name}_dxf.png", dpi=100, facecolor="white")
        plt.close(figure)
        if shutil.which("pdftoppm") and (directory / f"{name}.pdf").exists():
            subprocess.run(["pdftoppm", "-r", "100", "-png", "-singlefile",
                str(directory / f"{name}.pdf"), str(directory / f"{name}_pdf")], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=Path("build/architect_exports"))
    parser.add_argument("--render", action="store_true", help="Also render DXF/PDF comparison PNGs (matplotlib, Poppler).")
    args = parser.parse_args()
    result = validate(args.directory)
    output = args.directory / "dxf_validation.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Validated {len(result['files'])} DXF files; zero audit errors/fixes. Report: {output}")
    if args.render:
        render(args.directory)
