# World Scheme: celestial bodies and their gameplay

Every body is built from **the same attribute set**, so the level generator (Phase 2) can mix them freely.
In code this is the `PlanetType` resource (`game/scripts/planet_type.gd`) plus per-instance overrides on `Planet`.

## Shared attributes

| Attribute | Gameplay effect | Visual expression |
|---|---|---|
| `mass` | Gravity strength (F = G·m / r²) | Size and color saturation hint at density |
| `radius` | Collision size | Mesh scale |
| `atmosphere_height` / `atmosphere_drag` | Drag zone: slows the ship and can enable aerobraking | Fresnel rim glow and its thickness |
| `wind_mode` (none / radial / swirl) + `wind_strength` | Pushes the ship outward (radial) or around the planet (swirl). **Not shown in the preview** | Cloud speed, storm particles |
| `hazard_heat` | Hull damage when close (Phase 2) | Lava cracks, embers |
| `orbit` (center, radius, period, phase) | Moving body: timing puzzles | Visible orbit ring |
| `surface` palette + noise params | None | Shader colors, band/terrain style |

## Planet archetypes

| Archetype | Mass | Atmosphere | Field | Hazard | Notes |
|---|---|---|---|---|---|
| **Rocky** | medium | thin | none | none | The baseline teaching planet |
| **Ocean / Storm world** | medium | thick | swirl winds | lightning (P2) | Swirl bends you around it like a current |
| **Gas Giant** | high, large radius | deep drag zone | swirl | crushing depth | Has moons; a drag zone gives aerobraking |
| **Ice world** | low | thin | radial geysers (pulses) | none | Cryo-geysers push the ship away on a timer |
| **Lava world** | high (dense, small) | thin, hot | none | heat | Embers and glowing cracks |
| **Iron / Magnetic world** | medium | none | magnetosphere | none | Inside the field you're **shielded from CMEs**: a safe harbor |
| **Ringed** | high | medium | none | rings = drag band | Rings slow you without killing you |

## Stars

| Star | Gravity | Solar wind (radial push) | Flares / CMEs | Notes |
|---|---|---|---|---|
| **Red dwarf** | low | weak | frequent small | Twitchy and short-telegraphed |
| **Yellow (G)** | medium | medium | occasional | Baseline |
| **Blue giant** | high | strong | rare, huge | Massive push; you have to use it |
| **White dwarf** | very high, tiny | weak | none | Brutal slingshot point |
| **Pulsar** | high | none | rotating beam | Beam = timed lethal or push lane |

**CMEs (coronal mass ejections)**: a star charges (it brightens and its particles intensify, which is the telegraph),
then releases an expanding shock ring. When the ring passes the ship, it gives a strong radial kick.
Depending on timing it ruins a shot or rescues it. This is the core **launch-timing** mechanic.

## Exotics (Phase 2+)
- **Black hole**: extreme gravity with an event horizon. Placed by levels, or deployed by the player through an upgrade.
- **Wormhole pair**: enter A, exit B with the same speed and a rotated heading.
- **Nebula cloud**: drag plus a sensor blackout (the preview is hidden inside it).
- **Asteroid belt**: lots of small bodies; collisions damage you.
- **Comet**: a fast-moving body with a tail that pushes you.

## Player upgrades (run-scoped) and ship parts (persistent)

| Category | Examples | Stat |
|---|---|---|
| Sensors | Short / long-range / quantum | Preview length (0–100%), CME warning |
| Engine | Kick booster, ion drive | Boost charges (tap Space mid-flight), boost strength |
| Hull | Light / armored | Mass, hull HP |
| Utility | Black hole deployer, magnetic shield, grav anchor | Special one-shot abilities |

Heavier ships launch slower for the same slingshot power but resist wind and CMEs more (force / mass).
That's the core KSP-style trade-off.
