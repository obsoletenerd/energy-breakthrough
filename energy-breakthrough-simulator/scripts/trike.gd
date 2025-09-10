extends CharacterBody3D
class_name TrikeController

@export var reset_drop_height: float = 0.5  # meters above spawn when resetting
var _spawn_transform: Transform3D           # recorded at _ready()

# Assign Wheel Nodes
@export var wheel_fl_path: NodePath
@export var wheel_fr_path: NodePath
@export var wheel_r_path: NodePath

# If you split yaw (pivot) vs roll (mesh), point these to the mesh nodes otherwise leave empty to fall back.
@export var wheel_fl_mesh_path: NodePath
@export var wheel_fr_mesh_path: NodePath
@export var wheel_r_mesh_path: NodePath

# Control mode
enum ControlMode { KEYBOARD, SERIAL }
@export var control_mode: ControlMode = ControlMode.KEYBOARD

# Serial input handling
@export var invert_steer: bool = false
@export var serial_max_angle_deg: float = 30.0       # maps ANGLE from serial data to axis
@export var serial_speed_to_mps: float = 0.5         # converts SPEED from serial data into m/s
@export var serial_angle_timeout_ms: int = 250       # if stale, steering input is treated as 0 (recenters)
@export var serial_speed_timeout_ms: int = 250       # if stale, speed isn't commanded (only friction applies)

# Steering
@export_range(1.0, 60.0, 0.1) var max_steer_deg: float = 25.0
@export_range(10.0, 540.0, 1.0) var steer_speed_deg_per_s: float = 240.0
@export_range(10.0, 540.0, 1.0) var return_speed_deg_per_s: float = 180.0
@export var input_deadzone: float = 0.05

# Wheel roll visuals
@export var wheel_radius_m: float = 0.165
@export var roll_direction: int = 1 # flip if rolling backwards

# Simple vehicle dynamics
@export var wheel_base_m: float = 1.2
@export var max_speed_mps: float = 12.0
@export var accel_mps2: float = 4.0
@export var brake_mps2: float = 6.0
@export var roll_friction_mps2: float = 1.2
@export var gravity_mps2: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

# Runtime (cached nodes/rotations)
var _wheel_fl: Node3D
var _wheel_fr: Node3D
var _wheel_r: Node3D
var _orig_rot_fl: Vector3
var _orig_rot_fr: Vector3
var _orig_rot_r: Vector3

var _wheel_fl_mesh: Node3D
var _wheel_fr_mesh: Node3D
var _wheel_r_mesh: Node3D
var _orig_rot_fl_mesh: Vector3
var _orig_rot_fr_mesh: Vector3
var _orig_rot_r_mesh: Vector3

# Steering state
var _current_steer_deg: float = 0.0
var _target_steer_deg: float = 0.0

# Longitudinal state
var _speed_mps: float = 0.0

# Wheel roll angles
var _roll_fl_rad: float = 0.0
var _roll_fr_rad: float = 0.0
var _roll_r_rad: float = 0.0

# Latest serial data + freshness
var _serial_has_angle: bool = false
var _serial_axis: float = 0.0
var _serial_angle_time_ms: int = -1

var _serial_has_speed: bool = false
var _serial_speed_mps: float = 0.0
var _serial_speed_time_ms: int = -1

func _ready() -> void:
	_spawn_transform = global_transform

	_wheel_fl = _require_node(wheel_fl_path, "Wheel-FL")
	_wheel_fr = _require_node(wheel_fr_path, "Wheel-FR")
	_wheel_r  = _optional_node(wheel_r_path)

	_orig_rot_fl = _wheel_fl.rotation
	_orig_rot_fr = _wheel_fr.rotation
	if _wheel_r: _orig_rot_r = _wheel_r.rotation

	_wheel_fl_mesh = _get_or_fallback(wheel_fl_mesh_path, _wheel_fl)
	_wheel_fr_mesh = _get_or_fallback(wheel_fr_mesh_path, _wheel_fr)
	_wheel_r_mesh  = _get_or_fallback(wheel_r_mesh_path, _wheel_r)

	_orig_rot_fl_mesh = _wheel_fl_mesh.rotation
	_orig_rot_fr_mesh = _wheel_fr_mesh.rotation
	if _wheel_r_mesh: _orig_rot_r_mesh = _wheel_r_mesh.rotation

