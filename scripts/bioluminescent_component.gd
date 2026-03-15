extends Node2D

# ----------------------------
# ENUMS
# ----------------------------
enum Mode {
	ACTIVE,   # Always on - for visible NPCs
	PLAYER,   # Drains unless replenished - for player character
	DORMANT   # Only activates when player enters range - for hiding NPCs
}

# ----------------------------
# EXPORTS
# ----------------------------
@export var mode: Mode = Mode.ACTIVE
@export var max_radius: float = 200.0        # Max light radius in pixels
@export var glow_color: Color = Color(1.0, 0.8, 0.4, 1.0)  # Warm yellow default
@export var drain_rate: float = 20.0         # PLAYER mode: radius lost per second
@export var dormant_trigger_radius: float = 300.0  # DORMANT mode: detection range

# ----------------------------
# STATE
# ----------------------------
var current_radius: float = 0.0
var is_active: bool = false
var dormant_area: Area2D = null

# ----------------------------
# NODE REFS
# ----------------------------
var light: PointLight2D
var dormant_detector: Area2D

# ----------------------------
# SIGNALS
# ----------------------------
signal light_depleted()   # PLAYER mode: radius hit zero
signal dormant_triggered() # DORMANT mode: player entered range

# ----------------------------
# READY
# ----------------------------
func _ready() -> void:
	_setup_light()
	# REMOVED: _setup_dark_overlay()
	match mode:
		Mode.ACTIVE:
			current_radius = max_radius
			is_active = true
		Mode.PLAYER:
			current_radius = max_radius
			is_active = true
		Mode.DORMANT:
			current_radius = 0.0
			is_active = false
			_setup_dormant_detector()

# ----------------------------
# LIGHT SETUP
# ----------------------------
func _setup_light() -> void:
	light = PointLight2D.new()
	light.texture = _generate_light_texture()
	light.energy = 1.5
	light.texture_scale = _radius_to_scale(current_radius if current_radius > 0 else max_radius)
	light.color = glow_color
	light.visible = false
	light.shadow_enabled = false
	# This is critical - centers the light on the entity
	light.offset = Vector2.ZERO
	add_child(light)

func _generate_light_texture() -> ImageTexture:
	var size = 512
	var center = size / 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x - center, y - center).length()
			var normalized = dist / center  # 0.0 at center, 1.0 at edge
			var alpha: float
			if normalized >= 1.0:
				alpha = 0.0
			elif normalized < 0.3:
				alpha = 1.0
			else:
				# Smooth falloff from 0.3 to 1.0
				alpha = 1.0 - smoothstep(0.3, 1.0, normalized)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(img)

func _radius_to_scale(radius: float) -> float:
	# GradientTexture2D is 512px, scale it to match desired radius
	return radius / 256.0

# ----------------------------
# DARK OVERLAY SETUP
# ----------------------------
func _setup_dark_overlay() -> void:
	var root = get_tree().current_scene
	if not root.has_node("DarkOverlay"):
		var overlay = CanvasModulate.new()
		overlay.name = "DarkOverlay"
		overlay.color = Color(0.0, 0.02, 0.05, 1.0)
		# Must be added as a direct child of the scene root
		# and must be ABOVE the tilemap/background in the tree
		root.call_deferred("add_child", overlay)

# ----------------------------
# DORMANT DETECTOR SETUP
# ----------------------------
func _setup_dormant_detector() -> void:
	dormant_detector = Area2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = dormant_trigger_radius
	shape.shape = circle
	dormant_detector.add_child(shape)
	dormant_detector.collision_layer = 0
	dormant_detector.collision_mask = 2  # Player layer
	dormant_detector.body_entered.connect(_on_player_entered)
	dormant_detector.body_exited.connect(_on_player_exited)
	add_child(dormant_detector)

# ----------------------------
# PROCESS
# ----------------------------
func _process(delta: float) -> void:
	match mode:
		Mode.PLAYER:
			_process_player_mode(delta)
		Mode.ACTIVE:
			_process_active_mode()
		Mode.DORMANT:
			_process_dormant_mode(delta)
	_update_light()

func _process_active_mode() -> void:
	if not is_active:
		return
	current_radius = max_radius

func _process_player_mode(delta: float) -> void:
	if not is_active:
		return
	current_radius -= drain_rate * delta
	current_radius = max(current_radius, 0.0)
	if current_radius <= 0.0:
		emit_signal("light_depleted")

func _process_dormant_mode(delta: float) -> void:
	if is_active:
		# Fade in
		current_radius = move_toward(current_radius, max_radius, 150.0 * delta)
	else:
		# Fade out when player leaves
		current_radius = move_toward(current_radius, 0.0, 150.0 * delta)

# ----------------------------
# LIGHT UPDATE
# ----------------------------
func _update_light() -> void:
	if current_radius <= 1.0:
		light.visible = false
		return
	light.visible = true
	light.texture_scale = _radius_to_scale(current_radius)
	# Pulse effect for living creatures
	var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.05
	light.energy = 1.5 * pulse

# ----------------------------
# PUBLIC API
# ----------------------------

# PLAYER mode: call this when eating an NPC to restore light
func increase_radius(amount: float) -> void:
	current_radius = min(current_radius + amount, max_radius)

# PLAYER mode: call this to fully reset light (e.g. size up)
func reset_radius() -> void:
	current_radius = max_radius

# Manually activate (useful for cutscenes or special NPCs)
func activate() -> void:
	is_active = true

func deactivate() -> void:
	is_active = false

# Change color dynamically (e.g. when player eats something)
func set_glow_color(color: Color) -> void:
	glow_color = color
	light.color = color

# ----------------------------
# DORMANT CALLBACKS
# ----------------------------
func _on_player_entered(body: Node) -> void:
	if body is CharacterBody2D:
		is_active = true
		emit_signal("dormant_triggered")

func _on_player_exited(body: Node) -> void:
	if body is CharacterBody2D:
		is_active = false
