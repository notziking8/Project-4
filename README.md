# The Shifting Labyrinth

A playable Godot 4.7 test run based on the Team 3 story checkpoint. Open `project.godot` in Godot and press **F6** or **F5**.

## Play in a browser

The GitHub Pages address is **https://notziking8.github.io/Project-4/** once Pages is enabled and the first deployment succeeds. Use a desktop browser with WebGL 2, a keyboard and a mouse. Click **Launch game**, then press Enter on the title screen. The page includes fullscreen mode and a control reference. Progress lasts for the current play session.

### Enable hosting once

A repository administrator must open **Settings → Pages → Build and deployment → Source** and select **GitHub Actions**. Then run **Actions → Build and deploy game → Run workflow** on `main`. If a previous run built successfully but failed at Configure Pages, rerun that workflow after enabling Pages. A collaborator with push access alone cannot change this repository setting.

Every push to `main` then builds, tests and deploys automatically through `.github/workflows/pages.yml`. The workflow pins Godot to `.godot-version`, verifies the official engine and template downloads with SHA-512, runs both gameplay regression suites, and uploads the browser build as a Pages artifact. No deployment credentials need to be added to the repository.

The export uses Godot's single-threaded Web runtime, so GitHub Pages does not need cross-origin isolation headers. The production staging copy removes the local MCP autoload and editor plugin; the original editor project keeps its MCP integration. Generated exports and downloaded tools are excluded from Git.

### Build and preview locally

Install the Godot version listed in `.godot-version` and its matching export templates, plus Python 3.11 or later. From the repository directory:

```sh
python tools/export_web.py --godot godot --test
python -m http.server 8000 --directory build/web
```

Open **http://localhost:8000/**. Replace `godot` with the quoted absolute path to the Godot console executable if it is not on your PATH. Use this script for production exports so the development MCP bridge is removed from the staged project. Opening `index.html` directly as a local file will not work.

Browser validation covered launching the game, movement, the field guide, map, inventory keyboard focus, and responsive resizing in Chromium, with no browser console errors or failed asset requests. The exported game was served under a URL subdirectory to verify GitHub project-site paths.

## Game

Play as one explorer. Defeat the wardens in each sector, stand on its shrine to unlock the next sector, and defeat the Minotaur before reaching Athena's final shrine. The campaign has no companion switching or reunion requirement. Athena's dialogue and the ending reflect the solo journey.

The Minotaur's chamber stays physically sealed until **all 24 spirits across all three sectors are defeated**. Shifts, arrows and F cannot bypass the seal. Defeating the last spirit opens the chamber and starts a persistent hunt: the Minotaur tracks your position with AStar, even beyond sight range, and recalculates its route after shifts. Both maps show its live horn marker: **gray while sealed, pink while hunting**. It disappears when defeated. Respawning preserves the hunt; restarting restores the seal.

The prototype now uses an original generated pixel-art asset set under `assets/art/`. Environment assets are normalized to a 64-pixel grid, explorer sheets use exact 64 x 64 frames, UI icons use 32 x 32 frames, and the Minotaur/Athena sheets use 128 x 128 frames.

The shrine and equipment loop, shared health and inventory, armor modifiers, healing, spirit combat, shifting walls, flashlight hold, checkpoint respawn, and ending remain implemented in `scripts/game.gd`. Runtime presentation adds directional explorer animation, spirit/Minotaur/owl/Athena animation, moving-wall warning effects, ambient darkness, a warm active-explorer light, and light occlusion generated from the collision layout.

See `assets/art/ANIMATION_GUIDE.md` for the asset contract. The approved connected wall artwork is unchanged.

## Grid revamp

The labyrinth contains **162 chambers**, six times the previous chamber count, on a **109×55 tile grid** (6,976×3,520 pixels). There are 297 interior connections. Every sector participates in shifts every **6 seconds**, with a two-second amber warning. Each cycle normally opens and closes eight connections per sector. Once a sector boundary is unlocked, its connections shift too. The outer boundary, structural posts and sealed progression gates remain protected.

`scripts/maze_grid.gd` builds FloorTiles and ConnectedWalls TileMapLayers using the existing 16-variant neighbour atlas. TileData owns full-cell collision and light occlusion. All accessible chambers stay connected; the boss chamber is intentionally isolated until the spirits are defeated. Occupants and locked passages are protected. Tile updates, physics, navigation and route guidance agree after every shift.

Arrows are travelling projectiles launched from the same muzzle used to render the bow. Segment collision resolves the nearest wall or enemy, including large frame steps. Hold left click for repeated shots. Aim at enemies' bodies. Spirits use idle, patrol, chase, search, return and telegraphed attack states, with persistent AStar waypoint progress and repathing after shifts. Their stable hovering pose does not cycle through unrelated viewing angles.

The world is substantially darker, with a warm light attached to the player, wall shadows and a soft visibility falloff. Lighting is isolated from the HUD. Live text gives the current objective, remaining wardens, route directions and explanations for sealed gates.

| Control | Action |
| --- | --- |
| WASD / mouse | Move / aim |
| Hold left click | Fire arrows |
| F | Lock the aimed nearby passage in its **current open or closed state** for 10 seconds; then recharge for 5 seconds |
| E / R | Collect / consume a healing relic |
| Tab / X | Inventory / drop selected item at a shrine; click armor there to equip |
| M / G / H | Full map / toggle route trail / field guide |
| Escape | Close an overlay or pause |

Passage locking does not open walls or unlock bronze gates. To open a gate, clear that sector's wardens and activate its shrine. The map and field guide pause simulation while open.

See `POLISH_RULES.md` for the implementation contract and `tests/SOLO_VERIFICATION.md` for results. Run the regression suite with Godot's console executable: `--headless --path . --script res://tests/solo_regression.gd`. The earlier `grid_regression.gd` entry point delegates to this suite.

Boss-specific checks: `--headless --path . --script res://tests/minotaur_regression.gd`. Results are recorded in `tests/MINOTAUR_VERIFICATION.md`.
