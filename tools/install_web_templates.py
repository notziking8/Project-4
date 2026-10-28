"""Verify an official Godot template archive and install only its Web templates."""
from pathlib import Path
import argparse
import hashlib
import os
import zipfile

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("checksums", type=Path)
    args = parser.parse_args()
    version = (Path(__file__).resolve().parents[1] / ".godot-version").read_text().strip()
    lines = args.checksums.read_text().splitlines()
    matching = [line.split()[0] for line in lines if line.split()[-1].lstrip("*") == args.archive.name]
    if len(matching) != 1:
        raise SystemExit("Archive not present in official checksum manifest")
    with args.archive.open("rb") as archive:
        checksum = hashlib.file_digest(archive, "sha512").hexdigest()
    if checksum.lower() != matching[0].lower():
        raise SystemExit("Export template checksum mismatch")
    if os.name == "nt":
        data = Path(os.environ["APPDATA"])
        destination = data / "Godot/export_templates" / (version + ".stable")
    else:
        data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        destination = data / "godot/export_templates" / (version + ".stable")
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive) as archive:
        names = [n for n in archive.namelist()
                 if n.startswith("templates/web") and n.endswith(".zip")]
        if not names:
            raise SystemExit("No Web templates found in archive")
        for name in names:
            (destination / Path(name).name).write_bytes(archive.read(name))
    print(f"Verified SHA-512; installed {len(names)} Web templates in {destination}")

if __name__ == "__main__":
    main()
