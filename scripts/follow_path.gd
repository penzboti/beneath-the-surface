extends PathFollow2D

#@onready var seconds = $Shark.seconds;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# create_tween().tween_property(self, "progress_ratio", 1, seconds)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#self.progress_ratio += delta/seconds
	pass
