extends CharacterBody3D
class_name KartController

signal powerup_used(kart: KartController, item_type: String)
signal kart_eliminated(victim: KartController, attacker: KartController)

static var _cached_kart_scene: PackedScene = null
static var _shared_smoke_mesh: SphereMesh = null

static func _get_smoke_mesh() -> SphereMesh:
	if _shared_smoke_mesh == null:
		_shared_smoke_mesh = SphereMesh.new()
		_shared_smoke_mesh.radius = 0.10
		_shared_smoke_mesh.height = 0.18
		_shared_smoke_mesh.radial_segments = 6
		_shared_smoke_mesh.rings = 4
	return _shared_smoke_mesh

static func _get_kart_scene() -> PackedScene:
	if _cached_kart_scene == null:
		_cached_kart_scene = load("res://assets/models/bajaj_kart.glb") as PackedScene
	return _cached_kart_scene

@export var is_player: bool = false
@export var is_battle_mode: bool = false

var racer_name: String = "Pembalap"
var personality: String = "balanced"
var aggression: float = 0.5
var shortcut_chance: float = 0.45

# Stats (from Garage / AI profile)
var max_speed: float = 31.0
var accel: float = 22.0
var handling: float = 2.85
var drift_charge_rate: float = 42.0
var kart_mass: float = 1.0
var nitro_power: float = 14.0

# Driving state
var forward_speed: float = 0.0
var steer_visual: float = 0.0
var wheel_spin: float = 0.0
var is_drifting: bool = false
var drift_dir: float = 0.0
var drift_time: float = 0.0
var nitro_energy: float = 35.0 # 0..100
var nitro_active: bool = false
var mini_turbo_timer: float = 0.0
var controls_locked: bool = false

# Collision / Hazard / Combat state
var spinout_timer: float = 0.0
var flip_timer: float = 0.0
var flip_axis: Vector3 = Vector3.RIGHT
var oil_slip_timer: float = 0.0
var shield_timer: float = 0.0
var held_item: String = ""
var hp: float = 100.0
var eliminations: int = 0
var last_attacker: KartController = null

# Race progress
var current_lap: int = 1
var current_wp: int = 0
var total_progress: float = 0.0
var finished: bool = false
var finish_time: float = 0.0
var using_shortcut: bool = false
var ai_item_cooldown: float = 2.0
var ai_lane_offset: float = 0.0
var waypoints: Array[Vector3] = []
var shortcut_waypoints: Array[Vector3] = []
var shortcut_entry_wp: int = 4
var shortcut_exit_wp: int = 7
var shortcut_sub_idx: int = 0
var battle_targets: Array = []

# Visual & Articulated Driver Nodes
var visual_root: Node3D
var model_inst: Node3D
var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_rl: Node3D
var wheel_rr: Node3D
var steer_knuckle_fl: Node3D
var steer_knuckle_fr: Node3D
var steering_pivot: Node3D
var grip_l: Node3D
var grip_r: Node3D
var driver_torso: Node3D
var driver_head: Node3D
var driver_arm_l: Node3D
var driver_arm_r: Node3D
var driver_foot_l: Node3D
var driver_foot_r: Node3D
var flame_l: MeshInstance3D
var flame_r: MeshInstance3D
var shield_mesh: MeshInstance3D
var drift_spark_l: MeshInstance3D
var drift_spark_r: MeshInstance3D
var camera_rig: Node3D
var follow_camera: Camera3D
var name_label: Label3D
var steering_base_rot: Vector3 = Vector3.ZERO
var arm_l_rest_rot: Vector3 = Vector3.ZERO
var arm_r_rest_rot: Vector3 = Vector3.ZERO

var current_throttle_input: float = 0.0
var current_brake_input: float = 0.0
var exhaust_smoke_timer: float = 0.0
var smoke_puffs: Array = []
var shock_nodes: Array = []
var susp_phase: float = 0.0
var was_on_floor: bool = true
var landing_bounce: float = 0.0
var camera_shake: float = 0.0
var horn_cooldown: float = 0.0
var nitro_sfx_cd: float = 0.0
var crash_sfx_cd: float = 0.0
var engine_player: AudioStreamPlayer
var engine_idle_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer


func setup_kart(cfg: Dictionary, player_flag: bool, battle_flag: bool = false) -> void:
	is_player = player_flag
	is_battle_mode = battle_flag
	racer_name = str(cfg.get("name", "Pembalap"))
	personality = str(cfg.get("personality", "balanced"))
	aggression = float(cfg.get("aggression", 0.5))
	shortcut_chance = float(cfg.get("shortcut_chance", 0.45))
	max_speed = float(cfg.get("max_speed", 31.0))
	accel = float(cfg.get("accel", 22.0))
	handling = float(cfg.get("handling", 2.85))
	drift_charge_rate = float(cfg.get("drift_charge_rate", 42.0))
	kart_mass = float(cfg.get("mass", 1.0))
	nitro_power = float(cfg.get("nitro_power", 14.0))
	ai_lane_offset = randf_range(-2.8, 2.8)
	_build_nodes(cfg)


