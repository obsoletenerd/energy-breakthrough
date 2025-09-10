extends Node

# Serial input script that lets us take the streaming data from the real trike and use it to control the game vehicle

@export var port_name: String = "cu.usbmodem831101"  # change to your actual port
@export var baud_rate: int = 115200
@export var trike_path: NodePath
@export var max_angle_deg: float = 30.0
@export var invert_axis: bool = false
@export var debug_print: bool = true

var serial: GdSerial
var trike: TrikeController

func _ready():
	trike = get_node(trike_path)

	serial = GdSerial.new()
	serial.set_port(port_name)
	serial.set_baud_rate(baud_rate)
	serial.set_timeout(100)  # ms

	if serial.open():
		print("Serial port opened:", port_name)
	else:
		push_error("Failed to open serial port: %s" % port_name)

func _process(delta: float) -> void:
	if not serial.is_open():
		return

	while serial.bytes_available() > 0:
		var line = serial.readline().strip_edges()
		if line != "":
			_parse_line(line)

func _parse_line(line: String) -> void:
	# Expecting "ANGLE=12,SPEED=34" as per Firnsy's hardware
	if debug_print:
		print("Raw:", line)

	var angle_val: float = 0.0
	var speed_val: float = 0.0

	var parts = line.split(",")
	for part in parts:
		var kv = part.split("=")
		if kv.size() == 2:
			var key = kv[0].strip_edges().to_upper()
			var val = kv[1].strip_edges()
			match key:
				"ANGLE":
					angle_val = float(val)
				"SPEED":
					speed_val = float(val)

	# Map angle to steering axis
	var axis: float = clampf(angle_val / max_angle_deg, -1.0, 1.0)
	if invert_axis:
		axis = -axis

	# Send to the TrikeController
	trike.provider_type = TrikeController.ProviderType.EXTERNAL
	trike.set_external_axis(axis)

	# You now also have speed_val if you want to animate wheels later
