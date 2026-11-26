extends Node3D

const KART_PATH := "res://assets/models/bajaj_kart.glb"
const WORLD_BUILDER_SCRIPT := preload("res://scripts/world_props.gd")

var turntable: Node3D
var preview_kart: Node3D
var preview_steer_pivot: Node3D
var preview_steer_base_rot: Vector3 = Vector3.ZERO
var preview_grip_l: Node3D
var preview_grip_r: Node3D
var preview_arm_l: Node3D
var preview_arm_r: Node3D
var preview_knuckle_fl: Node3D
var preview_knuckle_fr: Node3D
var demo_time: float = 0.0

var lbl_preset: Label
var lbl_color: Label
var lbl_spoiler: Label
var lbl_wheel: Label
var lbl_engine: Label
var lbl_nitro: Label
var bar_speed: ProgressBar
var bar_handling: ProgressBar
var bar_nitro: ProgressBar
var bar_mass: ProgressBar
var name_input: LineEdit
var intro_player: AudioStreamPlayer
var intro_triggered: bool = false


func _ready() -> void:
	var wb: ChaosWorldBuilder = WORLD_BUILDER_SCRIPT.new()
	add_child(wb)
	wb.setup_tropical_lighting(self)

	# Play arcade Nusantara intro fanfare on game launch (with Web click-unlock fallback)
	intro_player = AudioStreamPlayer.new()
	intro_player.name = "IntroAudio"
	intro_player.stream = ComedySfx.get_stream("intro_fanfare")
	intro_player.volume_db = -5.0
	add_child(intro_player)
	intro_player.play()
	intro_triggered = not OS.has_feature("web")

	# Full Jakarta street asphalt ground beneath garage props (eliminates empty horizon void)
	var street_ground := MeshInstance3D.new()
	var street_plane := PlaneMesh.new()
	street_plane.size = Vector2(64.0, 64.0)
	street_ground.mesh = street_plane
	street_ground.position = Vector3(0.0, -0.34, -8.0)
	street_ground.material_override = wb.make_pbr_mat(
		ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_A),
		ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_N),
		Vector3(14.0, 14.0, 1.0), 0.88, Color(0.56, 0.58, 0.64),
		ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_R)
	)
	add_child(street_ground)

	# Garage turntable floor + spotlight
	var floor_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.2; cyl.bottom_radius = 4.6; cyl.height = 0.35
	floor_mesh.mesh = cyl
	floor_mesh.position = Vector3(0.0, -0.18, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.26, 0.28, 0.32)
	fmat.metallic = 0.08; fmat.roughness = 0.82
	floor_mesh.material_override = fmat
	add_child(floor_mesh)

	# Warm workshop golden-hour overhead light so the hero kart stands out brightly
	var shop_light := OmniLight3D.new()
	shop_light.position = Vector3(2.2, 3.8, 2.6)
	shop_light.light_color = Color(1.0, 0.90, 0.76)
	shop_light.light_energy = 1.45
	shop_light.omni_range = 14.0
	add_child(shop_light)

	# Indonesian backdrop props in Garage!
	wb.spawn_static_model(self, ChaosWorldBuilder.P_INDOMARET, Vector3(-8.5, 0.0, -9.5), 25.0)
	wb.spawn_static_model(self, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(6.5, 0.0, -8.5), -25.0)
	wb.spawn_static_model(self, ChaosWorldBuilder.P_GAPURA, Vector3(0.0, 0.0, -13.0), 0.0)

	turntable = Node3D.new()
	add_child(turntable)

	var cam := Camera3D.new()
	cam.fov = 52.0
	cam.position = Vector3(2.8, 2.1, 4.9)
	cam.look_at_from_position(cam.position, Vector3(-0.7, 0.75, 0.0), Vector3.UP)
	cam.current = true
	add_child(cam)

	_rebuild_preview_kart()
	_build_garage_ui()
	_refresh_ui()