func _build_nodes(cfg: Dictionary) -> void:
	# Collision shape
	# Smooth beveled-bottom convex skid hull so the kart glides effortlessly over sidewalks, curbs, speedbumps & park transitions (never snags!)
	var col := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array([
		# Tapered lower skid rim (0.24 m chamfered bevel all around)
		Vector3(-0.62, 0.02, -0.88), Vector3(0.62, 0.02, -0.88),
		Vector3(-0.62, 0.02,  0.88), Vector3(0.62, 0.02,  0.88),
		# Full waist belt at y = 0.28
		Vector3(-0.82, 0.28, -1.14), Vector3(0.82, 0.28, -1.14),
		Vector3(-0.82, 0.28,  1.14), Vector3(0.82, 0.28,  1.14),
		# Upper canopy at y = 1.15
		Vector3(-0.76, 1.15, -1.04), Vector3(0.76, 1.15, -1.04),
		Vector3(-0.76, 1.15,  1.04), Vector3(0.76, 1.15,  1.04),
	])
	col.shape = hull
	add_child(col)
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.35
	safe_margin = 0.04

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	model_inst = _get_kart_scene().instantiate()
	visual_root.add_child(model_inst)

	# Recolor Mat_Body and configure Garage spoiler & wheel scale
	var body_color: Color = cfg.get("body_color", Color(0.95, 0.38, 0.08))
	var spoiler_idx: int = int(cfg.get("spoiler_idx", 1))
	var wheel_scale: float = float(cfg.get("wheel_scale", 1.0))
	_customize_model(model_inst, body_color, spoiler_idx, wheel_scale)
	ChaosWorldBuilder.apply_realistic_glass(model_inst)

	# Bind wheels & articulated driver parts
	wheel_fl = model_inst.find_child("Wheel_FL", true, false) as Node3D
	wheel_fr = model_inst.find_child("Wheel_FR", true, false) as Node3D
	wheel_rl = model_inst.find_child("Wheel_RL", true, false) as Node3D
	wheel_rr = model_inst.find_child("Wheel_RR", true, false) as Node3D
	# Wrap front wheels in dedicated steering knuckles so yaw (steer L/R) & pitch (spin) never gimbal-conflict!
	steer_knuckle_fl = _wrap_wheel_in_knuckle(wheel_fl, "SteerKnuckle_FL")
	steer_knuckle_fr = _wrap_wheel_in_knuckle(wheel_fr, "SteerKnuckle_FR")
	steering_pivot = model_inst.find_child("SteeringPivot", true, false) as Node3D
	grip_l = model_inst.find_child("Grip_L", true, false) as Node3D
	grip_r = model_inst.find_child("Grip_R", true, false) as Node3D
	driver_torso = model_inst.find_child("DriverTorsoPivot", true, false) as Node3D
	driver_head = model_inst.find_child("DriverHeadPivot", true, false) as Node3D
	driver_arm_l = model_inst.find_child("DriverArm_L", true, false) as Node3D
	driver_arm_r = model_inst.find_child("DriverArm_R", true, false) as Node3D
	driver_foot_l = model_inst.find_child("DriverLeg_L_Foot", true, false) as Node3D
	driver_foot_r = model_inst.find_child("DriverLeg_R_Foot", true, false) as Node3D
	if steering_pivot:
		steering_base_rot = steering_pivot.rotation
	if driver_arm_l:
		arm_l_rest_rot = driver_arm_l.rotation
	if driver_arm_r:
		arm_r_rest_rot = driver_arm_r.rotation
	for sname in ["Shock_FL", "Shock_FR", "Shock_RL", "Shock_RR"]:
		var sn := model_inst.find_child(sname, true, false) as Node3D
		if sn:
			shock_nodes.append(sn)

	# Nitro exhaust flames
	flame_l = _make_flame_cone(Vector3(-0.28, 0.60, 1.32))
	flame_r = _make_flame_cone(Vector3(0.28, 0.60, 1.32))
	visual_root.add_child(flame_l)
	visual_root.add_child(flame_r)

	# Drift spark cones near rear tires
	drift_spark_l = _make_spark_orb(Vector3(-0.74, 0.16, 0.85))
	drift_spark_r = _make_spark_orb(Vector3(0.74, 0.16, 0.85))
	visual_root.add_child(drift_spark_l)
	visual_root.add_child(drift_spark_r)

	# Shield bubble
	shield_mesh = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.65
	sph.height = 3.0
	shield_mesh.mesh = sph
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.18, 0.78, 1.0, 0.30)
	smat.emission_enabled = true
	smat.emission = Color(0.2, 0.85, 1.0)
	smat.emission_energy_multiplier = 1.6
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = smat
	shield_mesh.position = Vector3(0.0, 0.85, 0.0)
	shield_mesh.visible = false
	visual_root.add_child(shield_mesh)

	# Floating nameplate (especially useful for 7 AI opponents & Battle Arena HP)
	if not is_player:
		name_label = Label3D.new()
		name_label.text = racer_name
		name_label.font_size = 42
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.position = Vector3(0.0, 2.05, 0.0)
		name_label.modulate = Color(1.0, 0.96, 0.8)
		name_label.outline_size = 8
		add_child(name_label)
	else:
		# Player chase camera
		camera_rig = Node3D.new()
		camera_rig.name = "CameraRig"
		add_child(camera_rig)
		follow_camera = Camera3D.new()
		follow_camera.fov = 68.0
		follow_camera.position = Vector3(0.0, 3.25, 6.4)
		follow_camera.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
		camera_rig.add_child(follow_camera)

		# Dual-layer realistic engine audio: warm idle loop + aggressive high-RPM roar + aerodynamic wind loop
		engine_idle_player = AudioStreamPlayer.new()
		engine_idle_player.name = "EngineIdleAudio"
		engine_idle_player.stream = ComedySfx.get_stream("engine_idle")
		engine_idle_player.volume_db = -10.5
		engine_idle_player.pitch_scale = 0.96
		engine_idle_player.autoplay = true
		add_child(engine_idle_player)

		engine_player = AudioStreamPlayer.new()
		engine_player.name = "EngineAudio"
		engine_player.stream = ComedySfx.get_stream("engine_loop")
		engine_player.volume_db = -26.0
		engine_player.pitch_scale = 0.76
		engine_player.autoplay = true
		add_child(engine_player)

		wind_player = AudioStreamPlayer.new()
		wind_player.name = "WindAudio"
		wind_player.stream = ComedySfx.get_stream("wind_loop")
		wind_player.volume_db = -38.0
		wind_player.pitch_scale = 0.85
		wind_player.autoplay = true
		add_child(wind_player)