func _physics_process(delta: float) -> void:
	# Steering
	var axis: float = 0.0
	match control_mode:
		ControlMode.KEYBOARD:
			var left: float  = Input.get_action_strength("steer_left")
			var right: float = Input.get_action_strength("steer_right")
			axis = clampf(right - left, -1.0, 1.0)
		ControlMode.SERIAL:
			axis = _axis_from_serial()

	if absf(axis) < input_deadzone: axis = 0.0
	if invert_steer: axis = -axis

	_target_steer_deg = axis * max_steer_deg
	var speed_deg_per_s: float = (return_speed_deg_per_s if axis == 0.0 else steer_speed_deg_per_s)
	_current_steer_deg = _move_toward_angle(_current_steer_deg, _target_steer_deg, speed_deg_per_s * delta)

	_apply_steer_to_wheel(_wheel_fl, _orig_rot_fl, _current_steer_deg)
	_apply_steer_to_wheel(_wheel_fr, _orig_rot_fr, _current_steer_deg)

	# Throttle/Speed
	match control_mode:
		ControlMode.KEYBOARD:
			var thr: float = Input.get_action_strength("throttle")
			var brk: float = Input.get_action_strength("brake")
			var accel: float = accel_mps2 * thr - brake_mps2 * brk
			_speed_mps += accel * delta
		ControlMode.SERIAL:
			_apply_serial_speed(delta) # only changes speed if fresh SPEED was received

	# Rolling friction and deadband
	if _speed_mps > 0.0:
		_speed_mps = maxf(0.0, _speed_mps - roll_friction_mps2 * delta)
	elif _speed_mps < 0.0:
		_speed_mps = minf(0.0, _speed_mps + roll_friction_mps2 * delta)
	if absf(_speed_mps) < 0.02: _speed_mps = 0.0

	# Clamp top speed
	_speed_mps = clampf(_speed_mps, -0.25 * max_speed_mps, max_speed_mps)

	# Heading and movement
	var steer_rad: float = deg_to_rad(_current_steer_deg)
	var yaw_rate: float = 0.0
	if absf(steer_rad) > 0.0001 and wheel_base_m > 0.0001:
		yaw_rate = (_speed_mps / wheel_base_m) * tan(steer_rad)
	rotation.y += yaw_rate * delta

	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var horizontal_velocity: Vector3 = forward * _speed_mps

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y += -gravity_mps2 * delta

	# Wheel roll visuals
	if wheel_radius_m > 0.0001:
		var dist: float = _speed_mps * delta
		var dtheta: float = roll_direction * (dist / wheel_radius_m)
		_roll_fl_rad = fmod(_roll_fl_rad + dtheta, TAU)
		_roll_fr_rad = fmod(_roll_fr_rad + dtheta, TAU)
		_roll_r_rad  = fmod(_roll_r_rad  + dtheta, TAU)

		_apply_roll_to_mesh(_wheel_fl_mesh, _orig_rot_fl_mesh, _roll_fl_rad)
		_apply_roll_to_mesh(_wheel_fr_mesh, _orig_rot_fr_mesh, _roll_fr_rad)
		if _wheel_r_mesh: _apply_roll_to_mesh(_wheel_r_mesh, _orig_rot_r_mesh, _roll_r_rad)

	move_and_slide()
	if is_on_floor(): velocity.y = 0.0

# Called by the serial bridge whenever a line is parsed.
func update_serial(angle_present: bool, angle_deg: float, speed_present: bool, speed_raw: float) -> void:
	# ANGLE
	if angle_present:
		var axis: float = clampf(angle_deg / max(serial_max_angle_deg, 0.001), -1.0, 1.0)
		if invert_steer: axis = -axis
		_serial_axis = axis
		_serial_has_angle = true
		_serial_angle_time_ms = Time.get_ticks_msec()

	# SPEED
	if speed_present:
		_serial_speed_mps = clampf(speed_raw * serial_speed_to_mps, 0.0, max_speed_mps)
		_serial_has_speed = true
		_serial_speed_time_ms = Time.get_ticks_msec()

