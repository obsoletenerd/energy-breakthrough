# SmoothYawFollow.gd (Godot 4.4)
extends Camera3D
class_name SmoothYawFollow

@export_node_path("Node3D") var target_path: NodePath
# Seconds to reach ~63% of the way toward the target yaw. Lower = snappier.
@export_range(0.01, 1.0, 0.01) var yaw_smooth_time: float = 0.18
# If you prefer to smooth pitch/roll too, set this true.
@export var smooth_full_rotation: bool = false

var _target: Node3D
var _rel_from_target: Transform3D  # camera's initial transform in target local space
var _initialized := false

func _ready() -> void:
	if target_path.is_empty():
		push_warning("SmoothYawFollow: No target assigned.")
		return
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("SmoothYawFollow: Target not found.")
		return

	# If camera is under target, run top-level so we control global transform directly.
	if _target.is_ancestor_of(self):
		set_as_top_level(true)

	# Cache the camera's initial local transform relative to the target.
	_rel_from_target = _target.global_transform.affine_inverse() * global_transform
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized or _target == null:
		return

	# Desired pose keeps the exact same relative offset to the target.
	var desired: Transform3D = _target.global_transform * _rel_from_target

	# Always lock position exactly (no bob or lag).
	var new_pos := desired.origin

	# Smooth only yaw by default, or full rotation if requested.
	var current_basis := global_transform.basis
	var desired_basis := desired.basis

	if smooth_full_rotation:
		var alpha := 1.0 - exp(-delta / max(yaw_smooth_time, 0.0001))
		var q_cur: Quaternion = current_basis.get_rotation_quaternion()
		var q_des: Quaternion = desired_basis.get_rotation_quaternion()
		var q_new: Quaternion = q_cur.slerp(q_des, alpha)
		current_basis = Basis(q_new).orthonormalized()
	else:
		var cur_eul := current_basis.get_euler()    # default YXZ order
		var des_eul := desired_basis.get_euler()

		var alpha := 1.0 - exp(-delta / max(yaw_smooth_time, 0.0001))
		var new_y := lerp_angle(cur_eul.y, des_eul.y, alpha)

		# Build basis using desired pitch/roll but smoothed yaw.
		current_basis = Basis.from_euler(Vector3(des_eul.x, new_y, des_eul.z)).orthonormalized()

	global_transform = Transform3D(current_basis, new_pos)
