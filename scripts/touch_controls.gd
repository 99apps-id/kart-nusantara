extends CanvasLayer
class_name TouchControlsOverlay

# Automatically shown on Android / touchscreen devices; hidden on Windows/Linux desktop.

func _ready() -> void:
	layer = 5
	var show_touch: bool = OS.has_feature("android") or DisplayServer.is_touchscreen_available()
	visible = show_touch
	if not show_touch:
		return
	_build_touch_buttons()


func _build_touch_buttons() -> void:
	# Left side: Steer Left / Right
	_make_btn("  <  ", "steer_left", Vector2(24, -130), Vector2(110, 96), false)
	_make_btn("  >  ", "steer_right", Vector2(148, -130), Vector2(110, 96), false)

	# Right side: Gas, Brake, Drift, Nitro, Item
	_make_btn("GAS", "accelerate", Vector2(-130, -130), Vector2(106, 96), true)
	_make_btn("REM", "brake", Vector2(-248, -130), Vector2(102, 86), true)
	_make_btn("DRIFT", "drift", Vector2(-130, -238), Vector2(106, 76), true)
	_make_btn("NITRO", "nitro", Vector2(-248, -238), Vector2(102, 76), true)
	_make_btn("ITEM", "use_item", Vector2(-362, -130), Vector2(98, 86), true)


func _make_btn(label: String, action_name: String, offset_pos: Vector2, btn_size: Vector2, anchor_right_side: bool) -> void:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.modulate = Color(1.0, 1.0, 1.0, 0.72)
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	if anchor_right_side:
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
	btn.offset_left = offset_pos.x
	btn.offset_top = offset_pos.y
	btn.offset_right = offset_pos.x + btn_size.x
	btn.offset_bottom = offset_pos.y + btn_size.y
	btn.button_down.connect(func(): Input.action_press(action_name))
	btn.button_up.connect(func(): Input.action_release(action_name))
	add_child(btn)