func _rebuild_preview_kart() -> void:
	if preview_kart != null:
		preview_kart.queue_free()
	var ks := load(KART_PATH) as PackedScene
	preview_kart = ks.instantiate()
	ChaosWorldBuilder.apply_realistic_glass(preview_kart)
	turntable.add_child(preview_kart)

	var cfg := GameConfig.get_player_kart_config()
	var wing := preview_kart.find_child("Spoiler_Wing", true, false) as Node3D
	var basket := preview_kart.find_child("Spoiler_Basket", true, false) as Node3D
	if wing: wing.visible = (int(cfg["spoiler_idx"]) == 1)
	if basket: basket.visible = (int(cfg["spoiler_idx"]) == 2)

	var wscale: float = float(cfg["wheel_scale"])
	for wn in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var w := preview_kart.find_child(wn, true, false) as Node3D
		if w:
			w.scale = Vector3(wscale, wscale, wscale)

	# Recolor Mat_Body
	var body_col: Color = cfg["body_color"]
	var stack: Array = [preview_kart]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var m: Material = mi.mesh.surface_get_material(s)
					if m == null:
						m = mi.get_active_material(s)
					if m != null and m.resource_name.begins_with("Mat_Body"):
						var dup := m.duplicate() as StandardMaterial3D
						if dup:
							dup.resource_name = m.resource_name
							dup.albedo_color = body_col
							mi.set_surface_override_material(s, dup)
		for ch in n.get_children():
			stack.append(ch)

	# Bind steering wheel, arms, and front wheels for live steering animation demo in Garage!
	preview_steer_pivot = preview_kart.find_child("SteeringPivot", true, false) as Node3D
	if preview_steer_pivot:
		preview_steer_base_rot = preview_steer_pivot.rotation
	preview_grip_l = preview_kart.find_child("Grip_L", true, false) as Node3D
	preview_grip_r = preview_kart.find_child("Grip_R", true, false) as Node3D
	preview_arm_l = preview_kart.find_child("DriverArm_L", true, false) as Node3D
	preview_arm_r = preview_kart.find_child("DriverArm_R", true, false) as Node3D
	preview_knuckle_fl = preview_kart.find_child("Wheel_FL", true, false) as Node3D
	preview_knuckle_fr = preview_kart.find_child("Wheel_FR", true, false) as Node3D


func _process(delta: float) -> void:
	demo_time += delta
	turntable.rotate_y(delta * 0.42)
	# Live steering & hands & front-wheels animation demo in Garage!
	var s_wave := sin(demo_time * 1.8)
	if preview_steer_pivot:
		preview_steer_pivot.rotation = preview_steer_base_rot
		preview_steer_pivot.rotate_object_local(Vector3.UP, s_wave * 0.95)
	if preview_arm_l and preview_grip_l:
		preview_arm_l.look_at(preview_grip_l.global_position, Vector3.UP)
	if preview_arm_r and preview_grip_r:
		preview_arm_r.look_at(preview_grip_r.global_position, Vector3.UP)
	if preview_knuckle_fl:
		preview_knuckle_fl.rotation.y = s_wave * 0.52
	if preview_knuckle_fr:
		preview_knuckle_fr.rotation.y = s_wave * 0.52


