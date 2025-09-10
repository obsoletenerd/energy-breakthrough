extends Node3D
class_name TrikeController

# Assign the wheels via inspector so the script knows which is which
@export var wheel_fl_path: NodePath
@export var wheel_fr_path: NodePath
@export var wheel_r_path: NodePath

# Steering config
@export_range(1.0, 60.0, 0.1) var max_steer_deg: float = 25.0
@export_range(10.0, 540.0, 1.0) var steer_speed_deg_per_s: float = 240.0   # How fast we change angle toward target
@export_range(10.0, 540.0, 1.0) var return_speed_deg_per_s: float = 180.0  # How fast we spring back to center when no input
@export var input_deadzone: float = 0.05  # Ignore tiny noise from analog/serial
@export var invert_steer: bool = false

# Choose input (external = serial data)
enum ProviderType { KEYBOARD, AXIS_ONLY, EXTERNAL }
@export var provider_type: ProviderType = ProviderType.KEYBOARD

# External provider can be assigned at runtime by other scripts
var external_input_provider: SteeringInputProvider = null

# Runtime
var _wheel_fl: Node3D
var _wheel_fr: Node3D
var _wheel_r: Node3D
var _orig_rot_fl: Vector3
var _orig_rot_fr: Vector3
var _orig_rot_r: Vector3

var _current_steer_deg: float = 0.0  # What the wheels are currently at
var _target_steer_deg: float = 0.0   # Where input wants us to be this frame

# Input Provider interface
class SteeringInputProvider:
	# Return desired steering from -1.0 (full left) to +1.0 (full right)
	func get_steer_axis() -> float:
		return 0.0

# Keyboard provider: left/right keys map to -1/ +1
class KeyboardInputProvider:
	extends SteeringInputProvider
	func get_steer_axis() -> float:
		var left := Input.get_action_strength("steer_left")
		var right := Input.get_action_strength("steer_right")
		return clamp(right - left, -1.0, 1.0)

# Joystick/Gamepad provider: Bind a controller axis to "steer_axis" in input settings
class AxisInputProvider:
	extends SteeringInputProvider
	func get_steer_axis() -> float:
		# Uses action strength which works for analog axes if mapped
		var axis := Input.get_action_strength("steer_axis")
		# If your axis mapping only goes 0..1, remap to -1..1 by subtracting a paired negative action
		return clamp(axis, -1.0, 1.0)

# External provider stub (e.g., serial/ESP32 or USB wheel)
# Assign to `external_input_provider` and set provider_type = EXTERNAL
# Then call `set_external_axis(value)` from elsewhere.
class ExternalInputProvider:
	extends SteeringInputProvider
	var _axis: float = 0.0
	func set_axis(value: float) -> void:
		_axis = clamp(value, -1.0, 1.0)
	func get_steer_axis() -> float:
		return _axis

var _provider: SteeringInputProvider

func _ready() -> void:
	_wheel_fl = _require_node(wheel_fl_path, "Wheel-FL")
	_wheel_fr = _require_node(wheel_fr_path, "Wheel-FR")
	_wheel_r  = _optional_node(wheel_r_path)

	_orig_rot_fl = _wheel_fl.rotation
	_orig_rot_fr = _wheel_fr.rotation
	if _wheel_r:
		_orig_rot_r = _wheel_r.rotation

	_select_provider()

func _select_provider() -> void:
	match provider_type:
		ProviderType.KEYBOARD:
			_provider = KeyboardInputProvider.new()
		ProviderType.AXIS_ONLY:
			_provider = AxisInputProvider.new()
		ProviderType.EXTERNAL:
			if external_input_provider == null:
				external_input_provider = ExternalInputProvider.new()
			_provider = external_input_provider

func _physics_process(delta: float) -> void:
	# 1) Read raw axis and deadzone it
	var axis := _provider.get_steer_axis()
	if absf(axis) < input_deadzone:
		axis = 0.0
	# Invert steering if selected via Inspector panel
	if invert_steer:
		axis = -axis

	# 2) Compute the target angle from axis
	_target_steer_deg = axis * max_steer_deg

	# 3) Move current angle toward target (different speed if axis is zero)
	var speed := return_speed_deg_per_s if axis == 0.0 else steer_speed_deg_per_s
	_current_steer_deg = _move_toward_angle(_current_steer_deg, _target_steer_deg, speed * delta)

	# 4) Apply to front wheels (rotate around local Y)
	_apply_steer_to_wheel(_wheel_fl, _orig_rot_fl, _current_steer_deg)
	_apply_steer_to_wheel(_wheel_fr, _orig_rot_fr, _current_steer_deg)

# Set external axis from other scripts (e.g., serial parser)
func set_external_axis(value: float) -> void:
	if provider_type == ProviderType.EXTERNAL and external_input_provider != null:
		if external_input_provider is ExternalInputProvider:
			(external_input_provider as ExternalInputProvider).set_axis(value)

# Helper functions
func _apply_steer_to_wheel(wheel: Node3D, original_rot: Vector3, steer_deg: float) -> void:
	# Preserve original X/Z rotations; add yaw around Y
	var rot := original_rot
	rot.y = original_rot.y + deg_to_rad(steer_deg)
	wheel.rotation = rot

func _move_toward_angle(from_deg: float, to_deg: float, step_deg: float) -> float:
	if from_deg == to_deg:
		return from_deg
	var sign := 1.0 if to_deg > from_deg else -1.0
	var next := from_deg + sign * step_deg
	# Clamp crossing
	if (sign > 0.0 and next > to_deg) or (sign < 0.0 and next < to_deg):
		return to_deg
	return next

func _require_node(path: NodePath, label: String) -> Node3D:
	if path.is_empty():
		push_error("%s path not assigned on TrikeController" % label)
		return Node3D.new()
	var n := get_node_or_null(path)
	if n == null:
		push_error("Could not find %s at %s" % [label, str(path)])
		return Node3D.new()
	return n as Node3D

func _optional_node(path: NodePath) -> Node3D:
	if path.is_empty():
		return null
	return get_node_or_null(path) as Node3D
