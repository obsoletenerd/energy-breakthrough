extends Node

@export var port_name: String = "/dev/cu.usbmodemXXXX"  # set full path if MacOS
@export var baud_rate: int = 115200
@export var trike_path: NodePath
@export var debug_print: bool = true
@export var invert_axis: bool = false  # if your hardware angle sign is flipped

var serial: GdSerial
var trike: TrikeController

func _ready() -> void:
	trike = get_node(trike_path)

	serial = GdSerial.new()
	serial.set_port(port_name)
	serial.set_baud_rate(baud_rate)
	serial.set_timeout(100)

	if serial.open():
		print("[Serial] OPEN: ", port_name)
	else:
		push_error("[Serial] Failed to open: %s" % port_name)

func _process(delta: float) -> void:
	if not serial.is_open(): return
	while serial.bytes_available() > 0:
		var line: String = serial.readline().strip_edges()
		if line != "": _parse_line(line)

func _parse_line(line: String) -> void:
	# Expecting: "ANGLE=12,SPEED=34" (fields may be missing)
	if debug_print:
		print("[Serial] ", line)

	var has_angle := false
	var has_speed := false
	var angle_deg := 0.0
	var speed_raw := 0.0

	for part in line.split(","):
		var kv := part.split("=")
		if kv.size() == 2:
			var k := (kv[0] as String).strip_edges().to_upper()
			var v := (kv[1] as String).strip_edges()
			match k:
				"ANGLE":
					angle_deg = float(v)
					if invert_axis: angle_deg = -angle_deg
					has_angle = true
				"SPEED":
					speed_raw = float(v)
					has_speed = true

	# Push whatever we have
	trike.update_serial(has_angle, angle_deg, has_speed, speed_raw)