func _customize_model(root: Node, body_color: Color, spoiler_idx: int, wheel_scale: float) -> void:
	var wing := root.find_child("Spoiler_Wing", true, false) as Node3D
	var basket := root.find_child("Spoiler_Basket", true, false) as Node3D
	if wing:
		wing.visible = (spoiler_idx == 1)
	if basket:
		basket.visible = (spoiler_idx == 2)

	for wname in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wn := root.find_child(wname, true, false) as Node3D
		if wn:
			wn.scale = Vector3(wheel_scale, wheel_scale, wheel_scale)

	# Recolor Mat_Body on all child MeshInstance3Ds
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.mesh.surface_get_material(s)
					if mat == null:
						mat = mi.get_active_material(s)
					if mat != null and mat.resource_name.begins_with("Mat_Body"):
						var dup := mat.duplicate() as StandardMaterial3D
						if dup:
							dup.resource_name = mat.resource_name
							dup.albedo_color = body_color
							mi.set_surface_override_material(s, dup)
		for ch in n.get_children():
			stack.append(ch)


func _wrap_wheel_in_knuckle(wheel_node: Node3D, knuckle_name: String) -> Node3D:
	if wheel_node == null or wheel_node.get_parent() == null:
		return null
	var p := wheel_node.get_parent()
	var knuckle := Node3D.new()
	knuckle.name = knuckle_name
	knuckle.position = wheel_node.position
	p.add_child(knuckle)
	wheel_node.owner = null
	wheel_node.reparent(knuckle, false)
	wheel_node.position = Vector3.ZERO
	return knuckle


func _make_flame_cone(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = 0.14
	cone.height = 0.95
	mi.mesh = cone
	mi.position = pos
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.05)
	mat.emission_energy_multiplier = 4.5
	mi.material_override = mat
	mi.visible = false
	return mi


func _make_spark_orb(pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.35
	mi.mesh = sph
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.1)
	mat.emission_energy_multiplier = 3.5
	mi.material_override = mat
	mi.visible = false
	return mi


