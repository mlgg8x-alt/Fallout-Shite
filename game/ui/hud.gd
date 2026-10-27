class_name HUD
extends CanvasLayer
## In-game overlay: vitals bars, crosshair, interaction prompt, debug readout
## and the pause menu. Call [method bind_player] once the player exists.

signal resume_requested
signal quit_requested

const HEALTH_COLOR := Color(0.85, 0.22, 0.2)
const STAMINA_COLOR := Color(0.25, 0.85, 0.45)
const MANA_COLOR := Color(0.3, 0.5, 0.95)

var _player: Player

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var interact_prompt: Label = %InteractPrompt
@onready var debug_label: Label = %DebugLabel
@onready var pause_menu: Control = %PauseMenu


func _ready() -> void:
	_style_bar(health_bar, HEALTH_COLOR)
	_style_bar(stamina_bar, STAMINA_COLOR)
	_style_bar(mana_bar, MANA_COLOR)
	interact_prompt.hide()
	debug_label.hide()
	pause_menu.hide()
	%ResumeButton.pressed.connect(resume_requested.emit)
	%QuitButton.pressed.connect(quit_requested.emit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible


func _process(_delta: float) -> void:
	if debug_label.visible and _player:
		var pos := _player.global_position
		debug_label.text = "FPS %d\nState %s\nSpeed %.2f m/s\nPos %.1f, %.1f, %.1f" % [
			Engine.get_frames_per_second(),
			_player.get_move_state_name(),
			_player.get_horizontal_speed(),
			pos.x, pos.y, pos.z,
		]


func bind_player(player: Player) -> void:
	_player = player
	_bind_pool(player.health, health_bar)
	_bind_pool(player.stamina, stamina_bar)
	_bind_pool(player.mana, mana_bar)
	player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)


func set_paused(paused: bool) -> void:
	pause_menu.visible = paused
	if paused:
		%ResumeButton.grab_focus()


func _bind_pool(pool: StatPool, bar: ProgressBar) -> void:
	var update := func(current: float, max_value: float) -> void:
		bar.max_value = max_value
		bar.value = current
	pool.changed.connect(update)
	update.call(pool.current, pool.max_value)


func _on_interaction_prompt_changed(prompt: String) -> void:
	interact_prompt.visible = not prompt.is_empty()
	interact_prompt.text = "[E] %s" % prompt


func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.06, 0.7)
	bg.border_color = Color(0.6, 0.9, 0.7, 0.35)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
