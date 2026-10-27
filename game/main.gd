extends Node
## Game root: spawns the player into the level, wires the HUD and owns pause.
##
## Later steps hang global systems (save/load, quests) off autoloads rather
## than this node, so the level can be swapped freely.

@onready var level: Node3D = $TestLevel
@onready var player: Player = $Player
@onready var hud: HUD = $HUD


func _ready() -> void:
	var spawn := level.get_node_or_null("PlayerSpawn") as Node3D
	if spawn:
		player.global_transform = spawn.global_transform
	hud.bind_player(player)
	hud.resume_requested.connect(set_paused.bind(false))
	hud.quit_requested.connect(get_tree().quit)
	set_paused(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		# Clicking back into the window recaptures the mouse after alt-tab.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	hud.set_paused(paused)