# Use fresh serial ANGLE or 0 (recenters) if stale/missing
func _axis_from_serial() -> float:
	if _serial_has_angle:
		var age := Time.get_ticks_msec() - _serial_angle_time_ms
		if age <= serial_angle_timeout_ms:
			return _serial_axis
	# stale or never seen means no steer input (targets center via return speed)
	return 0.0

# Apply fresh serial SPEED by accelerating/braking toward target or ignore if stale/missing
func _apply_serial_speed(delta: float) -> void:
	if _serial_has_speed:
		var age := Time.get_ticks_msec() - _serial_speed_time_ms
		if age <= serial_speed_timeout_ms:
			var diff: float = _serial_speed_mps - _speed_mps
			var a: float = (accel_mps2 if diff > 0.0 else brake_mps2)
			var step: float = a * delta
			if absf(diff) <= step:
				_speed_mps = _serial_speed_mps
			else:
				_speed_mps += signf(diff) * step
		# if stale do nothing this frame (only friction applies)

# Helper functions
func _apply_steer_to_wheel(wheel: Node3D, original_rot: Vector3, steer_deg: float) -> void:
	var rot: Vector3 = original_rot
	rot.y = original_rot.y + deg_to_rad(steer_deg)
	wheel.rotation = rot

func _apply_roll_to_mesh(mesh_node: Node3D, original_rot: Vector3, roll_rad: float) -> void:
	var r: Vector3 = original_rot
	r.x = original_rot.x + roll_rad
	mesh_node.rotation = r

func _move_toward_angle(from_deg: float, to_deg: float, step_deg: float) -> float:
	if from_deg == to_deg: return from_deg
	var s: float = (1.0 if to_deg > from_deg else -1.0)
	var next_val: float = from_deg + s * step_deg
	if (s > 0.0 and next_val > to_deg) or (s < 0.0 and next_val < to_deg):
		return to_deg
	return next_val

func _require_node(path: NodePath, label: String) -> Node3D:
	if path.is_empty():
		push_error("%s path not assigned on TrikeController" % label)
		return Node3D.new()
	var n: Node = get_node_or_null(path)
	if n == null:
		push_error("Could not find %s at %s" % [label, str(path)])
		return Node3D.new()
	return n as Node3D

func _optional_node(path: NodePath) -> Node3D:
	if path.is_empty(): return null
	return get_node_or_null(path) as Node3D

func _get_or_fallback(path: NodePath, fallback: Node3D) -> Node3D:
	if path.is_empty(): return fallback
	var n := get_node_or_null(path)
	return (n as Node3D) if n != null else fallback
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC by default
		_reset_trike()

func _reset_trike() -> void:
	# Put the trike back at spawn (with a small Y lift)
	var t := _spawn_transform
	t.origin.y += reset_drop_height
	global_transform = t

	# Stop any motion
	velocity = Vector3.ZERO
	_speed_mps = 0.0
	_current_steer_deg = 0.0
	_target_steer_deg = 0.0

	# Clear serial freshness so Serial mode waits for new data
	_serial_has_angle = false
	_serial_angle_time_ms = -1
	_serial_axis = 0.0

	_serial_has_speed = false
	_serial_speed_time_ms = -1
	_serial_speed_mps = 0.0

	# Restore wheel visuals (steer + roll) to originals
	if _wheel_fl:
		_wheel_fl.rotation = _orig_rot_fl
	if _wheel_fr:
		_wheel_fr.rotation = _orig_rot_fr
	if _wheel_r:
		_wheel_r.rotation = _orig_rot_r

	_roll_fl_rad = 0.0
	_roll_fr_rad = 0.0
	_roll_r_rad  = 0.0

	if _wheel_fl_mesh:
		_wheel_fl_mesh.rotation = _orig_rot_fl_mesh
	if _wheel_fr_mesh:
		_wheel_fr_mesh.rotation = _orig_rot_fr_mesh
	if _wheel_r_mesh:
		_wheel_r_mesh.rotation = _orig_rot_r_mesh
