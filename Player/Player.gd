extends KinematicBody2D

onready var animationPlayer      = $AnimationPlayer
onready var animationTree        = $AnimationTree
onready var swordHitbox          = $HitBoxPivot/SwordHitBox
onready var animationState       = animationTree.get("parameters/playback")
onready var hurtbox              = $HurtBox
onready var blinkAnimationPlayer = $BlinkAnimationPlayer

const MagicBeam = preload("res://Player/MagicBeam.tscn")
const MAX_CHARGE_TIME = 2.5
const MAGIC_BASE_MANA_COST = 5.0
const MAGIC_CHARGE_MANA_COST = 25.0
const MANA_REGEN_PER_SECOND = 4.0

onready var Player               = preload("res://Player/Wizard.png")
onready var Ledi                 = preload("res://Player/Ledi.png")
onready var Lyu                  = preload("res://Player/Lyu.png")
onready var Legan                = preload("res://Player/Legan.png")
onready var Effect               = preload("res://Effects/EnemyDeathEffect.tscn")

var ACCELERATION                 = 500
var MAX_SPEED                    = 80
var FRICTION                     = 500
var ROLL_SPEED                   = 120

var velocity                     = Vector2.ZERO
var roll_vector                  = Vector2.DOWN
var beam_direction               = Vector2.DOWN
var can_move                     = true 
var can_attack                   = true 
var is_charging_magic            = false
var magic_charge_time            = 0.0
var mana_regen_timer             = 0.0

var state                        = MOVE
enum { MOVE, ROLL, ATTACK, TRANSITION,}

signal update_mana

################################################################
func _ready():

	swordHitbox.knockback_vector = roll_vector
	animationTree.active         = true
	transformation()
	if Global.player == "Player":
		animationTree.active = false
		animationPlayer.play("IdleDown")
	randomize()
#______________________________________ Connecting Signals ___
# warning-ignore:return_value_discarded
	Global.connect("no_health", self, "dying_state")
# warning-ignore:return_value_discarded
	self.connect("update_mana", Global, "_on_update_status")

################################################# State Machine ###
func _process(delta):

	if can_move == true:
		match state:
			MOVE:
					   move_state(delta)
			ROLL:
					   roll_state()
			ATTACK:
					   attack_state()
			TRANSITION:
					   transition_state()
	_update_magic_charge(delta)
	_regenerate_mana(delta)
	_invisible()

###################################################### Movement ###
func move_state(delta):

	var input_vector = Vector2.ZERO
	input_vector.x   = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y   = Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	input_vector     = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		var facing_vector = input_vector
		if Global.player == "Player":
			beam_direction = input_vector
			facing_vector = Vector2(sign(input_vector.x), 0) if abs(input_vector.x) > abs(input_vector.y) else Vector2(0, sign(input_vector.y))
		roll_vector  = facing_vector
		swordHitbox.knockback_vector = facing_vector
		if Global.player == "Player":
			_play_wizard_animation("Run")
		else:
			animationTree.set("parameters/Idle/blend_position",         input_vector)
			animationTree.set("parameters/Run/blend_position",          input_vector)
			animationTree.set("parameters/Roll/blend_position",         input_vector)
			animationTree.set("parameters/PlayerAttack/blend_position", input_vector)
			animationTree.set("parameters/LediAttack/blend_position",   input_vector)
			animationTree.set("parameters/LeganAttack/blend_position",  input_vector)
			animationTree.set("parameters/LyuAttack/blend_position",    input_vector)
			animationState.travel("Run")
		velocity     = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)

	else:
		if Global.player == "Player":
			_play_wizard_animation("Idle")
		else:
			animationState.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move()

	if can_attack == true:
		if Input.is_action_just_pressed("ui_roll"):
			state = ROLL
		if Global.player != "Player" and Input.is_action_just_pressed("ui_attack"):
			state = ATTACK
			_power()

func move():
	velocity = move_and_slide(velocity)