func _physics_process(delta: float) -> void:
	if is_battle_mode and hp <= 0.0:
		visible = false
		return

	# Timers
	if shield_timer > 0.0:
		shield_timer = max(0.0, shield_timer - delta)
		shield_mesh.visible = shield_timer > 0.0
		shield_mesh.rotate_y(delta * 2.5)
	if mini_turbo_timer > 0.0:
		mini_turbo_timer = max(0.0, mini_turbo_timer - delta)
	if oil_slip_timer > 0.0:
		oil_slip_timer = max(0.0, oil_slip_timer - delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= 28.0 * delta
	else:
		velocity.y = min(velocity.y, -0.5)

	# Handle Spin-out / Flip-roll physics recovery
	if flip_timer > 0.0:
		flip_timer = max(0.0, flip_timer - delta)
		visual_root.rotate_object_local(flip_axis, delta * 9.5)
		velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
		move_and_slide()
		if flip_timer <= 0.0:
			visual_root.rotation = Vector3.ZERO
		return

	if spinout_timer > 0.0:
		spinout_timer = max(0.0, spinout_timer - delta)
		visual_root.rotate_y(delta * 12.5)
		forward_speed = move_toward(forward_speed, 0.0, delta * 18.0)
		var fwd_s := -global_basis.z
		velocity.x = fwd_s.x * forward_speed
		velocity.z = fwd_s.z * forward_speed
		move_and_slide()
		if spinout_timer <= 0.0:
			visual_root.rotation = Vector3.ZERO
		return

	var throttle := 0.0
	var steer := 0.0
	var want_drift := false
	var want_nitro := false
	var want_item := false

	if not controls_locked:
		if is_player:
			if Input.is_action_pressed("accelerate"):
				throttle += 1.0
			if Input.is_action_pressed("brake"):
				throttle -= 1.0
			if Input.is_action_pressed("steer_left"):
				steer += 1.0
			if Input.is_action_pressed("steer_right"):
				steer -= 1.0
			want_drift = Input.is_action_pressed("drift")
			want_nitro = Input.is_action_pressed("nitro")
			want_item = Input.is_action_just_pressed("use_item")
			if Input.is_action_just_pressed("drift") and is_on_floor() and abs(forward_speed) > 6.0:
				velocity.y = 6.2 # Arcade hop!
		else:
			var ai_cmd := _compute_ai_controls(delta)
			throttle = ai_cmd["throttle"]
			steer = ai_cmd["steer"]
			want_drift = ai_cmd["drift"]
			want_nitro = ai_cmd["nitro"]
			want_item = ai_cmd["use_item"]

	current_throttle_input = max(throttle, 0.0)
	current_brake_input = max(-throttle, 0.0)

	if want_item and held_item != "":
		var item_to_fire := held_item
		held_item = ""
		emit_signal("powerup_used", self, item_to_fire)

	# Nitro activation
	nitro_sfx_cd = maxf(0.0, nitro_sfx_cd - delta)
	horn_cooldown = maxf(0.0, horn_cooldown - delta)
	crash_sfx_cd = maxf(0.0, crash_sfx_cd - delta)
	if is_player and horn_cooldown <= 0.0:
		if Input.is_key_pressed(KEY_H):
			horn_cooldown = 0.65
			ComedySfx.play(self, "horn_klakson", -4.0)
		elif Input.is_key_pressed(KEY_T):
			horn_cooldown = 1.25
			ComedySfx.play(self, "telolet", -4.0)
	nitro_active = want_nitro and nitro_energy > 4.0 and throttle >= 0.0
	if nitro_active:
		nitro_energy = max(0.0, nitro_energy - 34.0 * delta)
		if is_player and nitro_sfx_cd <= 0.0:
			nitro_sfx_cd = 0.45
			ComedySfx.play(self, "nitro", -8.0)
			add_camera_shake(0.12)

	# Effective top speed
	var eff_max := max_speed
	if nitro_active:
		eff_max += nitro_power
	if mini_turbo_timer > 0.0:
		eff_max += 9.5

	# Drift state machine
	if want_drift and abs(forward_speed) > 10.0 and is_on_floor():
		if not is_drifting and abs(steer) > 0.15:
			is_drifting = true
			drift_dir = sign(steer)
			drift_time = 0.0
		elif is_drifting:
			drift_time += delta
			nitro_energy = min(100.0, nitro_energy + drift_charge_rate * delta)
	else:
		if is_drifting:
			if drift_time >= 0.85:
				mini_turbo_timer = 1.6 if drift_time >= 2.0 else 0.9
				nitro_energy = min(100.0, nitro_energy + 12.0)
			is_drifting = false
			drift_dir = 0.0
			drift_time = 0.0

	# Acceleration / Crisp Braking (Rem) & Reverse (Mundur)
	var eff_accel := accel * (1.45 if nitro_active else 1.0)
	if throttle > 0.0:
		if forward_speed < -0.5:
			# Coming out of reverse -> crisp brake forward
			forward_speed = move_toward(forward_speed, 0.0, 48.0 * delta)
		else:
			forward_speed = move_toward(forward_speed, eff_max * throttle, eff_accel * delta)
	elif throttle < 0.0:
		if forward_speed > 0.8:
			# Crisp Braking (Rem) when moving forward!
			forward_speed = move_toward(forward_speed, 0.0, 50.0 * delta)
		else:
			# Smooth Reverse gear (Mundur) up to -16 m/s!
			forward_speed = move_toward(forward_speed, -16.0, 28.0 * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, 12.0 * delta)

	# Steering (responsive forward & natural reverse steering, oil slick causes wobble!)
	var steer_factor := handling
	if is_drifting:
		steer_factor *= 1.32
	if oil_slip_timer > 0.0:
		steer += sin(Time.get_ticks_msec() * 0.025) * 1.35
	var speed_turn_scale: float = clampf(absf(forward_speed) / 6.0, 0.0, 1.0)
	var turn_sign := 1.0 if forward_speed >= -0.15 else -1.0
	var active_steer := steer
	if is_drifting:
		active_steer = drift_dir * 0.65 + steer * 0.55
	if absf(forward_speed) > 0.2:
		rotate_y(active_steer * steer_factor * speed_turn_scale * turn_sign * delta)

	# Apply horizontal velocity (with lateral drift slide)
	var fwd := -global_basis.z
	var right := global_basis.x
	var target_vel := fwd * forward_speed
	if is_drifting:
		target_vel += right * (-drift_dir * forward_speed * 0.22)
	var grip := 6.5 if is_drifting else (2.0 if oil_slip_timer > 0.0 else 11.5)
	velocity.x = lerp(velocity.x, target_vel.x, clamp(delta * grip, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target_vel.z, clamp(delta * grip, 0.0, 1.0))

	move_and_slide()
	_handle_collisions()
	_update_visuals_and_driver(delta, active_steer)
	_update_engine_audio(delta)
	_update_progress()


func _update_engine_audio(delta: float) -> void:
	if not is_player or engine_player == null:
		return
	if not engine_player.playing and engine_player.stream != null:
		engine_player.play()
	if engine_idle_player != null and not engine_idle_player.playing and engine_idle_player.stream != null:
		engine_idle_player.play()
	if wind_player != null and not wind_player.playing and wind_player.stream != null:
		wind_player.play()
	var speed_ratio: float = clampf(absf(forward_speed) / maxf(max_speed, 1.0), 0.0, 1.45)
	var load_ratio: float = clampf(speed_ratio * 0.85 + (0.35 if current_throttle_input > 0.1 else 0.0) + (0.35 if nitro_active else 0.0), 0.0, 1.2)
	var throttle_boost: float = 0.18 if current_throttle_input > 0.1 else (0.08 if current_brake_input > 0.1 and forward_speed < -0.5 else 0.0)
	var target_pitch: float = 0.72 + speed_ratio * 1.15 + throttle_boost
	if nitro_active:
		target_pitch += 0.34
	elif is_drifting:
		target_pitch += 0.09 + sin(Time.get_ticks_msec() * 0.04) * 0.03
	if not is_on_floor():
		target_pitch += 0.12
	# Crossfade: warm idle purr at low speed -> roaring racing engine under acceleration
	if engine_idle_player != null:
		var idle_vol: float = lerpf(-9.5, -26.0, clampf(load_ratio * 1.35, 0.0, 1.0))
		var idle_pitch: float = 0.94 + speed_ratio * 0.30 + (0.08 if current_throttle_input > 0.1 else 0.0)
		engine_idle_player.volume_db = lerpf(engine_idle_player.volume_db, idle_vol, clampf(delta * 7.0, 0.0, 1.0))
		engine_idle_player.pitch_scale = lerpf(engine_idle_player.pitch_scale, clampf(idle_pitch, 0.85, 1.4), clampf(delta * 8.0, 0.0, 1.0))
	var roar_vol: float = lerpf(-26.0, -7.0, clampf(load_ratio, 0.0, 1.0)) + (1.8 if nitro_active else 0.0)
	engine_player.pitch_scale = lerpf(engine_player.pitch_scale, clampf(target_pitch, 0.65, 2.35), clampf(delta * 9.0, 0.0, 1.0))
	engine_player.volume_db = lerpf(engine_player.volume_db, clampf(roar_vol, -28.0, -4.5), clampf(delta * 8.0, 0.0, 1.0))
	# Aerodynamic wind rushes past helmet as speed climbs
	if wind_player != null:
		var wind_factor: float = clampf((absf(forward_speed) - 6.0) / maxf(max_speed, 1.0), 0.0, 1.3)
		var wind_vol: float = lerpf(-40.0, -10.5, clampf(wind_factor, 0.0, 1.0)) + (2.5 if nitro_active else 0.0)
		var wind_pitch: float = 0.80 + wind_factor * 0.55 + (0.20 if nitro_active else 0.0)
		wind_player.volume_db = lerpf(wind_player.volume_db, clampf(wind_vol, -42.0, -7.0), clampf(delta * 6.0, 0.0, 1.0))
		wind_player.pitch_scale = lerpf(wind_player.pitch_scale, clampf(wind_pitch, 0.75, 1.65), clampf(delta * 6.0, 0.0, 1.0))


func _handle_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		if collider is KartController:
			var other := collider as KartController
			var push_dir := (other.global_position - global_position)
			push_dir.y = 0.0
			if push_dir.length() > 0.01:
				push_dir = push_dir.normalized()
			var rel_speed := (velocity - other.velocity).length()
			if rel_speed > 6.5:
				if (is_player or other.is_player) and crash_sfx_cd <= 0.0:
					crash_sfx_cd = 0.28
					var sfx_id := "crash_heavy" if rel_speed > 17.0 else "crash_kart"
					ComedySfx.play(self, sfx_id, -4.5, randf_range(0.90, 1.12))
					if is_player:
						add_camera_shake(clampf(rel_speed * 0.025, 0.16, 0.55))
					elif other.is_player:
						other.add_camera_shake(clampf(rel_speed * 0.025, 0.16, 0.55))
			if rel_speed > 8.0:
				var force: float = clampf(rel_speed * 0.45 * (kart_mass / maxf(other.kart_mass, 0.5)), 4.0, 18.0)
				other.velocity += push_dir * force
				other.velocity.y = max(other.velocity.y, 4.5)
				if force > 11.5 and other.shield_timer <= 0.0:
					other.apply_spinout(1.0)
				if is_battle_mode and other.shield_timer <= 0.0 and (nitro_active or rel_speed > 14.0):
					other.take_battle_damage(20.0, self)
		elif collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var hit_dir := (rb.global_position - global_position).normalized()
			var impulse_mag: float = maxf(absf(forward_speed) * 1.15 * kart_mass, 12.0)
			rb.apply_impulse((hit_dir + Vector3(0.0, 0.65, 0.0)) * impulse_mag)
			rb.apply_torque_impulse(Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)))
			if is_player and crash_sfx_cd <= 0.0:
				crash_sfx_cd = 0.22
				ComedySfx.play(self, "smash", -5.5, randf_range(0.88, 1.15))
				add_camera_shake(0.22)
			if rb.has_method("on_smashed_by_kart"):
				rb.on_smashed_by_kart(self)
			if not nitro_active and shield_timer <= 0.0:
				forward_speed *= 0.88
		elif collider is StaticBody3D:
			# Horizontal wall / building / tunnel-side impact
			if absf(col.get_normal().y) < 0.35 and absf(forward_speed) > 9.0:
				if is_player and crash_sfx_cd <= 0.0:
					crash_sfx_cd = 0.35
					ComedySfx.play(self, "crash_heavy", -5.0, randf_range(0.88, 1.08))
					add_camera_shake(0.35)


