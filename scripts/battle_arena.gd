extends Node3D

const KART_SCRIPT := preload("res://scripts/kart_controller.gd")
const WORLD_BUILDER_SCRIPT := preload("res://scripts/world_props.gd")
const REPLAY_SCRIPT := preload("res://scripts/replay_system.gd")

const ITEM_NAMES := {
	"": "KOSONG",
	"banana": "KULIT PISANG",
	"rocket": "ROKET KARTUN",
	"water_bomb": "BOM AIR",
	"oil": "GENANGAN OLI",
	"shield": "PERISAI"
}

var world_builder: ChaosWorldBuilder
var replay_sys: ReplaySystem
var replay_cam: Camera3D
var karts: Array = []
var player_kart: KartController
var match_ended: bool = false

var hud_hp_bar: ProgressBar
var hud_alive_label: Label
var hud_ko_label: Label
var hud_item_label: Label
var hud_nitro_bar: ProgressBar
var hud_banner: Label
var replay_panel: PanelContainer


func _ready() -> void:
	world_builder = WORLD_BUILDER_SCRIPT.new()
	add_child(world_builder)
	world_builder.setup_tropical_lighting(self)

	_build_arena()
	_spawn_8_combat_karts()

	replay_cam = Camera3D.new()
	replay_cam.fov = 62.0
	replay_cam.position = Vector3(24.0, 12.0, 24.0)
	add_child(replay_cam)

	replay_sys = REPLAY_SCRIPT.new()
	add_child(replay_sys)
	replay_sys.setup(karts, replay_cam, [
		Vector3(24.0, 10.0, 24.0),
		Vector3(-24.0, 10.0, -24.0),
		Vector3(0.0, 16.0, 28.0)
	])

	_build_hud()
	add_child(TouchControlsOverlay.new())


func _build_arena() -> void:
	var mat_floor := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_N), Vector3(0.0625, 0.0625, 0.0625), 0.96, Color(0.74, 0.77, 0.84), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_R), 2.1)
	var mat_rim := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_N), Vector3(0.12, 0.12, 0.12), 0.96, Color(0.82, 0.84, 0.88), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_R), 2.0)

	# 76m x 76m Nusantara Market Square Battle Arena
	world_builder.add_ground_slab(self, Vector3(0.0, -0.5, 0.0), Vector3(84.0, 1.0, 84.0), mat_floor)
	# Arena boundary walls
	world_builder.add_ground_slab(self, Vector3(0.0, 1.8, -38.0), Vector3(78.0, 3.6, 2.0), mat_rim)
	world_builder.add_ground_slab(self, Vector3(0.0, 1.8, 38.0), Vector3(78.0, 3.6, 2.0), mat_rim)
	world_builder.add_ground_slab(self, Vector3(-38.0, 1.8, 0.0), Vector3(2.0, 3.6, 78.0), mat_rim)
	world_builder.add_ground_slab(self, Vector3(38.0, 1.8, 0.0), Vector3(2.0, 3.6, 78.0), mat_rim)

	# Iconic Indonesian facades outside arena rim
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_INDOMARET, Vector3(-16.0, 0.0, -42.5), 180.0)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_ALFAMART, Vector3(16.0, 0.0, -42.5), 180.0)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(-42.0, 0.0, 0.0), -90.0)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(42.0, 0.0, 0.0), 90.0)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAPURA, Vector3(0.0, 0.0, -37.0), 0.0)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAPURA, Vector3(0.0, 0.0, 37.0), 0.0)

	# Central Jump Ramp + Destructible Chaos Cover
	world_builder.add_ground_slab(self, Vector3(0.0, 0.45, 0.0), Vector3(7.0, 0.3, 9.0), mat_rim, 0.0, deg_to_rad(11.0))

	for i in range(8):
		var ang := float(i) * TAU / 8.0
		var r := 16.0
		var p := Vector3(cos(ang) * r, 0.1, sin(ang) * r)
		world_builder.spawn_item_box(self, p)
		world_builder.spawn_destructible(self, "barrel", p + Vector3(2.5, 0.0, 0.0))
		world_builder.spawn_destructible(self, "cardboard", p + Vector3(-2.5, 0.0, 1.5))
		if i % 2 == 0:
			world_builder.spawn_destructible(self, "gerobak", Vector3(cos(ang) * 26.0, 0.1, sin(ang) * 26.0), rad_to_deg(ang))
		else:
			world_builder.spawn_destructible(self, "pot", Vector3(cos(ang) * 26.0, 0.1, sin(ang) * 26.0))
			world_builder.spawn_destructible(self, "pole", Vector3(cos(ang) * 31.0, 0.1, sin(ang) * 31.0))

	world_builder.spawn_dynamic_obstacle(self, "chicken", Vector3(-20.0, 0.1, 8.0), Vector3(20.0, 0.1, 8.0), 8.0)
	world_builder.spawn_dynamic_obstacle(self, "angkot", Vector3(-26.0, 0.1, -18.0), Vector3(26.0, 0.1, -18.0), 12.0)


