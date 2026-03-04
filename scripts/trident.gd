extends Node2D

var direction: Vector2
@export var speed: int = 100
@export var vanish_timer: float = 9.99
@export var trident_air_add: int = 3

var timer: float = 0

@onready var char: CharacterBody2D = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# remove unnecessary tridents
	timer += delta
	if timer > vanish_timer: self.queue_free()
	
func _physics_process(_delta: float) -> void:
	# move
	char.velocity = direction.normalized() * speed*5
	char.move_and_slide()
	
	# check for wall collisions
	# any other collision is handled elsewhere
	for i in char.get_slide_collision_count():
		var collision = char.get_slide_collision(i)
		if collision.get_collider() is TileMapLayer:
			self.queue_free()
