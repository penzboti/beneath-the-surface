extends CharacterBody2D

@export var AIR: int = 10;
@export var max_air_timer: int = 10;
@export var max_trident_timer: int = 10;
var can_trident = true

const SPEED = 10.0
const MAX_SPEED = 200.0 # sideways. double of terminal velocity
const JUMP_VELOCITY = -200.0
const GRAVITY = 300.0

var mouse_held: bool = true
var air_timer: float = 0;
var trident_timer: float = 0;
var level_time: float = 0;
var timer_label: Label
var dying: bool = false
var score_submitted: bool = false

signal lose_air(air) # amúgy ez bármilyen levegőváltozás, nem csak lose

func _ready() -> void:
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	$CanvasLayer.add_child(timer_label)
	timer_label.add_theme_font_size_override("font_size", 24)
	
	var system_font = SystemFont.new()
	system_font.font_names = ["Monospace"]
	timer_label.add_theme_font_override("font", system_font)
	
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	timer_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

func _process(delta: float) -> void:
	level_time += delta
	var minutes = int(level_time / 60)
	var seconds = int(level_time) % 60
	var msecs = int(fmod(level_time * 1000, 1000))
	timer_label.text = "Time: %02d:%02d.%03d" % [minutes, seconds, msecs]
	
	# animations
	if abs(velocity.y) < 20:
		%PlayerSprite.animation = "idle"
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		%PlayerSprite.animation = "swim"
	if Input.is_action_pressed("move_down"):
		%PlayerSprite.animation = "down"
	if velocity.y > 20:
		%PlayerSprite.animation = "down"
	if velocity.y < -20:
		%PlayerSprite.animation = "up"
	if direction > 0:
		%PlayerSprite.flip_h = true
	elif direction < 0:
		%PlayerSprite.flip_h = false
	
	# shooting trident
	if Input.is_action_just_pressed("mb1") and can_trident:
		mouse_held = true
	if Input.is_action_just_released("mb1") and can_trident:
		mouse_held = false
		shoot()
		can_trident = false
		$PlayerSprite/Trident.visible = false
		trident_timer = 0
	
	# doing timer stuff
	air_timer += delta
	if !can_trident: trident_timer += delta
	
	if position.y > 0:
		if air_timer > max_air_timer/10.0:
			AIR-=1
			air_timer = 0
			lose_air.emit(AIR)
			if AIR <= 0 and not dying:
				dying = true
				$Die.play()
				set_physics_process(false)
				visible = false
				await $Die.finished
				get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)
	else:
		AIR = 10
		lose_air.emit(AIR)
	
	if trident_timer > max_trident_timer:
		can_trident = true
		$PlayerSprite/Trident.visible = true

func _physics_process(delta: float) -> void:
	# handle gravity with low terminal velocity
	if not is_on_floor() and velocity.y < MAX_SPEED*0.5:
		velocity.y += GRAVITY * delta
		
	# handle movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction and abs(velocity.x) < MAX_SPEED:
		velocity.x += SPEED * direction
	else:
		# friction sideways
		velocity.x = move_toward(velocity.x, 0, SPEED)

	
	if Input.is_action_pressed("move_down") and velocity.y < MAX_SPEED: # increase descent speed over terminal velocity
		velocity.y += SPEED
	elif velocity.y > MAX_SPEED*0.5: # slow down descent to terminal velocity
		velocity.y = move_toward(velocity.y, MAX_SPEED*0.5, SPEED)

	# Handle jump.
	if Input.is_action_just_pressed("move_up") and position.y > 0:
		velocity.y = JUMP_VELOCITY
		# make it go faster if jumping
		if direction and abs(velocity.x) < MAX_SPEED * 3:
			velocity.x += SPEED*5 * direction
	
	# Handle dash
	if Input.is_action_just_pressed("dash") and position.y > 0:
		velocity.x = JUMP_VELOCITY*2.4 * -direction
		AIR -= 1
		lose_air.emit(AIR)
		$DashParticle.emitting = true
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var node = collision.get_collider()
		if node != null:
			if node.get_parent().has_meta("shark"):
				AIR = 0
				lose_air.emit(AIR)
				$Chomp.play()
		var normal = collision.get_normal()
		if abs(normal.x) > 0.5:
			if normal.x > 0 and Input.is_action_just_pressed("move_kick"):
				velocity.x += MAX_SPEED*2
			elif Input.is_action_just_pressed("move_kick"):
				velocity.x -= MAX_SPEED*2

	move_and_slide()
	
func add_air(air) :
	if AIR != 0:
		AIR += air
		lose_air.emit(AIR)
		$Air.play()

@export var projectile_scene: PackedScene
func shoot():
	var muzzle = global_position
	var projectile = projectile_scene.instantiate()
	
	# Calculate direction from muzzle to mouse
	var direction: Vector2 = (get_global_mouse_position() - muzzle).normalized()
	
		# Set projectile position and rotation
	projectile.global_position = muzzle
	projectile.rotation = direction.angle() + PI / 2

	projectile.direction = direction
	
	# Add to root scene so it doesn't move with the player
	get_tree().root.add_child(projectile)
	$Throw.play()

func finish_level():
	submit_score()
	# Wait briefly so the HTTP request fires before the scene unloads.
	await get_tree().create_timer(0.2).timeout

func submit_score() -> void:
	if score_submitted:
		print("Player: score already submitted, ignoring.")
		return
	score_submitted = true

	# Get level name from filename (e.g. Level1)
	var level_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	var final_time = level_time
	print("Player: trying to submit score for level: ", level_name, " time: ", final_time)

	if has_node("/root/Leaderboard"):
		print("Player: Found Leaderboard node")
		var leaderboard = get_node("/root/Leaderboard")
		if leaderboard.has_method("submit_score"):
			print("Player: Leaderboard has submit_score method, calling it.")
			leaderboard.submit_score(level_name, final_time)
		else:
			print("Player ERROR: Leaderboard missing submit_score method")
	else:
		print("Player ERROR: Could not find /root/Leaderboard node!")
