@tool
class_name PlanetType
extends Resource
## An archetype: how a family of planets looks and how its environment behaves.
## Per-planet size, mass, and orbit live on the Planet node. See docs/WORLD_SCHEME.md.

enum Surface { ROCKY, OCEAN, GAS, ICE, LAVA }
enum Wind { NONE, SWIRL, PULSE }

@export var display_name := "Rocky"
@export var surface: Surface = Surface.ROCKY

@export_group("Surface Colors")
@export var color_low := Color(0.25, 0.2, 0.18)
@export var color_mid := Color(0.5, 0.42, 0.35)
@export var color_high := Color(0.8, 0.76, 0.7)
@export var emission_color := Color(0, 0, 0)
@export var emission_strength := 0.0
@export var noise_scale := 2.0
@export var band_count := 7.0
@export var polar_caps := 0.0

@export_group("Atmosphere")
@export var atmosphere_color := Color(0.4, 0.6, 1.0)
## Visual glow intensity of the atmosphere rim.
@export var atmosphere_glow := 1.0
## Gameplay: how far above the surface the drag zone reaches (units).
@export var atmosphere_height := 0.0
## Gameplay: drag coefficient at the surface.
@export var atmosphere_drag := 0.0

@export_group("Weather")
@export_range(0.0, 1.0) var cloud_coverage := 0.0
@export var cloud_color := Color(1, 1, 1)
@export var cloud_speed := 0.05
@export var storms := false
@export var embers := false
@export var rings := false
@export var ring_color := Color(0.85, 0.75, 0.6)

@export_group("Wind Field")
@export var wind: Wind = Wind.NONE
@export var wind_strength := 0.0
## Wind reaches out to this multiple of the planet radius.
@export var wind_reach := 3.0
@export var pulse_period := 4.0
@export var pulse_duration := 0.8