func _update_visuals_and_driver(delta: float, active_steer: float) -> void:
	steer_visual = lerp(steer_visual, clamp(active_steer, -1.0, 1.0), clamp(delta * 10.0, 0.0, 1.0))
	wheel_spin += forward_speed * delta * 3.1

	# 1. Steer front knuckles left/right (~33 deg) + spin all 4 detailed wheels independently!
	var front_steer_rad := steer_visual * 0.58
	if steer_knuckle_fl:
		steer_knuckle_fl.rotation.y = front_steer_rad
	if steer_knuckle_fr:
		steer_knuckle_fr.rotation.y = front_steer_rad
	if wheel_fl:
		wheel_fl.rotation.x = -wheel_spin
	if wheel_fr:
		wheel_fr.rotation.x = -wheel_spin
	if wheel_rl:
		wheel_rl.rotation.x = -wheel_spin
	if wheel_rr:
		wheel_rr.rotation.x = -wheel_spin

	# 2. Body drift yaw & roll tilt
	var target_yaw := -drift_dir * 0.24 if is_drifting else 0.0
	var target_roll := -steer_visual * 0.12
	visual_root.rotation.y = lerp(visual_root.rotation.y, target_yaw, clamp(delta * 8.0, 0.0, 1.0))
	visual_root.rotation.z = lerp(visual_root.rotation.z, target_roll, clamp(delta * 8.0, 0.0, 1.0))

	# 3. Articulated Steering Wheel + Driver Hands + Head + Torso + Pedals/Feet!
	if steering_pivot:
		# Spin steering wheel around its local column axis (Y in Godot after glTF Z-up->Y-up)
		steering_pivot.rotation = steering_base_rot
		steering_pivot.rotate_object_local(Vector3.UP, steer_visual * 1.18)

	if driver_torso:
		driver_torso.rotation.z = lerp(driver_torso.rotation.z, steer_visual * 0.16, clamp(delta * 9.0, 0.0, 1.0))
	if driver_head:
		driver_head.rotation.y = lerp(driver_head.rotation.y, steer_visual * 0.42, clamp(delta * 9.0, 0.0, 1.0))

	# Left & Right arms actively track the turning steering wheel grips (Grip_L / Grip_R)!
	if driver_arm_l and grip_l:
		var target_l := grip_l.global_position
		if driver_arm_l.global_position.distance_to(target_l) > 0.05:
			driver_arm_l.look_at(target_l, global_basis.y)
	if driver_arm_r and grip_r:
		var target_r := grip_r.global_position
		if driver_arm_r.global_position.distance_to(target_r) > 0.05:
			driver_arm_r.look_at(target_r, global_basis.y)

	# Gas & Brake foot pedal press animation
	if driver_foot_r:
		driver_foot_r.rotation.x = lerp(driver_foot_r.rotation.x, -current_throttle_input * 0.32, clamp(delta * 12.0, 0.0, 1.0))
	if driver_foot_l:
		driver_foot_l.rotation.x = lerp(driver_foot_l.rotation.x, -current_brake_input * 0.32, clamp(delta * 12.0, 0.0, 1.0))

	# 4. Nitro Flames & Drift Sparks visual effects
	var show_flame := nitro_active or mini_turbo_timer > 0.0
	flame_l.visible = show_flame
	flame_r.visible = show_flame
	if show_flame:
		var pulse := 0.85 + randf() * 0.45
		flame_l.scale = Vector3(1.0, pulse * 1.25, 1.0)
		flame_r.scale = Vector3(1.0, pulse * 1.25, 1.0)

	drift_spark_l.visible = is_drifting
	drift_spark_r.visible = is_drifting
	if is_drifting:
		var spark_col := Color(0.15, 0.72, 1.0) if drift_time >= 2.0 else Color(1.0, 0.75, 0.12)
		(drift_spark_l.material_override as StandardMaterial3D).emission = spark_col
		(drift_spark_r.material_override as StandardMaterial3D).emission = spark_col
		var s := 0.7 + randf() * 0.7
		drift_spark_l.scale = Vector3(s, s, s)
		drift_spark_r.scale = Vector3(s, s, s)

	# 5. Suspension bounce & shockbreaker compression + Exhaust Smoke Puffs!
	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor:
		landing_bounce = 1.0
	was_on_floor = on_floor_now
	landing_bounce = move_toward(landing_bounce, 0.0, delta * 5.0)
	susp_phase += delta * (4.0 + abs(forward_speed) * 0.65)
	var bump_y: float = sin(susp_phase) * 0.018 * clampf(absf(forward_speed) / 18.0, 0.0, 1.0) - landing_bounce * 0.14
	visual_root.position.y = lerp(visual_root.position.y, bump_y, clamp(delta * 16.0, 0.0, 1.0))
	var shock_comp: float = clamp(1.0 + bump_y * 1.4, 0.78, 1.12)
	for sn in shock_nodes:
		if is_instance_valid(sn):
			sn.scale.y = shock_comp

	_update_exhaust_smoke(delta)

	# 6. Dynamic chase camera FOV, smooth swing & action camera shake
	if is_player and follow_camera != null:
		camera_shake = move_toward(camera_shake, 0.0, delta * 2.2)
		var target_fov := 82.0 if show_flame else (74.0 if is_drifting else 68.0)
		follow_camera.fov = lerp(follow_camera.fov, target_fov, clamp(delta * 6.0, 0.0, 1.0))
		var shake_x: float = randf_range(-camera_shake, camera_shake) * 0.45
		var shake_y: float = randf_range(-camera_shake, camera_shake) * 0.35
		follow_camera.position.x = lerp(follow_camera.position.x, -steer_visual * 0.85, clamp(delta * 4.5, 0.0, 1.0)) + shake_x
		follow_camera.position.y = 3.25 + shake_y

	if name_label != null and is_battle_mode:
		name_label.text = "%s [HP:%d]" % [racer_name, int(hp)]


