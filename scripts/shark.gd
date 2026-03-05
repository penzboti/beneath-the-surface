extends Node2D

@onready var char: Area2D = $'.'
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var timer: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("default")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.has_meta("player"):
		body.add_air(-10)
	if body.has_meta("trident"):
		self.queue_free()

func flip_h(val):
	anim.flip_h = val
