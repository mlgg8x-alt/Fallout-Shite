extends SceneTree
## Headless smoke test for the foundation slice. Boots the main scene, drives
## the player with simulated input and checks movement, crouch, slopes and
## interaction. Run with:
##   godot --headless --path . -s tests/smoke_test.gd
## Exits non-zero on any failure.

var _failures := 0
var _main: Node
var _player: Player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_player = _main.get_node("Player")
	await _frames(30)

	_check(_player.is_on_floor(), "player spawns on the floor")
	_check(_player.global_position.distance_to(Vector3(0, 0, 24)) < 0.2, "player spawns at PlayerSpawn")

	# Walk
	var start := _player.global_position
	await _hold(["move_forward"], 60)
	_check(absf(_player.get_horizontal_speed() - _player.walk_speed) < 0.2, "walk reaches walk_speed")
	_check(_player.global_position.z < start.z - 3.5, "walking forward moves along -Z")
	await _frames(30)
	_check(_player.get_horizontal_speed() < 0.05, "friction stops the player")

	# Sprint drains stamina
	var stamina_before := _player.stamina.current
	await _hold(["move_forward", "sprint"], 45)
	_check(absf(_player.get_horizontal_speed() - _player.sprint_speed) < 0.3, "sprint reaches sprint_speed")
	_check(_player.stamina.current < stamina_before - 5.0, "sprinting drains stamina")
	await _frames(30)

	# Jump
	var ground_y := _player.global_position.y
	var peak := ground_y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for i in 80:
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
	_check(peak > ground_y + 1.0, "jump clears 1 m (peak %.2f)" % (peak - ground_y))
	_check(_player.is_on_floor(), "player lands after jumping")

	# Crouch shrinks the capsule and returns
	await _hold(["crouch"], 30, false)
	var capsule := _player.collision_shape.shape as CapsuleShape3D
	_check(_player.is_crouching and is_equal_approx(capsule.height, _player.crouch_height), "crouch shrinks capsule")
	Input.action_release("crouch")
	await _frames(30)
	_check(not _player.is_crouching and is_equal_approx(capsule.height, _player.standing_height), "releasing crouch stands up")

	# Crouch tunnel: cannot stand up under the roof
	_teleport(Vector3(0, 0, -14), 0.0)
	await _hold(["crouch"], 20, false)
	await _hold(["crouch", "move_forward"], 90, false)
	_check(_player.global_position.z < -16.0, "crouched player enters tunnel")
	Input.action_release("crouch")
	await _frames(20)
	_check(_player.is_crouching, "player stays crouched under the tunnel roof")
	await _hold(["move_forward"], 150)
	await _frames(20)
	_check(not _player.is_crouching, "player stands after leaving the tunnel")

	# Stairs and ramp both reach the 3 m platforms
	_teleport(Vector3(12, 0, 6), 0.0)
	await _hold(["move_forward"], 150)
	_check(_player.global_position.y > 2.9, "stairs reach the east platform (y %.2f)" % _player.global_position.y)
	_teleport(Vector3(-12, 0, 10), 0.0)
	await _hold(["move_forward"], 180)
	_check(_player.global_position.y > 2.9, "ramp reaches the west platform (y %.2f)" % _player.global_position.y)

	# Interaction with the lever
	var prompts: Array[String] = []
	_player.interaction_prompt_changed.connect(func(p: String) -> void: prompts.append(p))
	var lamp: Light3D = _main.get_node("TestLevel/LeverLamp")
	_teleport(Vector3(2.5, 0, 21.5), 0.0)
	_player.head.rotation.x = deg_to_rad(-25.0)
	await _frames(10)
	_check(not prompts.is_empty() and prompts[-1] == "Turn light off", "looking at lever shows its prompt")
	var was_on := lamp.visible
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(5)
	_check(lamp.visible != was_on, "interacting toggles the lamp")
	_check(prompts[-1] == "Turn light on", "prompt updates after interacting")
	_player.head.rotation.x = 0.0
	await _frames(5)
	_check(prompts[-1] == "", "prompt clears when looking away")

	# Pause freezes the player
	_main.set_paused(true)
	var paused_pos := _player.global_position
	await _hold(["move_forward"], 20)
	_check(_player.global_position.is_equal_approx(paused_pos), "pause freezes the player")
	_main.set_paused(false)

	print("\nSmoke test: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(1 if _failures else 0)


func _check(ok: bool, label: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + label)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hold(actions: Array, frames: int, release := true) -> void:
	for a: String in actions:
		Input.action_press(a)
	await _frames(frames)
	if release:
		for a: String in actions:
			Input.action_release(a)


func _teleport(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