func _compute_ai_controls(delta: float) -> Dictionary:
	ai_item_cooldown = max(0.0, ai_item_cooldown - delta)
	var target_pt := global_position - global_basis.z * 10.0
	var want_use_item := false

	if is_battle_mode:
		var best_target: KartController = null
		var best_d := 99999.0
		for t in battle_targets:
			if t != self and is_instance_valid(t) and t.hp > 0.0:
				var d := global_position.distance_to(t.global_position)
				if d < best_d:
					best_d = d
					best_target = t
		if best_target != null:
			target_pt = best_target.global_position
			if held_item != "" and ai_item_cooldown <= 0.0 and best_d < 28.0:
				want_use_item = true
				ai_item_cooldown = randf_range(2.0, 4.5)
	elif waypoints.size() > 0:
		if using_shortcut and shortcut_waypoints.size() > 0:
			target_pt = shortcut_waypoints[shortcut_sub_idx]
			if global_position.distance_to(target_pt) < 7.5:
				shortcut_sub_idx += 1
				if shortcut_sub_idx >= shortcut_waypoints.size():
					using_shortcut = false
					current_wp = shortcut_exit_wp % waypoints.size()
		else:
			target_pt = waypoints[current_wp]
			var to_next := (waypoints[(current_wp + 1) % waypoints.size()] - target_pt).normalized()
			var side := to_next.cross(Vector3.UP).normalized()
			target_pt += side * ai_lane_offset
			if global_position.distance_to(waypoints[current_wp]) < 11.0:
				if current_wp == shortcut_entry_wp and shortcut_waypoints.size() > 0 and randf() < shortcut_chance:
					using_shortcut = true
					shortcut_sub_idx = 0
				else:
					var prev_wp := current_wp
					current_wp = (current_wp + 1) % waypoints.size()
					if prev_wp == waypoints.size() - 1 and current_wp == 0:
						current_lap += 1
		if held_item != "" and ai_item_cooldown <= 0.0 and randf() < aggression * 0.08:
			want_use_item = true
			ai_item_cooldown = randf_range(2.5, 6.0)

	var to_target := target_pt - global_position
	to_target.y = 0.0
	var desired_dir := to_target.normalized() if to_target.length() > 0.1 else -global_basis.z
	var fwd := -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(desired_dir, Vector3.UP)
	var steer_val: float = clamp(angle * 1.9, -1.0, 1.0)
	var drift_val: bool = abs(angle) > 0.52 and forward_speed > 16.0 and (personality == "drifter" or personality == "aggressive" or abs(angle) > 0.78)
	var nitro_val: bool = nitro_energy > (45.0 if personality == "speedster" else 65.0) and abs(angle) < 0.35

	return {
		"throttle": 1.0 if abs(angle) < 1.25 else 0.65,
		"steer": steer_val,
		"drift": drift_val,
		"nitro": nitro_val,
		"use_item": want_use_item
	}


