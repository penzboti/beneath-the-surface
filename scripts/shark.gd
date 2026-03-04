# change this to animatedbody?

extends Node2D

@export var circle: bool = false
@export var radius: int = 100;
@export var seconds: int = 10;
@export var flip_on_half_point = true;
@onready var char: Area2D = $'.'
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var timer: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("default")
	if circle:
		char.global_position += Vector2(radius, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if flip_on_half_point:
		timer += delta
		var half = float(seconds)/2
		if timer > half:
			anim.scale.x *= -1;
			timer -= half
	if circle:
		rotation += delta*2*PI/seconds
		anim.global_rotation = 0
