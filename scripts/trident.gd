extends Node2D

var direction: Vector2
@export var speed: int = 100
@export var invincibility_timer: float = 0.1 # rather than an invincibility timer, mask out the player as a collision object
@export var vanish_timer: float = 9.99
@export var trident_air_add: int = 3

var timer: float = 0

@onready var char: CharacterBody2D = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CollisionShape2D.disabled = true
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	timer += delta
	#if timer > invincibility_timer: $CharacterBody2D/CollisionShape2D.disabled = false
	if timer > vanish_timer: self.queue_free()
	
	char.velocity = direction.normalized() * speed
	char.move_and_slide()

func _physics_process(_delta: float) -> void:
	for i in char.get_slide_collision_count():
		var collision = char.get_slide_collision(i)
		if collision.get_collider().get_parent().has_meta("shark"):
			collision.get_collider().get_parent().queue_free()
		if collision.get_collider() is TileMapLayer:
			self.queue_free()