func _update_progress() -> void:
	if is_battle_mode or waypoints.size() == 0:
		return
	if is_player:
		# Smooth progression + cutting across park/sidewalks without breaking lap progress!
		var n_wp := waypoints.size()
		var max_lookahead := mini(6, n_wp - 1)
		for step_i in range(max_lookahead):
			var idx := (current_wp + step_i) % n_wp
			if global_position.distance_to(waypoints[idx]) < 24.0:
				var next_idx := (idx + 1) % n_wp
				if idx == n_wp - 1 or (current_wp > n_wp - 6 and next_idx < 3):
					current_lap += 1
				current_wp = next_idx
				break
	var dist_to_wp := global_position.distance_to(waypoints[current_wp])
	total_progress = float(current_lap) * 100000.0 + float(current_wp) * 200.0 - dist_to_wp


func apply_speedbump_hop(strength: float = 4.6) -> void:
	if is_on_floor() and absf(forward_speed) > 6.5:
		velocity.y = maxf(velocity.y, clampf(absf(forward_speed) * 0.16, 2.8, strength))
		landing_bounce = 0.65
		if is_player:
			add_camera_shake(0.18)


func give_powerup(item_type: String) -> void:
	if held_item == "":
		held_item = item_type
		if is_player:
			ComedySfx.play(self, "pickup", -5.0)