func _spawn_8_combat_karts() -> void:
	for i in range(8):
		var ang := float(i) * TAU / 8.0
		var spawn_pos := Vector3(cos(ang) * 28.0, 0.3, sin(ang) * 28.0)
		var k: KartController = KART_SCRIPT.new()
		if i == 0:
			k.setup_kart(GameConfig.get_player_kart_config(), true, true)
			player_kart = k
		else:
			var ai_def: Dictionary = GameConfig.AI_ROSTER[i - 1]
			k.setup_kart({
				"name": ai_def["name"],
				"personality": ai_def["personality"],
				"aggression": max(float(ai_def["aggression"]), 0.75),
				"body_color": ai_def["color"],
				"spoiler_idx": i % 3,
				"wheel_scale": 1.05,
				"max_speed": 29.0,
				"accel": 21.0,
				"handling": 3.0,
				"drift_charge_rate": 46.0,
				"mass": 1.25 if ai_def["personality"] == "rammer" else 1.0,
				"nitro_power": 13.5
			}, false, true)
		k.look_at_from_position(spawn_pos, Vector3(0.0, 0.3, 0.0), Vector3.UP)
		k.powerup_used.connect(_on_powerup_used)
		k.kart_eliminated.connect(_on_kart_eliminated)
		add_child(k)
		karts.append(k)

	for k in karts:
		k.battle_targets = karts
	world_builder.active_karts = karts
	if player_kart.follow_camera:
		player_kart.follow_camera.current = true


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	var top := HBoxContainer.new()
	top.position = Vector2(20, 14)
	top.add_theme_constant_override("separation", 20)
	cl.add_child(top)

	hud_alive_label = _pill(top, "BERTAHAN: 8 / 8", Color(1.0, 0.85, 0.2))
	hud_ko_label = _pill(top, "ELIMINASI: 0", Color(1.0, 0.45, 0.25))
	hud_item_label = _pill(top, "SENJATA [E]: KOSONG", Color(0.4, 0.92, 1.0))

	var btm := VBoxContainer.new()
	btm.anchor_left = 1.0; btm.anchor_right = 1.0
	btm.anchor_top = 1.0; btm.anchor_bottom = 1.0
	btm.offset_left = -280; btm.offset_right = -24
	btm.offset_top = -120; btm.offset_bottom = -20
	cl.add_child(btm)

	var hp_lbl := Label.new(); hp_lbl.text = "HP KENDARAAN"; btm.add_child(hp_lbl)
	hud_hp_bar = ProgressBar.new(); hud_hp_bar.max_value = 100; hud_hp_bar.value = 100
	hud_hp_bar.custom_minimum_size = Vector2(240, 22); btm.add_child(hud_hp_bar)

	var n_lbl := Label.new(); n_lbl.text = "NITRO [Q] (Tabrak Keras!)"; btm.add_child(n_lbl)
	hud_nitro_bar = ProgressBar.new(); hud_nitro_bar.max_value = 100; hud_nitro_bar.value = 50
	hud_nitro_bar.custom_minimum_size = Vector2(240, 20); btm.add_child(hud_nitro_bar)

	hud_banner = Label.new()
	hud_banner.anchor_left = 0.5; hud_banner.anchor_right = 0.5
	hud_banner.anchor_top = 0.35; hud_banner.anchor_bottom = 0.35
	hud_banner.offset_left = -350; hud_banner.offset_right = 350
	hud_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_banner.add_theme_font_size_override("font_size", 46)
	hud_banner.modulate = Color(1.0, 0.88, 0.2)
	cl.add_child(hud_banner)

	replay_panel = PanelContainer.new()
	replay_panel.anchor_left = 0.5; replay_panel.anchor_right = 0.5
	replay_panel.anchor_top = 1.0; replay_panel.anchor_bottom = 1.0
	replay_panel.offset_left = -280; replay_panel.offset_right = 280
	replay_panel.offset_top = -105; replay_panel.offset_bottom = -35
	replay_panel.visible = false
	cl.add_child(replay_panel)
	var rbox := HBoxContainer.new()
	rbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rbox.add_theme_constant_override("separation", 14)
	replay_panel.add_child(rbox)
	var b1 := Button.new(); b1.text = "Ganti Sudut Replay"
	b1.pressed.connect(func(): replay_sys.cycle_camera_angle()); rbox.add_child(b1)
	var b2 := Button.new(); b2.text = "Battle Lagi"
	b2.pressed.connect(func(): get_tree().reload_current_scene()); rbox.add_child(b2)
	var b3 := Button.new(); b3.text = "Kembali ke Garage"
	b3.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")); rbox.add_child(b3)


func _pill(parent: Control, t: String, col: Color) -> Label:
	var p := PanelContainer.new(); parent.add_child(p)
	var l := Label.new(); l.text = " " + t + " "; l.modulate = col
	l.add_theme_font_size_override("font_size", 18); p.add_child(l)
	return l


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if replay_sys.is_playing:
		replay_sys.tick(delta)
		return

	world_builder.tick_world(self, delta)
	replay_sys.tick(delta)

	var alive := 0
	for k in karts:
		if k.hp > 0.0:
			alive += 1
	hud_alive_label.text = " %s | BERTAHAN: %d / 8 " % [player_kart.racer_name.to_upper(), alive]
	hud_ko_label.text = " ELIMINASI: %d " % player_kart.eliminations
	hud_item_label.text = " SENJATA [E]: %s " % ITEM_NAMES.get(player_kart.held_item, "KOSONG")
	hud_hp_bar.value = player_kart.hp
	hud_nitro_bar.value = player_kart.nitro_energy

	if not match_ended:
		if player_kart.hp <= 0.0:
			match_ended = true
			hud_banner.text = "GOKART HANCUR! (KO: %d)" % player_kart.eliminations
			replay_panel.visible = true
			replay_sys.start_replay()
		elif alive <= 1:
			match_ended = true
			hud_banner.text = "%s JUARA BATTLE ARENA! (KO: %d)" % [player_kart.racer_name.to_upper(), player_kart.eliminations]
			replay_panel.visible = true
			replay_sys.start_replay()


func _on_powerup_used(kart: KartController, item_type: String) -> void:
	world_builder.trigger_powerup(self, kart, item_type)


func _on_kart_eliminated(victim: KartController, attacker: KartController) -> void:
	world_builder.spawn_flying_chaos_burst(self, victim.global_position, true)
	if attacker != null:
		attacker.eliminations += 1
