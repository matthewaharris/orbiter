# Orbiter: notes for Claude

## Toolchain (Windows)
- Godot 4.7.2 console exe: `$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`
- Blender 5.2: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`
- MCP servers `godot` and `blender` are registered at user scope. The Blender MCP needs Blender open with the addon server started.

## Verify changes
- Script errors: `godot --headless --path game --import`
- Level solvability: `godot --headless --path game -- --solve` (every level must report > 0 solutions)
- Visuals: `godot --path game -- --level=N [--aim=DEG,POW --launch-at=S --chase] --shot=<scratch>/x.png --shot-delay=S`, then read the PNG.

## Conventions
- The gameplay plane is Z=0. The tactical camera looks down -Z. Ship models face -Z and their "up" is +Z.
- Gravity: accel = mass / r² (`Gravity.acceleration`). Non-gravity forces live in `environment_force()` on Planet/Star and are deliberately **not** in the aim preview.
- Timed world events (orbits, CMEs, geysers) read `WorldClock.time`, which is never reset on retry.
- Planet, Star, Portal, Launcher, and Level are `@tool` scripts. Generated children are created without an owner so they never get saved into scenes.
- Don't edit files with PowerShell `Get-Content`/`Set-Content`: it corrupts UTF-8 and adds BOMs. Use the Edit tool or Python.
- Bash heredocs with complex quoting fail in this environment. Write temp scripts to the scratchpad instead.
