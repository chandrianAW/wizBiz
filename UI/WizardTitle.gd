extends Node2D

var is_starting = false

func _input(event):
	if is_starting:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_attack"):
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()

func _start_game():
	if is_starting:
		return
	is_starting = true
	# warning-ignore:return_value_discarded
	get_tree().change_scene("res://Levels/InsideHouse.tscn")