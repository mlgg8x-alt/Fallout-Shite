class_name Player
extends CharacterBody3D
## First-person player controller: walk, sprint, jump, crouch and mouse look.
##
## Origin sits at the feet. Combat, stats and inventory attach later as child
## components; this script only owns movement, camera and interaction.

signal interaction_prompt_changed(prompt: String)

enum MoveState { IDLE, WALK, SPRINT, CROUCH, AIR }

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var crouch_speed := 2.2
@export var ground_acceleration := 50.0
@export var ground_friction := 40.0
@export var air_acceleration := 8.0

@export_group("Jump")
@export var jump_velocity := 4.8
## Grace period after walking off a ledge where a jump still counts.
@export var coyote_time := 0.12
## A jump pressed this long before landing fires on touchdown.
@export var jump_buffer_time := 0.12
@export var jump_stamina_cost := 8.0

@export_group("Sprint")
@export var sprint_stamina_per_second := 15.0

@export_group("Crouch")
@export var standing_height := 1.8
@export var crouch_height := 1.1
@export var crouch_transition_speed := 10.0
@export var toggle_crouch := false

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var base_fov := 75.0
@export var sprint_fov := 83.0
@export var head_bob_amount := 0.04
@export var head_bob_frequency := 2.2
## Distance from the top of the capsule down to eye level.
@export var eye_offset := 0.15

@export_group("Interaction")
@export var interact_distance := 2.5

var move_state := MoveState.IDLE
var is_crouching := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _current_height := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _bob_time := 0.0
var _crouch_toggled := false
var _interaction_target: Interactable
var _interaction_prompt := ""

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var health: StatPool = $Stats/Health
@onready var stamina: StatPool = $Stats/Stamina
@onready var mana: StatPool = $Stats/Mana


func _ready() -> void:
	_current_height = standing_height
	_apply_height()
	camera.fov = base_fov
	interact_ray.target_position = Vector3(0.0, 0.0, -interact_distance)
	interact_ray.add_exception(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("interact") and _interaction_target:
		_interaction_target.interact(self)
	elif toggle_crouch and event.is_action_pressed("crouch"):
		_crouch_toggled = not _crouch_toggled


func _physics_process(delta: float) -> void:
	_update_crouch(delta)
	_update_timers(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_try_jump()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var sprinting := _can_sprint(input_dir)
	_update_move_state(input_dir, sprinting)

	var target := wish_dir * _get_target_speed()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float
	if not is_on_floor():
		rate = air_acceleration
	elif wish_dir != Vector3.ZERO:
		rate = ground_acceleration
	else:
		rate = ground_friction
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if sprinting:
		stamina.drain(sprint_stamina_per_second * delta)

	move_and_slide()

	_update_camera_effects(delta)
	_update_interaction_target()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_move_state_name() -> String:
	return MoveState.keys()[move_state]


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	if is_crouching and not _can_stand():
		return
	# Jumping out of a crouch stands the player up.
	_crouch_toggled = false
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	stamina.drain(jump_stamina_cost)


func _can_sprint(input_dir: Vector2) -> bool:
	return (
		Input.is_action_pressed("sprint")
		and is_on_floor()
		and not is_crouching
		and input_dir.y < 0.0  # moving forward
		and not stamina.is_empty()
	)


func _update_move_state(input_dir: Vector2, sprinting: bool) -> void:
	if not is_on_floor():
		move_state = MoveState.AIR
	elif is_crouching:
		move_state = MoveState.CROUCH
	elif sprinting:
		move_state = MoveState.SPRINT
	elif input_dir != Vector2.ZERO:
		move_state = MoveState.WALK
	else:
		move_state = MoveState.IDLE


func _get_target_speed() -> float:
	match move_state:
		MoveState.SPRINT:
			return sprint_speed
		MoveState.CROUCH:
			return crouch_speed
	return walk_speed


func _update_crouch(delta: float) -> void:
	var wants_crouch := _crouch_toggled if toggle_crouch else Input.is_action_pressed("crouch")
	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

	var target_height := crouch_height if is_crouching else standing_height
	if is_equal_approx(_current_height, target_height):
		return
	var previous := _current_height
	_current_height = move_toward(
		_current_height, target_height, crouch_transition_speed * delta * (standing_height - crouch_height)
	)
	# Never grow into a ceiling mid-transition.
	if _current_height > previous and test_move(global_transform, Vector3.UP * (_current_height - previous)):
		_current_height = previous
		is_crouching = true
		return
	_apply_height()


func _can_stand() -> bool:
	var clearance := standing_height - _current_height
	return clearance <= 0.0 or not test_move(global_transform, Vector3.UP * clearance)


func _apply_height() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	capsule.height = _current_height
	collision_shape.position.y = _current_height * 0.5
	head.position.y = _current_height - eye_offset


func _update_camera_effects(delta: float) -> void:
	var target_fov := sprint_fov if move_state == MoveState.SPRINT else base_fov
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-8.0 * delta))

	var speed := get_horizontal_speed()
	var bob_offset := Vector3.ZERO
	if is_on_floor() and speed > 0.5:
		_bob_time += delta * speed * head_bob_frequency
		bob_offset = Vector3(cos(_bob_time * 0.5) * head_bob_amount * 0.5, sin(_bob_time) * head_bob_amount, 0.0)
	camera.position = camera.position.lerp(bob_offset, 1.0 - exp(-12.0 * delta))


func _update_interaction_target() -> void:
	var target: Interactable = null
	if interact_ray.is_colliding():
		target = Interactable.find_on(interact_ray.get_collider() as Node)
		if target and not target.enabled:
			target = null
	_interaction_target = target
	# Compare text, not targets, so a prop that changes its prompt updates the HUD.
	var prompt := target.prompt if target else ""
	if prompt != _interaction_prompt:
		_interaction_prompt = prompt
		interaction_prompt_changed.emit(prompt)
