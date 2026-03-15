extends CharacterBody2D

# Notes:
# Remove circle.gdshader after finding proper controls, its there for making the color shape circle
# Currently player collision layer is set to 2 so both wont collide, change this later


@export var speed: float = 300.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var name_label: Label = $NameLabel
@onready var bio_light = $Bioluminescence  # whatever you named the node

var peer_id: int = 0

func on_eat_npc(npc_tier: int) -> void:
	bio_light.increase_radius(npc_tier * 15.0)

# When sizing up
func on_size_up() -> void:
	bio_light.reset_radius()
	bio_light.max_radius += 30.0  # glow grows with size
	
func setup(id: int) -> void:
	peer_id = id
	set_multiplayer_authority(id)
	sprite.animation = "orange" if id == 1 else "green"
	sprite.play()
	name_label.text = "P1" if id == 1 else "P2"
	
	var my_id = multiplayer.get_unique_id()
	if id == my_id:
		camera.enabled = true
		camera.make_current()
		camera.limit_left = -1728
		camera.limit_top = -972
		camera.limit_right = 1728
		camera.limit_bottom = 972
	else:
		camera.enabled = false

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	velocity = dir * speed
	if velocity.x < 0:
		sprite.flip_h = true 
	elif velocity.x > 0:
		sprite.flip_h =	 false
	move_and_slide()
