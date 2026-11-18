"""Collect notices from the locked Rust packages downloaded for this build.

Run after building: python tools/collect_acadrust_licenses.py --cargo-home <path>
Only the local Cargo cache is read; nothing is downloaded or installed.
"""

import argparse
import os
from pathlib import Path
import tomllib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cargo-home", type=Path, default=Path(
        os.environ.get("CARGO_HOME", str(Path.home() / ".cargo"))))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    crate = root / "src" / "acadrust_converter"
    lock = tomllib.loads((crate / "Cargo.lock").read_text(encoding="utf-8"))
    registries = list((args.cargo_home / "registry" / "src").glob("*"))
    if not registries:
        raise SystemExit("Cargo sources are missing; build the converter first.")

    inventory = []
    texts = {}
    for package in lock["package"]:
        if "source" not in package:
            continue
        name = f'{package["name"]}-{package["version"]}'
        source = next((registry / name for registry in registries
                       if (registry / name).is_dir()), None)
        if source is None:
            # Cargo downloads only dependencies used by the selected platform.
            continue
        metadata = tomllib.loads((source / "Cargo.toml").read_text(encoding="utf-8"))
        license_name = metadata["package"].get("license", "see license file")
        url = f'https://crates.io/api/v1/crates/{package["name"]}/{package["version"]}/download'
        inventory.append(f"{name}: {license_name}\nSource: {url}")
        license_files = [path for path in source.iterdir() if path.is_file()
                         and path.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE", "THIRD_PARTY_NOTICES"))]
        if not license_files:
            raise SystemExit(f"No license text found for {name}; inspect its source before distributing.")
        for path in sorted(license_files):
            text = path.read_text(encoding="utf-8").strip()
            texts.setdefault(text, []).append(f"{name}/{path.name}")

    output = ["Rust converter dependency notices",
              "Generated from Cargo.lock and the Cargo sources downloaded for this build.",
              "Source archives contain the unmodified dependency source and original notices.",
              "", "\n\n".join(inventory)]
    for text, packages in texts.items():
        output.extend(["", "=" * 72, "Applies to: " + ", ".join(packages), "", text])
    (crate / "licenses" / "DEPENDENCIES.txt").write_text("\n".join(output) + "\n", encoding="utf-8")
    print(f"Collected {len(inventory)} package notices and {len(texts)} distinct license texts.")


if __name__ == "__main__":
    main()
