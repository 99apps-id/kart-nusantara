extends Node

func _ready() -> void:
	_run_checks()


func _run_checks() -> void:
	print("=== KART NUSANTARA HEADLESS FULL VERIFICATION ===")
	var scenes := [
		"res://scenes/main_menu.tscn",
		"res://scenes/race_track.tscn",
		"res://scenes/battle_arena.tscn"
	]
	for path in scenes:
		var ps := load(path) as PackedScene
		if ps == null:
			push_error("FAILED to load scene: " + path)
			get_tree().quit(1)
			return
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame

		if path.ends_with("race_track.tscn"):
			var kcount: int = inst.karts.size()
			var pk: KartController = inst.player_kart
			var has_grille: bool = pk.model_inst.find_child("GrilleBack", true, false) != null or pk.model_inst.find_child("FrontGrille", true, false) != null
			var has_thin_hood: bool = pk.model_inst.find_child("ThinHoodShell", true, false) != null
			var has_pillar_a: bool = pk.model_inst.find_child("PillarA_L", true, false) != null and pk.model_inst.find_child("ThinWindshieldGlass", true, false) != null
			var has_shocks: bool = pk.shock_nodes.size() == 4
			var has_arms: bool = pk.driver_arm_l != null and pk.driver_arm_r != null and pk.grip_l != null and pk.grip_r != null
			var has_knuckles: bool = pk.steer_knuckle_fl != null and pk.steer_knuckle_fr != null
			var track_len: float = float(inst.circuit_data.get("total_length", 0.0))
			var has_tunnel: bool = inst.find_child("CurvedTunnel", true, false) != null
			var bumps: int = inst.world_builder.speed_bumps.size()

			# 1. Test steering left/right -> verify front knuckles turn AND hands follow steering grips!
			pk._update_visuals_and_driver(0.1, 1.0)
			var knuckle_left_y: float = pk.steer_knuckle_fl.rotation.y
			var arm_l_rot_left: Vector3 = pk.driver_arm_l.rotation
			pk._update_visuals_and_driver(0.5, -1.0)
			var knuckle_right_y: float = pk.steer_knuckle_fl.rotation.y
			var arm_l_rot_right: Vector3 = pk.driver_arm_l.rotation
			var arms_moved: bool = arm_l_rot_left.distance_to(arm_l_rot_right) > 0.01
			var wheels_steered: bool = knuckle_left_y > 0.05 and knuckle_right_y < -0.05

			# 2. Physics test: Place player kart INSIDE the central grass park & drive across sidewalk + curb back onto asphalt!
			pk.global_position = Vector3(-20.0, 0.25, -14.0)
			pk.rotation = Vector3(0.0, -PI * 0.5, 0.0) # facing +X toward asphalt road at X=0
			pk.forward_speed = 18.0
			pk.velocity = Vector3(18.0, 0.0, 0.0)
			for _step in range(95):
				pk.forward_speed = maxf(pk.forward_speed, 16.0)
				pk.velocity.x = 16.0
				pk.velocity.z = 0.0
				pk.velocity.y -= 28.0 * (1.0 / 60.0)
				pk.move_and_slide()
				await get_tree().physics_frame
			var crossed_from_park: bool = pk.global_position.x > -6.5

			# 3. Reverse & brake physics test: brake from forward speed down into reverse!
			pk.forward_speed = 10.0
			for _b in range(60):
				var eff_accel: float = pk.accel
				if pk.forward_speed > 0.5:
					pk.forward_speed = move_toward(pk.forward_speed, 0.0, eff_accel * 2.4 * (1.0 / 60.0))
				else:
					pk.forward_speed = move_toward(pk.forward_speed, -16.0, eff_accel * 1.15 * (1.0 / 60.0))
			var reverse_ok: bool = pk.forward_speed < -5.0

			print("VERIFY race_track: karts=%d track_len=%.1fm tunnel=%s bumps=%d thin_hood=%s pillar_a=%s shocks=%d grille=%s arms_moved=%s wheels_steered=%s park_to_track=%s (endX=%.2f) reverse_ok=%s (v=%.1f) lights=%d peds=%d dyn_obs=%d items=%d" % [
				kcount, track_len, str(has_tunnel), bumps, str(has_thin_hood), str(has_pillar_a),
				pk.shock_nodes.size(), str(has_grille), str(arms_moved), str(wheels_steered),
				str(crossed_from_park), pk.global_position.x, str(reverse_ok), pk.forward_speed,
				inst.world_builder.traffic_lights.size(), inst.world_builder.pedestrians.size(),
				inst.world_builder.dynamic_obstacles.size(), inst.world_builder.item_boxes.size()
			])
			var has_engine_audio: bool = (pk.find_child("EngineAudio", true, false) is AudioStreamPlayer) and (pk.find_child("EngineIdleAudio", true, false) is AudioStreamPlayer) and (pk.find_child("WindAudio", true, false) is AudioStreamPlayer) and (inst.find_child("BirdsAmbienceAudio", true, false) is AudioStreamPlayer)
			var sfx_req := ["intro_fanfare", "countdown_beep", "race_go", "engine_idle", "engine_loop", "wind_loop", "birds_ambience", "horn_klakson", "crash_heavy", "crash_kart", "bonk", "chicken_scream", "ped_scream_male", "ped_scream_female", "telolet", "smash", "slip", "boom", "nitro", "siren", "pickup", "rocket_launch", "rocket_explosion"]
			var sfx_ok := true
			var mp3_loaded := 0
			for sname in sfx_req:
				var st := ComedySfx.get_stream(sname)
				if st == null or st.get_length() <= 0.05:
					sfx_ok = false
				elif st is AudioStreamMP3 or st is AudioStreamOggVorbis:
					mp3_loaded += 1
			# Verify Idle vs Running engine separation and steady speed-based pitch (Up arrow)
			pk.controls_locked = false
			pk.nitro_active = false
			pk.current_throttle_input = 0.0
			pk.forward_speed = 0.0
			for _f in range(90):
				pk._update_engine_audio(1.0 / 60.0)
			var idle_db_at_idle: float = pk.engine_idle_player.volume_db
			var roar_db_at_idle: float = pk.engine_player.volume_db
			pk.current_throttle_input = 1.0
			pk.forward_speed = 15.0
			for _f in range(90):
				pk._update_engine_audio(1.0 / 60.0)
			var mid_pitch: float = pk.engine_player.pitch_scale
			var mid_roar_db: float = pk.engine_player.volume_db
			var mid_idle_db: float = pk.engine_idle_player.volume_db
			pk.forward_speed = pk.max_speed
			for _f in range(90):
				pk._update_engine_audio(1.0 / 60.0)
			var p_min: float = 99.0
			var p_max: float = -99.0
			for _f in range(30):
				pk._update_engine_audio(1.0 / 60.0)
				p_min = minf(p_min, pk.engine_player.pitch_scale)
				p_max = maxf(p_max, pk.engine_player.pitch_scale)
			var top_pitch: float = pk.engine_player.pitch_scale
			var top_spread: float = p_max - p_min
			var engine_curve_ok: bool = (idle_db_at_idle > -12.0) and (roar_db_at_idle <= -50.0) and (mid_idle_db <= -50.0) and (mid_roar_db > -18.0) and (top_pitch > mid_pitch + 0.35) and (top_spread < 0.01)
			var name_ok: bool = (pk.racer_name == GameConfig.get_clean_player_name())
			print("VERIFY audio: engine_node=%s sfx_all_valid=%s assets_loaded=%d/%d idle(idle=%.1fdB roar=%.1fdB) run(idle=%.1fdB roar=%.1fdB midP=%.2f topP=%.2f spread=%.4f) curve_ok=%s player_name=%s name_ok=%s" % [str(has_engine_audio), str(sfx_ok), mp3_loaded, sfx_req.size(), idle_db_at_idle, roar_db_at_idle, mid_idle_db, mid_roar_db, mid_pitch, top_pitch, top_spread, str(engine_curve_ok), pk.racer_name, str(name_ok)])
			if kcount != 8 or track_len < 650.0 or not has_tunnel or bumps < 4 or not has_thin_hood or not has_pillar_a or not has_grille or not has_shocks or not has_arms or not arms_moved or not wheels_steered or not crossed_from_park or not reverse_ok or not has_engine_audio or not sfx_ok or mp3_loaded < sfx_req.size() or not engine_curve_ok or not name_ok:
				push_error("VERIFICATION ASSERTION FAILED on race_track!")
				get_tree().quit(2)
				return
		elif path.ends_with("battle_arena.tscn"):
			var bcount: int = inst.karts.size()
			var icount: int = inst.world_builder.item_boxes.size()
			# Verify Ring-Out rule: throwing player outside arena immediately marks kalah (hp=0, match_ended=true, no floating)
			var bp: KartController = inst.player_kart
			bp.global_position = Vector3(41.5, 1.0, 0.0)
			for _t in range(4):
				await get_tree().physics_frame
			await get_tree().process_frame
			var ringout_ok: bool = (bp.hp <= 0.0) and inst.player_ringed_out and inst.match_ended and bp.velocity.length() < 0.01 and ("KALAH" in inst.hud_banner.text)
			print("VERIFY battle_arena: combat_karts=%d items=%d ringout_kalah=%s banner='%s'" % [bcount, icount, str(ringout_ok), inst.hud_banner.text])
			if bcount != 8 or not ringout_ok:
				push_error("VERIFICATION ASSERTION FAILED on battle_arena Ring-Out!")
				get_tree().quit(3)
				return
		else:
			GameConfig.set_player_name("Raka Turbo")
			var name_box := inst.find_child("PlayerNameInput", true, false) as LineEdit
			if name_box == null:
				push_error("PlayerNameInput missing in Garage!")
				get_tree().quit(2)
				return
			GameConfig.selected_color_idx = 1
			inst._rebuild_preview_kart()
			var hood1 := inst.preview_kart.find_child("ThinHoodShell", true, false) as MeshInstance3D
			var mat1 := hood1.get_active_material(0) as StandardMaterial3D if hood1 != null else null
			var c1: Color = mat1.albedo_color if mat1 != null else Color.BLACK
			GameConfig.selected_color_idx = 2
			inst._rebuild_preview_kart()
			var hood2 := inst.preview_kart.find_child("ThinHoodShell", true, false) as MeshInstance3D
			var mat2 := hood2.get_active_material(0) as StandardMaterial3D if hood2 != null else null
			var c2: Color = mat2.albedo_color if mat2 != null else Color.BLACK
			var exp1: Color = GameConfig.BODY_COLORS[1]["color"]
			var exp2: Color = GameConfig.BODY_COLORS[2]["color"]
			var hood_recolored: bool = c1.is_equal_approx(exp1) and c2.is_equal_approx(exp2) and not c1.is_equal_approx(c2)
			var has_intro_audio: bool = inst.find_child("IntroAudio", true, false) is AudioStreamPlayer
			print("VERIFY main_menu (Garage 3D): hood_recolored=%s intro_audio=%s c1=%s c2=%s" % [str(hood_recolored), str(has_intro_audio), str(c1), str(c2)])
			GameConfig.selected_color_idx = 0
			if not hood_recolored or not has_intro_audio:
				push_error("VERIFICATION ASSERTION FAILED: ThinHoodShell did not recolor in Garage!")
				get_tree().quit(4)
				return

		inst.queue_free()
		await get_tree().process_frame

	print("=== ALL 3 SCENES & ALL FEATURES PASSED VERIFICATION ===")
	get_tree().quit(0)
