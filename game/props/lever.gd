extends StaticBody3D
## Test prop for the interaction system: toggles a light on and off.

@export var target_light: Light3D
@export var is_on := true

@onready var interactable: Interactable = $Interactable
@onready var handle: Node3D = $Handle


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	_apply()


func _on_interacted(_interactor: Node) -> void:
	is_on = not is_on
	_apply()


func _apply() -> void:
	if target_light:
		target_light.visible = is_on
	handle.rotation.x = deg_to_rad(-35.0 if is_on else 35.0)
	interactable.prompt = "Turn light off" if is_on else "Turn light on"
