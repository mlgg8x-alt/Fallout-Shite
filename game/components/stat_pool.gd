class_name StatPool
extends Node
## A regenerating resource pool such as health, stamina or mana.
##
## The RPG layer will later drive [member max_value] and [member regen_rate]
## from character stats; for now they are plain exports.

signal changed(current: float, max_value: float)
signal depleted

@export var max_value := 100.0
## Units restored per second once the regen delay has passed.
@export var regen_rate := 0.0
## Seconds after spending before regeneration resumes.
@export var regen_delay := 1.0

var current := 0.0
var _regen_cooldown := 0.0


func _ready() -> void:
	current = max_value
	changed.emit(current, max_value)


func _process(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
		return
	if regen_rate > 0.0 and current < max_value:
		_set_current(current + regen_rate * delta)


## Spends [param amount] only if the pool can afford all of it.
func try_spend(amount: float) -> bool:
	if current < amount:
		return false
	drain(amount)
	return true


## Removes up to [param amount], clamping at zero, and pauses regeneration.
func drain(amount: float) -> void:
	if amount <= 0.0:
		return
	_regen_cooldown = regen_delay
	_set_current(current - amount)


func restore(amount: float) -> void:
	_set_current(current + amount)


func set_max(value: float, refill := false) -> void:
	max_value = maxf(value, 0.0)
	_set_current(max_value if refill else current)


func is_empty() -> bool:
	return current <= 0.0


func get_ratio() -> float:
	return current / max_value if max_value > 0.0 else 0.0


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_value)
	if is_equal_approx(clamped, current):
		return
	current = clamped
	changed.emit(current, max_value)
	if current <= 0.0:
		depleted.emit()
