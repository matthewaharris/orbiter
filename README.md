# Orbiter

A gravity-slingshot game: set your launch angle, power, and **timing**, then let planets, stars,
and space weather carry your ship to the portal. It plays in 2D, but every planet, star, and ship is
rendered in full 3D, and you can drop into a 3D chase cam mid-flight.

Inspired by the early-2000s flash slingshot games, with roguelite runs and KSP-style ship building planned.

- Design and roadmap: [`docs/PLAN.md`](docs/PLAN.md)
- Planet, star, and hazard design: [`docs/WORLD_SCHEME.md`](docs/WORLD_SCHEME.md)

## Run it

1. Install **Godot 4.7** (standard, not .NET): `winget install GodotEngine.GodotEngine`
2. Open Godot → **Import** → pick `game/project.godot` → **Run** (F5)

## Controls

| Input | Action |
|---|---|
| Drag the mouse (pull back from the slingshot) | Set angle and power |
| A/D or ←/→ | Fine-tune angle (hold **Shift** for extra fine) |
| W/S or ↑/↓ | Fine-tune power |
| **Space** | Launch |
| **C** / Tab | Toggle the 3D chase cam |
| **P** | Toggle the aim preview (off = hard mode) |
| **R** | Reset the ship |
| Enter / click | Next sector after a clear |

## Project layout

```
game/                 Godot project (open game/project.godot)
  scenes/main.tscn    Game shell: environment, sky, cameras
  scenes/levels/      One .tscn per level: edit these in the Godot editor
  scripts/            GDScript (planet.gd, star.gd, ship.gd, main.gd ...)
  shaders/            Procedural planet / star / sky / portal shaders
  data/planets/       PlanetType archetypes (.tres): tweak colors and weather in the inspector
  assets/models/      .glb models exported from Blender
tools/blender/        Python scripts that build the 3D models
docs/                 Design docs
```

## Making a level (great first task!)

1. In Godot, duplicate `scenes/levels/level_01.tscn`.
2. Drag planets around. They render live in the editor. Change `radius`, `mass`, and `planet_type`.
3. To make a moon, set **Orbit → Orbit Center** to another planet and give it an `orbit_radius`.
4. Add the new file to the `LEVELS` list in `scripts/game.gd`.
5. Check that it's beatable: `godot --headless --path game -- --solve`

## Rebuilding 3D models

```
blender --background --factory-startup --python tools/blender/build_ship.py
blender --background --factory-startup --python tools/blender/build_portal.py
```

Each script exports to `game/assets/models/` and renders a preview to `tools/blender/previews/`.

## Developer command-line flags

Pass these after `--`, for example `godot --path game -- --level=3 --chase`:

| Flag | Effect |
|---|---|
| `--level=N` | Start on level N |
| `--aim=DEG,POWER` | Preset the aim, e.g. `--aim=16,0.7` |
| `--launch-at=SEC` | Launch automatically after SEC seconds |
| `--chase` | Start in the chase cam |
| `--no-preview` | Start with the preview off |
| `--shot=out.png --shot-delay=SEC` | Save a screenshot, then quit |
| `--solve` | Brute-force every level and report how many launches win |

## Collaborating

- `main` should always run. Do your work on a branch: `git switch -c my-feature`.
- Open a pull request on GitHub, and get the other person to play it before merging.
