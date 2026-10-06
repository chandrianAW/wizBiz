extends Area2D

var direction = Vector2.DOWN
var knockback_vector = Vector2.DOWN
var damage = 1
var charge_ratio = 0.0
var beam_length = 32.0
var beam_width = 4.0
var beam_phase = 0.0
var lifetime = 0.2
var full_lifetime = 0.2
var hit_targets = {}

onready var collision_shape = $CollisionShape2D

func _ready():
	collision_shape.shape = collision_shape.shape.duplicate()

func configure(facing, charge):
	direction = facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	rotation = direction.angle()
	knockback_vector = direction
	charge_ratio = clamp(charge, 0.0, 1.0)
	damage = 1 + int(floor(charge_ratio * 7.0))
	var viewport_reach = max(get_viewport_rect().size.x, get_viewport_rect().size.y) * 1.5
	beam_length = viewport_reach * (1.0 + charge_ratio * 0.35)
	beam_width = 3.0 + charge_ratio * 21.0
	lifetime = 0.3 + charge_ratio * 1.2
	full_lifetime = lifetime
	var visible_width = beam_width + 4.0
	var end_cap = beam_width * 0.65
	collision_shape.shape.extents = Vector2((beam_length + end_cap) * 0.5, visible_width * 0.5)
	collision_shape.position = Vector2((beam_length + end_cap) * 0.5, 0.0)
	update()

func _process(delta):
	beam_phase += delta
	update()

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	update()
	for area in get_overlapping_areas():
		if area.get("invincible") == true:
			continue
		var target = area.get_parent()
		var target_id = target.get_instance_id()
		if not hit_targets.has(target_id) and target.has_method("_on_HurtBox_area_entered"):
			hit_targets[target_id] = true
			target.call("_on_HurtBox_area_entered", self)

func _draw():
	var flicker = 0.9 + sin(beam_phase * 24.0) * 0.1
	var color = Color(0.34, 0.9, 1.0).linear_interpolate(Color(1.0, 0.73, 0.32), charge_ratio)
	color = Color(color.r * flicker, color.g * flicker, color.b * flicker, 1.0)
	var opacity = clamp(lifetime / full_lifetime, 0.0, 1.0)
	var start = Vector2.ZERO
	var end = Vector2(beam_length, 0.0)
	draw_line(start, end, Color(color.r, color.g, color.b, 0.14 * opacity), beam_width + 4.0, true)
	draw_line(start, end, Color(color.r, color.g, color.b, 0.42 * opacity), beam_width + 1.75, true)
	draw_line(start, end, Color(color.r, color.g, color.b, opacity), beam_width, true)
	draw_line(Vector2(0.0, -1.0), Vector2(beam_length, -1.0), Color(0.92, 1.0, 0.96, 0.88 * opacity), max(1.0, beam_width * 0.2), true)
	draw_circle(end, beam_width * 0.65, Color(color.r, color.g, color.b, opacity))
	draw_circle(end, max(1.0, beam_width * 0.24), Color(1.0, 1.0, 0.94, opacity))
