"""Stage a production-only Godot project, optionally test it, and export Pages files.

The editor's MCP setup remains untouched. No developer bridge is shipped to browsers.
Requires the version in .godot-version and its official Web export templates.
"""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def prepare() -> Path:
    stage = ROOT / "build/web-project"
    stage.mkdir(parents=True, exist_ok=True)
    for folder in ("assets", "scenes", "scripts", "tests", "web"):
        shutil.copytree(ROOT / folder, stage / folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("*.import", "__pycache__"))
    config = (ROOT / "project.godot").read_text(encoding="utf-8")
    for section in ("autoload", "editor_plugins", "godot_mcp"):
        config = re.sub(rf"^\[{section}\]\s*\n.*?(?=^\[|\Z)", "", config,
                        flags=re.MULTILINE | re.DOTALL)
    assert "MCPGameBridge" not in config and "addons/" not in config
    (stage / "project.godot").write_text(config, encoding="utf-8")
    shutil.copy2(ROOT / "export_presets.cfg", stage / "export_presets.cfg")
    return stage

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable or absolute path")
    parser.add_argument("--test", action="store_true", help="Run both integration suites before export")
    args = parser.parse_args()
    version = (ROOT / ".godot-version").read_text().strip()
    actual = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not actual.startswith(version + "."):
        raise SystemExit(f"Expected Godot {version}; found {actual}")
    stage = prepare()
    command = [args.godot, "--headless", "--path", str(stage)]
    subprocess.run(command + ["--editor", "--import", "--quit"], check=True)
    if args.test:
        for suite in ("solo_regression", "minotaur_regression"):
            subprocess.run(command + ["--script", f"res://tests/{suite}.gd"], check=True)
    output = ROOT / "build/web"
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run(command + ["--export-release", "Web", str(output / "index.html")], check=True)
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not (output / name).is_file() or (output / name).stat().st_size == 0:
            raise SystemExit(f"Missing export output: {name}")
    page = (output / "index.html").read_text(encoding="utf-8")
    if "$GODOT_" in page or '"variant/thread_support":true' in page:
        raise SystemExit("Web shell was not correctly exported")
    (output / ".nojekyll").touch()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    (output / "build-info.json").write_text(json.dumps({
        "godot": version, "revision": revision, "threads": False,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Web build ready: {output}")
    print("Preview with: python -m http.server 8000 --directory build/web")

if __name__ == "__main__":
    main()
