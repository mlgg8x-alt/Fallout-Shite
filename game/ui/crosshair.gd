@tool
extends Control
## Minimal crosshair: center dot plus four ticks, drawn in code so it scales cleanly.

@export var color := Color(0.85, 1.0, 0.9, 0.85)
@export var gap := 5.0
@export var length := 7.0
@export var thickness := 2.0
@export var dot_radius := 1.5


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, dot_radius, color)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * gap, c + dir * (gap + length), color, thickness)