func add_camera_shake(amount: float) -> void:
	camera_shake = minf(1.0, camera_shake + amount)


func apply_spinout(duration: float = 1.25) -> void:
	if shield_timer > 0.0:
		shield_timer = 0.0
		shield_mesh.visible = false
		return
	spinout_timer = max(spinout_timer, duration)
	forward_speed *= 0.45


func apply_knockback_flip(impulse: Vector3, attacker: KartController = null) -> void:
	if shield_timer > 0.0:
		shield_timer = 0.0
		shield_mesh.visible = false
		return
	velocity += impulse
	velocity.y = max(velocity.y, 9.5)
	flip_timer = 1.15
	flip_axis = Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized()
	forward_speed *= 0.3
	if is_battle_mode:
		take_battle_damage(34.0, attacker)


func apply_oil_slip(duration: float = 2.0) -> void:
	if shield_timer > 0.0:
		return
	oil_slip_timer = max(oil_slip_timer, duration)


func activate_shield(duration: float = 6.5) -> void:
	shield_timer = duration
	shield_mesh.visible = true


func take_battle_damage(amount: float, attacker: KartController = null) -> void:
	if not is_battle_mode or hp <= 0.0:
		return
	hp = max(0.0, hp - amount)
	if attacker != null and attacker != self:
		last_attacker = attacker
	if hp <= 0.0:
		emit_signal("kart_eliminated", self, last_attacker)


func _update_exhaust_smoke(delta: float) -> void:
	# Budgeted exhaust puffs for stable 60 FPS across all 8 karts on mid-range PCs
	var max_puffs := 14 if is_player else 6
	var emit_interval := (0.05 if nitro_active else (0.09 if current_throttle_input > 0.1 else 0.22)) if is_player else 0.22
	exhaust_smoke_timer += delta
	if exhaust_smoke_timer >= emit_interval and smoke_puffs.size() < max_puffs and get_parent() != null:
		exhaust_smoke_timer = 0.0
		var shared_mesh := _get_smoke_mesh()
		var sides: Array = [-0.28, 0.28] if is_player else [(-0.28 if (randi() % 2 == 0) else 0.28)]
		for sx_val in sides:
			var sx: float = float(sx_val)
			var mi := MeshInstance3D.new()
			mi.mesh = shared_mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var smat := StandardMaterial3D.new()
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			if nitro_active:
				smat.albedo_color = Color(0.95, 0.68, 0.35, 0.58)
				smat.emission_enabled = true
				smat.emission = Color(1.0, 0.45, 0.08)
				smat.emission_energy_multiplier = 0.9
			else:
				var g := randf_range(0.68, 0.85)
				smat.albedo_color = Color(g, g, g, 0.48)
			smat.roughness = 0.95
			mi.material_override = smat
			# Local exhaust tip in Godot (+Z is rear)
			var spawn_pos := to_global(Vector3(sx, 0.60, 1.24))
			mi.position = spawn_pos
			get_parent().add_child(mi)
			var back_dir := global_basis.z
			var drift_vel: Vector3 = back_dir * (2.6 + absf(forward_speed) * 0.12) + Vector3(randf_range(-0.45, 0.45), randf_range(1.1, 2.0), randf_range(-0.45, 0.45))
			smoke_puffs.append({
				"node": mi,
				"mat": smat,
				"vel": drift_vel,
				"age": 0.0,
				"life": randf_range(0.55, 0.95)
			})

	var expired: Array = []
	for p in smoke_puffs:
		p["age"] = float(p["age"]) + delta
		var node: MeshInstance3D = p["node"]
		if not is_instance_valid(node) or float(p["age"]) >= float(p["life"]):
			if is_instance_valid(node):
				node.queue_free()
			expired.append(p)
			continue
		var t: float = float(p["age"]) / float(p["life"])
		node.position += (p["vel"] as Vector3) * delta
		var sc: float = 1.0 + t * 2.4
		node.scale = Vector3(sc, sc, sc)
		var mat: StandardMaterial3D = p["mat"]
		var c := mat.albedo_color
		c.a = (1.0 - t) * 0.48
		mat.albedo_color = c
	for e in expired:
		smoke_puffs.erase(e)