func _build_garage_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(430, 670)
	cl.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "KART NUSANTARA"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1.0, 0.82, 0.14)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "CHAOS RACING - GARAGE & MODIFIKASI"
	sub.add_theme_font_size_override("font_size", 15)
	vbox.add_child(sub)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Nama Pemain:"
	name_lbl.custom_minimum_size = Vector2(115, 0)
	name_row.add_child(name_lbl)
	name_input = LineEdit.new()
	name_input.name = "PlayerNameInput"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.max_length = 20
	name_input.placeholder_text = "Ketik nama pembalap..."
	name_input.text = GameConfig.get_clean_player_name()
	name_input.text_changed.connect(func(txt: String): GameConfig.set_player_name(txt))
	name_row.add_child(name_input)

	vbox.add_child(HSeparator.new())

	lbl_preset = _add_cycler(vbox, "Model Gokart", func(d):
		GameConfig.selected_preset_idx = posmod(GameConfig.selected_preset_idx + d, GameConfig.KART_PRESETS.size())
		_rebuild_preview_kart(); _refresh_ui()
	)
	lbl_color = _add_cycler(vbox, "Warna Bodi", func(d):
		GameConfig.selected_color_idx = posmod(GameConfig.selected_color_idx + d, GameConfig.BODY_COLORS.size())
		_rebuild_preview_kart(); _refresh_ui()
	)
	lbl_spoiler = _add_cycler(vbox, "Spoiler / Rak", func(d):
		GameConfig.selected_spoiler_idx = posmod(GameConfig.selected_spoiler_idx + d, GameConfig.SPOILER_STYLES.size())
		_rebuild_preview_kart(); _refresh_ui()
	)
	lbl_wheel = _add_cycler(vbox, "Velg & Ban", func(d):
		GameConfig.selected_wheel_idx = posmod(GameConfig.selected_wheel_idx + d, GameConfig.WHEEL_STYLES.size())
		_rebuild_preview_kart(); _refresh_ui()
	)
	lbl_engine = _add_cycler(vbox, "Upgrade Mesin", func(d):
		GameConfig.engine_level = clamp(GameConfig.engine_level + d, 0, 2)
		_refresh_ui()
	)
	lbl_nitro = _add_cycler(vbox, "Upgrade Nitro", func(d):
		GameConfig.nitro_level = clamp(GameConfig.nitro_level + d, 0, 2)
		_refresh_ui()
	)

	vbox.add_child(HSeparator.new())
	bar_speed = _add_stat_bar(vbox, "Kecepatan")
	bar_handling = _add_stat_bar(vbox, "Handling & Drift")
	bar_nitro = _add_stat_bar(vbox, "Energi Nitro")
	bar_mass = _add_stat_bar(vbox, "Kekuatan Tabrak")

	vbox.add_child(HSeparator.new())

	var btn_race := Button.new()
	btn_race.text = "MULAI CHAOS RACING (8 GOKART)"
	btn_race.custom_minimum_size = Vector2(0, 48)
	btn_race.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/race_track.tscn"))
	vbox.add_child(btn_race)

	var btn_battle := Button.new()
	btn_battle.text = "MULAI BATTLE ARENA (8 GOKART)"
	btn_battle.custom_minimum_size = Vector2(0, 44)
	btn_battle.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle_arena.tscn"))
	vbox.add_child(btn_battle)


func _add_cycler(parent: Control, title_text: String, cb: Callable) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var t := Label.new(); t.text = title_text; t.custom_minimum_size = Vector2(130, 0); row.add_child(t)
	var b_prev := Button.new(); b_prev.text = " < "; b_prev.pressed.connect(func(): cb.call(-1)); row.add_child(b_prev)
	var val := Label.new(); val.size_flags_horizontal = Control.SIZE_EXPAND_FILL; val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(val)
	var b_next := Button.new(); b_next.text = " > "; b_next.pressed.connect(func(): cb.call(1)); row.add_child(b_next)
	return val


func _add_stat_bar(parent: Control, label_text: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new(); l.text = label_text; l.custom_minimum_size = Vector2(140, 0); row.add_child(l)
	var pb := ProgressBar.new(); pb.max_value = 100; pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pb.custom_minimum_size = Vector2(0, 18); row.add_child(pb)
	return pb


func _refresh_ui() -> void:
	var cfg := GameConfig.get_player_kart_config()
	lbl_preset.text = str(GameConfig.KART_PRESETS[GameConfig.selected_preset_idx]["name"])
	lbl_color.text = str(GameConfig.BODY_COLORS[GameConfig.selected_color_idx]["name"])
	lbl_spoiler.text = str(GameConfig.SPOILER_STYLES[GameConfig.selected_spoiler_idx])
	lbl_wheel.text = str(GameConfig.WHEEL_STYLES[GameConfig.selected_wheel_idx])
	lbl_engine.text = "Level %d / 3" % (GameConfig.engine_level + 1)
	lbl_nitro.text = "Level %d / 3" % (GameConfig.nitro_level + 1)

	bar_speed.value = clamp((float(cfg["max_speed"]) - 24.0) / 14.0 * 100.0, 20.0, 100.0)
	bar_handling.value = clamp((float(cfg["handling"]) - 1.8) / 2.0 * 100.0, 20.0, 100.0)
	bar_nitro.value = clamp((float(cfg["nitro_power"]) - 10.0) / 10.0 * 100.0, 20.0, 100.0)
	bar_mass.value = clamp(float(cfg["mass"]) / 1.7 * 100.0, 20.0, 100.0)


func _input(event: InputEvent) -> void:
	# Web browsers block audio until the first user click/key; replay intro fanfare on first interaction
	if not intro_triggered and (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		if event.is_pressed():
			intro_triggered = true
			if is_instance_valid(intro_player):
				intro_player.play()
