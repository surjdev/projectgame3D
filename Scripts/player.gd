extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

# --- Mouse look tuning ---
@export var mouse_sensitivity := 0.008
@export var mouse_smoothness := 12.0
@export var invert_y := false

# Pitch limits (deg in Inspector)
@export_range(-89.0, 0.0, 0.1) var pitch_min_deg := -80.0
@export_range(0.0, 89.0, 0.1)  var pitch_max_deg :=  80.0
var _pitch_min := deg_to_rad(pitch_min_deg)
var _pitch_max := deg_to_rad(pitch_max_deg)

# yaw/pitch targets
var _yaw_target := 0.0
var _pitch_target := 0.0
var _yaw := 0.0
var _pitch := 0.0

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var neck: Node3D       = $"Pivot/character-a2/character-a/Neck"
@onready var camera: Camera3D   = $"Pivot/character-a2/character-a/Neck/Camera3D"
@onready var anim: AnimationPlayer = $"Pivot/character-a2/AnimationPlayer"

var _was_on_floor := true

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# init aim from nodes
	_yaw = rotation.y
	_yaw_target = _yaw
	_pitch = camera.rotation.x
	_pitch_target = _pitch

	# neck holds only pitch
	neck.rotation.y = 0.0
	camera.rotation.z = 0.0

	# start idle
	if anim.has_animation("idle"):
		anim.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.relative.x
		var dy: float = mm.relative.y
		if invert_y: dy = -dy

		_yaw_target   -= dx * mouse_sensitivity
		_pitch_target -= dy * mouse_sensitivity
		_pitch_min = deg_to_rad(pitch_min_deg)
		_pitch_max = deg_to_rad(pitch_max_deg)
		_pitch_target = clamp(_pitch_target, _pitch_min, _pitch_max)

func _process(delta: float) -> void:
	var t := 1.0 - pow(0.0001, delta * mouse_smoothness)
	_yaw   = lerp_angle(_yaw, _yaw_target, t)
	_pitch = lerp(_pitch, _pitch_target, t)

	rotation.y = _yaw
	neck.rotation.y = 0.0
	camera.rotation.x = _pitch
	camera.rotation.z = 0.0

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if anim.has_animation("jump_start"):
			anim.play("jump_start", 0.06)   # crossfade 0.06s
			if anim.has_animation("jump_up"):
				anim.queue("jump_up")       # ต่อด้วยท่าลอยขึ้น

	# movement (หน้า = -Z -> กลับสัญญาณ y)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# --- animation state logic ---
	var is_moving := direction != Vector3.ZERO
	if is_on_floor():
		# just landed this frame
		if not _was_on_floor and anim.has_animation("land"):
			anim.play("land", 0.08)

		if is_moving:
			if anim.has_animation("walk"):
				anim.play("walk", 0.10)
		else:
			if anim.has_animation("idle"):
				anim.play("idle", 0.12)
	else:
		# in air
		if velocity.y > 0.0:
			if anim.has_animation("jump_up"):
				anim.play("jump_up", 0.06)
		else:
			if anim.has_animation("fall"):
				anim.play("fall", 0.06)

	_was_on_floor = is_on_floor()