func _input(event):
	if Global.player != "Player" or not can_move:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var facing = Vector2.ZERO
	if event.is_action_pressed("ui_up"):
		facing = Vector2.UP
	elif event.is_action_pressed("ui_down"):
		facing = Vector2.DOWN
	elif event.is_action_pressed("ui_left"):
		facing = Vector2.LEFT
	elif event.is_action_pressed("ui_right"):
		facing = Vector2.RIGHT
	if facing != Vector2.ZERO:
		roll_vector = facing
		beam_direction = facing
		swordHitbox.knockback_vector = facing
		_play_wizard_animation("Run")

func _direction_suffix(facing):
	if abs(facing.x) > abs(facing.y):
		return "Right" if facing.x > 0 else "Left"
	return "Down" if facing.y > 0 else "Up"

func _play_wizard_animation(animation_prefix):
	var animation_name = animation_prefix + _direction_suffix(roll_vector)
	if animationPlayer.current_animation != animation_name:
		animationPlayer.play(animation_name)

func _update_magic_charge(delta):
	if Global.player != "Player" or not can_move or not can_attack:
		_cancel_magic_charge()
		return

	if Input.is_action_pressed("ui_attack"):
		is_charging_magic = true
		magic_charge_time = min(magic_charge_time + delta, MAX_CHARGE_TIME)
		update()
	elif is_charging_magic:
		_fire_magic_beam()

