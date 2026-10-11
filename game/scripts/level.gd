@tool
class_name Level
extends Node3D
## Root of every level scene. Holds the level's metadata; children are planets, stars,
## a Launcher, and a Portal. Build new levels by duplicating a level scene in the editor.

@export var level_name := "Untitled"
@export_multiline var hint := ""
@export var time_limit := 20.0
@export var camera_center := Vector2.ZERO
@export var camera_height := 70.0
## Ship is lost when it leaves this box around camera_center.
@export var bounds_half_extents := Vector2(52, 32)
## Use the distant key light (turn off when the level has its own star).
@export var use_sun := true
@export_range(0, 360) var default_aim_deg := 30.0
@export_range(0.05, 1.0) var default_power := 0.6


func bounds() -> Rect2:
	return Rect2(camera_center - bounds_half_extents, bounds_half_extents * 2.0)


func launcher() -> Launcher:
	for c in get_children():
		if c is Launcher:
			return c
	return null


func portal() -> Portal:
	for c in get_children():
		if c is Portal:
			return c
	return null


func stars() -> Array[Star]:
	var out: Array[Star] = []
	for c in get_children():
		if c is Star:
			out.append(c)
	return out
