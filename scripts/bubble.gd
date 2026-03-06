
extends Area2D

@onready var player = get_tree().current_scene.get_node("Player")
@onready var particle = get_tree().current_scene.get_node("BubbleParticle")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	if body.has_meta("player"):
		body.add_air(5)
		particle.global_position = self.global_position
		particle.emitting = true
		self.queue_free()
	if body.has_meta("trident"):
		player.add_air(3)
		particle.global_position = self.global_position
		particle.emitting = true
		self.queue_free()