func _fire_magic_beam():
	var charge_ratio = clamp(magic_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	if Global.mana < MAGIC_BASE_MANA_COST:
		_cancel_magic_charge()
		return
	var affordable_charge = clamp((Global.mana - MAGIC_BASE_MANA_COST) / MAGIC_CHARGE_MANA_COST, 0.0, 1.0)
	charge_ratio = min(charge_ratio, affordable_charge)
	var mana_cost = MAGIC_BASE_MANA_COST + MAGIC_CHARGE_MANA_COST * charge_ratio
	Global.mana = max(0.0, Global.mana - mana_cost)
	emit_signal("update_mana")
	var beam = MagicBeam.instance()
	add_child(beam)
	beam.position = beam_direction * 8.0
	beam.configure(beam_direction, charge_ratio)
	is_charging_magic = false
	magic_charge_time = 0.0
	update()

func _regenerate_mana(delta):
	if Global.mana >= Global.MAX_MANA:
		mana_regen_timer = 0.0
		return
	mana_regen_timer += delta
	if mana_regen_timer < 0.25:
		return
	var elapsed = mana_regen_timer
	mana_regen_timer = 0.0
	var previous_mana = Global.mana
	Global.mana = min(Global.MAX_MANA, Global.mana + MANA_REGEN_PER_SECOND * elapsed)
	if Global.mana != previous_mana:
		emit_signal("update_mana")

func _cancel_magic_charge():
	is_charging_magic = false
	magic_charge_time = 0.0
	update()

func _draw():
	if not is_charging_magic:
		return
	var charge_ratio = clamp(magic_charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	var center = Vector2(0, -49)
	var color = Color(0.36, 0.92, 1.0).linear_interpolate(Color(1.0, 0.82, 0.4), charge_ratio)
	draw_circle(center, 4.0 + charge_ratio * 4.0, Color(color.r, color.g, color.b, 0.2))
	draw_arc(center, 8.0, -PI / 2.0, -PI / 2.0 + PI * 2.0 * charge_ratio, 32, color, 2.0, true)
	draw_circle(center, 2.0 + charge_ratio * 2.0, Color(0.9, 1.0, 1.0))

################################################# Roll & Attack ###
func roll_state():
	velocity = roll_vector * ROLL_SPEED
	if Global.player == "Player":
		_play_wizard_animation("Roll")
	else:
		animationState.travel("Roll")
	move()

func roll_animation_finished():
	velocity = velocity * 0.8
	state = MOVE

func attack_state():
	velocity = Vector2.ZERO
	animationState.travel(Global.player + "Attack")

func attack_animation_finished():
	state = MOVE

############################################### Transformations ###
func transformation():

	if Global.player == "Player":
		$Sprite.texture    = Player
		swordHitbox.damage = 1

	if Global.player == "Legan":
		$Sprite.texture    = Legan
		swordHitbox.damage = 2

	if Global.player == "Ledi":
		$Sprite.texture    = Ledi
		swordHitbox.damage = 4

	if Global.player == "Lyu":
		$Sprite.texture    = Lyu
		swordHitbox.damage = 6

func smoke_effect():
	$Smoke.play()
	$Smoke.frame = 0

############################# Walk by itself when change Levels ###
func transition():
	$Transition.start()
	roll_vector = Global.direction
	state = TRANSITION

func transition_state():
	velocity = Global.direction * MAX_SPEED
	animationTree.set("parameters/Run/blend_position",           Global.direction)
	animationTree.set("parameters/PlayerAttack/blend_position",  Global.direction)
	animationTree.set("parameters/Roll/blend_position",          Global.direction)
	animationTree.set("parameters/LediAttack/blend_position",    Global.direction)
	animationTree.set("parameters/LeganAttack/blend_position",   Global.direction)
	animationTree.set("parameters/LyuAttack/blend_position",     Global.direction)
	animationState.travel("Run")
	move()

func _on_Transition_timeout():
	animationTree.set("parameters/Idle/blend_position",          Global.direction)
	animationState.travel("Idle")
	state = MOVE

###################################################### Crafting ###
func cut_left():
	can_move = false
	animationState.travel("Idle")
	$AnimationPlayer.play("CutLeft")
	yield($AnimationPlayer,"animation_finished")
	animationState.travel("Idle")
	state = MOVE
	can_move = true

func cut_right():
	can_move = false
	animationState.travel("Idle")
	$AnimationPlayer.play("CutRight")
	yield($AnimationPlayer,"animation_finished")
	animationState.travel("Idle")
	state    = MOVE
	can_move = true

func break_left():
	can_move = false
	animationState.travel("Idle")
	$AnimationPlayer.play("BreakLeft")
	yield($AnimationPlayer,"animation_finished")
	animationState.travel("Idle")
	state    = MOVE
	can_move = true

func break_right():
	can_move = false
	animationState.travel("Idle")
	$AnimationPlayer.play("BreakRight")
	yield($AnimationPlayer,"animation_finished")
	animationState.travel("Idle")
	state    = MOVE
	can_move = true

######################################################## Damage ###
func _on_HurtBox_area_entered(area):
	$Hurt.play()
	Global.health -= area.damage
	hurtbox.start_invincibility(0.5)
	hurtbox.create_hit_effect()

func dying_state():
	#$HurtBox.set_deferred("monitoring", false)
	$HurtBox.queue_free()
	animationTree.active = false
	can_move = false
	animationPlayer.play("Dying")
	Global.stop_music()
	Global.death_play()
	yield($AnimationPlayer, "animation_finished")
	Global.health = Global.max_health
# warning-ignore:return_value_discarded
	Global.from = null
	Global.direction = Vector2.ZERO
	yield(get_tree().create_timer(2),"timeout")
	get_tree().change_scene("res://Levels/InsideHouse.tscn")
	Global.play_music()

func _on_HurtBox_invincibility_started():
	blinkAnimationPlayer.play("Start")

func _on_HurtBox_invincibility_ended():
	blinkAnimationPlayer.play("Stop")

################################################# Spending Mana ###
func _power():
	if Global.player == "Lyu":
		emit_signal("update_mana")
		if Global.mana > 0:
			Global.mana -= 10
			emit_signal("update_mana")
		else:
			Global.player = "Player"
			transformation()
			smoke_effect()

############################################### Using Repellent ###
func _invisible():
	if Global.repellent == true:
		self.modulate = Color(1,1,1,0.3)
	else:
		self.modulate = Color(1,1,1,1)
