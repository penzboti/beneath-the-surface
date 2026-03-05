@tool
extends Path2D

enum PathMode { LINEAR, CIRCLE }

@export_group("Mode Control")
@export var mode: PathMode = PathMode.LINEAR:
	set(value):
		mode = value
		_update_path()

@export var lock_linear_path: bool = false

@export_group("Timing")
@export var travel_time: float = 10.0

@export_group("Circle Settings")
@export var radius: float = 100.0:
	set(value):
		radius = value
		if mode == PathMode.CIRCLE: _update_path()

@export_range(4, 64) var points_count: int = 4:
	set(value):
		points_count = value
		if mode == PathMode.CIRCLE: _update_path()

var direction: float = 1.0

func _ready():
	_update_path()

func _process(delta: float):
	if Engine.is_editor_hint(): return
	
	var follower = get_node_or_null("PathFollow2D")
	if not follower or not curve or travel_time <= 0: return

	var total_length = curve.get_baked_length()
	var speed = total_length / travel_time
	
	if mode == PathMode.CIRCLE:
		follower.loop = true
		follower.progress += speed * delta
		
		# --- CIRCLE FLIP LOGIC ---
		# In a standard circle starting at 0 degrees (right side):
		# 0.0 to 0.5 ratio is the bottom half (moving left)
		# 0.5 to 1.0 ratio is the top half (moving right)
		if follower.progress_ratio > 0.0 and follower.progress_ratio < 0.5:
			_flip_shark(true) # Facing left
		else:
			_flip_shark(false) # Facing right
			
	else:
		follower.loop = false
		follower.progress += speed * delta * direction
		
		# --- PING PONG LOGIC ---
		if direction > 0 and follower.progress_ratio >= 0.999:
			direction = -1.0
			_flip_shark(true)
		elif direction < 0 and follower.progress_ratio <= 0.001:
			direction = 1.0
			_flip_shark(false)

func _flip_shark(should_flip: bool):
	var follower = get_node_or_null("PathFollow2D")
	if follower:
		for child in follower.get_children():
			child.flip_h(should_flip)

func _update_path():
	if not curve: curve = Curve2D.new()
	
	if mode == PathMode.LINEAR:
		if not lock_linear_path:
			curve.clear_points()
			curve.add_point(Vector2.ZERO)
			curve.add_point(Vector2(300, 0))
	else:
		_generate_circle_points()
	
	var follower = get_node_or_null("PathFollow2D")
	if follower: 
		follower.progress = 0
		follower.loop = (mode == PathMode.CIRCLE)
	
	queue_redraw()

func _generate_circle_points():
	curve.clear_points()
	var control_length = radius * (4.0 / 3.0) * tan(PI / (2.0 * points_count))
	for i in range(points_count + 1):
		var angle = i * TAU / points_count
		var pos = Vector2(cos(angle), sin(angle)) * radius
		var dir = Vector2(-sin(angle), cos(angle))
		curve.add_point(pos, -dir * control_length, dir * control_length)
