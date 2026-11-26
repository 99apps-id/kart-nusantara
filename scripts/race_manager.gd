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
var circuit_data: Dictionary = {}
var track_waypoints: Array[Vector3] = []
var shortcut_waypoints: Array[Vector3] = []

var race_time: float = 0.0
var countdown_timer: float = 3.2
var last_countdown_num: int = 4
var race_started: bool = false
var race_finished: bool = false
var chaos_score: int = 0
var alert_timer: float = 0.0

# HUD elements
var hud_pos_label: Label
var hud_lap_label: Label
var hud_speed_label: Label
var hud_item_label: Label
var hud_chaos_label: Label
var hud_light_label: Label
var hud_fps_label: Label
var hud_nitro_bar: ProgressBar
var hud_alert_label: Label
var hud_center_label: Label
var replay_panel: PanelContainer


func _ready() -> void:
	world_builder = WORLD_BUILDER_SCRIPT.new()
	add_child(world_builder)
	world_builder.setup_tropical_lighting(self)
	world_builder.red_light_violated.connect(_on_red_light_violated)
	world_builder.prop_smashed.connect(_on_prop_smashed)

	_build_nusantara_circuit()
	_spawn_8_karts()

	replay_cam = Camera3D.new()
	replay_cam.fov = 62.0
	replay_cam.position = Vector3(14.0, 6.0, 18.0)
	add_child(replay_cam)

	replay_sys = REPLAY_SCRIPT.new()
	add_child(replay_sys)
	replay_sys.setup(karts, replay_cam, [
		Vector3(16.0, 6.5, 18.0),
		Vector3(18.0, 7.5, -72.0),
		Vector3(-56.0, 14.0, -10.0),
		Vector3(-126.0, 7.5, -72.0),
		Vector3(-135.0, 7.0, 35.0),
		Vector3(-25.0, 7.5, 118.0)
	])

	_build_hud()
	add_child(TouchControlsOverlay.new())


func _build_nusantara_circuit() -> void:
	# Balanced neutral surface tints so road/sidewalk/grass stay bright, readable, and never oversaturated
	var mat_grass := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_GRASS_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_GRASS_N), Vector3(0.06, 0.06, 0.06), 0.94, Color(0.76, 0.85, 0.72), null, 1.5, true)
	# Road/sidewalk/curb use spline UV (use_triplanar = false) so markings & paving stones curve smoothly with the racing line!
	var mat_asphalt := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_N), Vector3(1.0, 1.0, 1.0), 0.96, Color(0.74, 0.77, 0.84), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_ASPHALT_R), 2.2, false)
	var mat_sidewalk := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_N), Vector3(1.0, 1.0, 1.0), 0.96, Color(0.83, 0.85, 0.89), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_R), 2.1, false)
	var mat_curb := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_CURB_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_CURB_N), Vector3(1.0, 1.0, 1.0), 0.72, Color(0.84, 0.86, 0.90), null, 1.8, false)
	var mat_shortcut := world_builder.make_pbr_mat(ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_A), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_N), Vector3(1.0, 1.0, 1.0), 0.90, Color(0.84, 0.82, 0.78), ChaosWorldBuilder.get_tex(ChaosWorldBuilder.PT_SIDEWALK_R), 1.9, false)

	# Expansive tropical grass & open city park ground (Y = 0.0, completely drivable everywhere!)
	world_builder.add_ground_slab(self, Vector3(-50.0, -0.5, 0.0), Vector3(440.0, 1.0, 440.0), mat_grass)

	# 703m Winding GP-Style Nusantara Racing Circuit (Catmull-Rom closed spline, min turn radius 21.9m — zero sharp square corners!)
	var ctrl_pts: Array[Vector3] = [
		Vector3(0.0, 0.0, 36.0),
		Vector3(0.0, 0.0, -14.0),
		Vector3(0.0, 0.0, -64.0),
		Vector3(-24.0, 0.0, -110.0),
		Vector3(-76.0, 0.0, -124.0),
		Vector3(-128.0, 0.0, -96.0),
		Vector3(-118.0, 0.0, -40.0),
		Vector3(-148.0, 0.0, 18.0),
		Vector3(-134.0, 0.0, 82.0),
		Vector3(-82.0, 0.0, 122.0),
		Vector3(-14.0, 0.0, 124.0),
		Vector3(30.0, 0.0, 100.0),
		Vector3(16.0, 0.0, 68.0)
	]
	circuit_data = world_builder.build_curved_road(self, ctrl_pts, 16.0, mat_asphalt, {
		"curb": mat_curb,
		"sidewalk": mat_sidewalk,
		"ramp": mat_grass,
		"sidewalks": true
	}, 10)
	var samples: Array = circuit_data["samples"]
	var tangents: Array = circuit_data["tangents"]
	var rights: Array = circuit_data["rights"]
	var n_samp: int = samples.size()

	# Build 26 smooth main racing waypoints starting right ahead of Start/Finish (idx 12 -> wrap around -> idx 7)
	track_waypoints.clear()
	for k in range(26):
		var s_idx := (12 + k * 5) % n_samp
		var sp: Vector3 = samples[s_idx]
		track_waypoints.append(Vector3(sp.x, 0.5, sp.z))

	# DRIVABLE CURVED TUNNEL ("TEROWONGAN NUSANTARA") spanning winding west bend idx 56..68 (~65m long)
	var tunnel_start := 56
	var tunnel_end := 68
	world_builder.build_curved_tunnel(self, circuit_data, tunnel_start, tunnel_end, 9.5, 2.6, 5.2, 1.4)

	# CURVED PARK SHORTCUT: Open scenic park lane cutting across Taman Kota from north-east (-16, -96) to south-west (-124, 74)!
	var sc_ctrl: Array[Vector3] = [
		Vector3(-16.0, 0.0, -96.0),
		Vector3(-42.0, 0.0, -54.0),
		Vector3(-68.0, 0.0, -4.0),
		Vector3(-92.0, 0.0, 42.0),
		Vector3(-124.0, 0.0, 74.0)
	]
	var sc_data := world_builder.build_open_curved_road(self, sc_ctrl, 8.6, mat_shortcut, {
		"curb": mat_curb,
		"sidewalks": false
	}, 8)
	var sc_samps: Array = sc_data["samples"]
	shortcut_waypoints.clear()
	for s_i in [5, 11, 17, 23, 28]:
		if s_i < sc_samps.size():
			var p: Vector3 = sc_samps[s_i]
			shortcut_waypoints.append(Vector3(p.x, 0.5, p.z))

	# Park Shortcut jump ramp in the middle of Taman Kota
	world_builder.add_ground_slab(self, Vector3(-68.0, 0.42, -4.0), Vector3(7.6, 0.24, 6.2), mat_shortcut, deg_to_rad(28.0), deg_to_rad(13.0))
	var sc_sign := Label3D.new()
	sc_sign.text = ">>> SHORTCUT TAMAN KOTA >>>"
	sc_sign.font_size = 64
	sc_sign.modulate = Color(1.0, 0.90, 0.16)
	sc_sign.outline_size = 12
	sc_sign.position = Vector3(-24.0, 3.8, -92.0)
	sc_sign.rotation_degrees = Vector3(0.0, 145.0, 0.0)
	add_child(sc_sign)

	# Far Outer World Safety Perimeter (leaves all sidewalks, buildings & central park 100% open and drivable!)
	var mat_wall := StandardMaterial3D.new()
	mat_wall.albedo_color = Color(0.85, 0.22, 0.18, 0.08)
	mat_wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	world_builder.add_ground_slab(self, Vector3(135.0, 2.5, 0.0), Vector3(2.0, 6.0, 390.0), mat_wall)
	world_builder.add_ground_slab(self, Vector3(-235.0, 2.5, 0.0), Vector3(2.0, 6.0, 390.0), mat_wall)
	world_builder.add_ground_slab(self, Vector3(-50.0, 2.5, -195.0), Vector3(375.0, 6.0, 2.0), mat_wall)
	world_builder.add_ground_slab(self, Vector3(-50.0, 2.5, 195.0), Vector3(375.0, 6.0, 2.0), mat_wall)

	# Start/Finish Gapura RT Merah-Putih (at Z = 0, facing -Z) + second Gapura at Kampung curve (idx 96)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAPURA, Vector3(0.0, 0.0, 0.0), 0.0)
	var g2_p: Vector3 = samples[96]
	var g2_t: Vector3 = tangents[96]
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAPURA, g2_p, rad_to_deg(atan2(g2_t.x, g2_t.z)))

	# Roadside buildings facing inward toward the track (never blocking tunnel or central park!)
	var roadside_buildings := [
		# East Commercial Boulevard (Start/Finish)
		[10, 1.0, 17.5, ChaosWorldBuilder.P_INDOMARET, Vector3(6.2, 6.0, 5.2)],
		[15, 1.0, 17.5, ChaosWorldBuilder.P_ALFAMART, Vector3(6.2, 6.0, 5.2)],
		[20, 1.0, 16.0, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)],
		[24, 1.0, 19.5, ChaosWorldBuilder.P_GEDUNG_KANTOR, Vector3(8.0, 12.0, 7.0)],
		[5, 1.0, 18.0, ChaosWorldBuilder.P_RUKO_KAFE, Vector3(6.4, 5.5, 5.2)],
		[118, 1.0, 18.5, ChaosWorldBuilder.P_GEDUNG_KANTOR, Vector3(8.0, 12.0, 7.0)],
		[124, 1.0, 17.5, ChaosWorldBuilder.P_RUKO_KAFE, Vector3(6.4, 5.5, 5.2)],
		# North Business & Market Curve
		[32, 1.0, 18.5, ChaosWorldBuilder.P_GEDUNG_KANTOR, Vector3(8.0, 12.0, 7.0)],
		[38, 1.0, 17.0, ChaosWorldBuilder.P_INDOMARET, Vector3(6.2, 6.0, 5.2)],
		[44, 1.0, 17.0, ChaosWorldBuilder.P_ALFAMART, Vector3(6.2, 6.0, 5.2)],
		[49, 1.0, 16.0, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)],
		# West & South-West Kampung Nusantara (after tunnel exit idx 68)
		[73, 1.0, 17.5, ChaosWorldBuilder.P_RUMAH, Vector3(6.2, 4.8, 5.2)],
		[79, 1.0, 17.5, ChaosWorldBuilder.P_RUKO_KAFE, Vector3(6.4, 5.5, 5.2)],
		[85, 1.0, 16.0, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)],
		[91, 1.0, 17.5, ChaosWorldBuilder.P_RUMAH, Vector3(6.2, 4.8, 5.2)],
		[98, 1.0, 17.5, ChaosWorldBuilder.P_INDOMARET, Vector3(6.2, 6.0, 5.2)],
		[104, 1.0, 17.5, ChaosWorldBuilder.P_RUMAH, Vector3(6.2, 4.8, 5.2)],
		[110, 1.0, 17.5, ChaosWorldBuilder.P_ALFAMART, Vector3(6.2, 6.0, 5.2)],
		[114, 1.0, 16.0, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)],
		# Inner corner accent stalls (plenty of clearance so park stays open!)
		[13, -1.0, 16.5, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)],
		[42, -1.0, 17.5, ChaosWorldBuilder.P_RUKO_KAFE, Vector3(6.4, 5.5, 5.2)],
		[102, -1.0, 17.0, ChaosWorldBuilder.P_KIOS_BUAH, Vector3(4.2, 2.8, 2.6)]
	]
	for b in roadside_buildings:
		var bi: int = int(b[0]) % n_samp
		var side: float = float(b[1])
		var dist: float = float(b[2])
		var p: Vector3 = samples[bi] + rights[bi] * (side * dist)
		var inward: Vector3 = -rights[bi] * side
		var yaw_deg := rad_to_deg(atan2(inward.x, inward.z))
		world_builder.spawn_static_model(self, String(b[3]), Vector3(p.x, 0.08, p.z), yaw_deg, b[4])

	# CENTRAL TAMAN KOTA NUSANTARA (completely open & drivable! Gazebo, flower beds, bougainvillea bushes & tropical trees)
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAZEBO, Vector3(-42.0, 0.0, 12.0), 25.0, Vector3(4.2, 3.6, 4.2))
	world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GAZEBO, Vector3(-86.0, 0.0, -48.0), -30.0, Vector3(4.2, 3.6, 4.2))
	for fb_pos in [
		Vector3(-34.0, 0.0, -14.0), Vector3(-52.0, 0.0, 26.0), Vector3(-76.0, 0.0, -28.0),
		Vector3(-56.0, 0.0, -72.0), Vector3(-92.0, 0.0, 16.0), Vector3(-28.0, 0.0, 56.0),
		Vector3(-62.0, 0.0, 74.0)
	]:
		world_builder.spawn_static_model(self, ChaosWorldBuilder.P_FLOWER_BED, fb_pos, randf() * 360.0)
	for bush_pos in [
		Vector3(-26.0, 0.0, 4.0), Vector3(-48.0, 0.0, -24.0), Vector3(-60.0, 0.0, 14.0),
		Vector3(-78.0, 0.0, -64.0), Vector3(-96.0, 0.0, -16.0), Vector3(-42.0, 0.0, 48.0),
		Vector3(-74.0, 0.0, 52.0), Vector3(-34.0, 0.0, -68.0), Vector3(-18.0, 0.0, 32.0),
		Vector3(-104.0, 0.0, 28.0)
	]:
		world_builder.spawn_static_model(self, ChaosWorldBuilder.P_BUSH, bush_pos, randf() * 360.0)
	for park_tree in [
		Vector3(-28.0, 0.0, -34.0), Vector3(-58.0, 0.0, -48.0), Vector3(-82.0, 0.0, 2.0),
		Vector3(-36.0, 0.0, 36.0), Vector3(-68.0, 0.0, 86.0), Vector3(-98.0, 0.0, -62.0)
	]:
		world_builder.spawn_static_model(self, ChaosWorldBuilder.P_TREE, park_tree, randf() * 360.0, Vector3(0.75, 4.0, 0.75))

	# Roadside Palms, Street Trees, Vintage Lamps, Benches, Bushes & Outer Guardrails (skip tunnel idx 54..70 & park openings!)
	for i in range(0, n_samp, 5):
		if i >= tunnel_start - 2 and i <= tunnel_end + 2:
			continue
		var c: Vector3 = samples[i]
		var r: Vector3 = rights[i]
		var t: Vector3 = tangents[i]
		var road_yaw := rad_to_deg(atan2(t.x, t.z))

		# Outer sidewalk palm / tree alternating
		var p_out := c + r * 11.4
		if i % 10 == 0:
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_PALM, Vector3(p_out.x, 0.14, p_out.z), float(i) * 19.0, Vector3(0.85, 6.0, 0.85))
		else:
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_TREE, Vector3(p_out.x, 0.14, p_out.z), float(i) * 29.0, Vector3(0.75, 4.0, 0.75))

		# Vintage lamp & decorative bush on outer sidewalk
		var lamp_p := c + r * 10.6 + t * 2.2
		world_builder.spawn_static_model(self, ChaosWorldBuilder.P_VINTAGE_LAMP, Vector3(lamp_p.x, 0.14, lamp_p.z), road_yaw - 90.0)
		if i % 15 == 5:
			var bench_p := c + r * 11.5 - t * 2.4
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_BENCH, Vector3(bench_p.x, 0.14, bench_p.z), road_yaw - 90.0)
		if i % 10 == 5:
			var b_out := c + r * 12.6
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_BUSH, Vector3(b_out.x, 0.10, b_out.z), float(i) * 37.0)

		# Outer apex tire stacks & guardrails ONLY on outer side of sharp sweeping curves (inner side stays open for park shortcuts!)
		if i in [25, 35, 45, 75, 85, 95, 105, 115]:
			var ts_p := c + r * 9.6
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_TIRE_STACK, Vector3(ts_p.x, 0.14, ts_p.z), road_yaw, Vector3(0.95, 0.85, 1.8))
		if i in [30, 40, 80, 90, 110]:
			var gr_p := c + r * 9.0
			world_builder.spawn_static_model(self, ChaosWorldBuilder.P_GUARDRAIL, Vector3(gr_p.x, 0.14, gr_p.z), road_yaw)

		# Overhead sagging power cables on straighter city segments
		if i in [10, 20, 35, 80, 100]:
			world_builder.spawn_overhead_cables(self, c - r * 11.5 + Vector3(0, 7.8, 0), c + r * 11.5 + t * 3.5 + Vector3(0, 7.8, 0), 1.35)

	# 4 Speedbumps (Polisi Tidur) placed cleanly across the curved road!
	for sb_idx in [17, 46, 84, 117]:
		var sbp: Vector3 = samples[sb_idx]
		var sbt: Vector3 = tangents[sb_idx]
		world_builder.spawn_speedbump(self, Vector3(sbp.x, 0.06, sbp.z), rad_to_deg(atan2(sbt.x, sbt.z)), 1.65)

	# 2 Working Traffic Lights (Lampu Merah-Kuning-Hijau yang bisa diterobos!)
	for tl_idx in [21, 93]:
		var tlp: Vector3 = samples[tl_idx]
		var tlr: Vector3 = rights[tl_idx]
		var tlt: Vector3 = tangents[tl_idx]
		var tl_pos := tlp + tlr * 9.4
		world_builder.spawn_traffic_light(self, Vector3(tl_pos.x, 0.14, tl_pos.z), rad_to_deg(atan2(tlt.x, tlt.z)), Vector3(tlp.x, 0.5, tlp.z))

	# Destructible Objects along the 703m curved circuit: Traffic Cones, Parked Motorcycles & Bicycles, Gerobak Bakso, Kardus, Pot, Tiang, Tong, Pagar Kayu!
	for cone_idx in [14, 28, 52, 71, 88, 108, 122]:
		var cp: Vector3 = samples[cone_idx]
		var cr: Vector3 = rights[cone_idx]
		var ct: Vector3 = tangents[cone_idx]
		for k in range(3):
			var cpos := cp + cr * (5.6 - float(k) * 0.8) + ct * (float(k) * 1.4)
			world_builder.spawn_destructible(self, "cone", Vector3(cpos.x, 0.10, cpos.z))

	# Parked Motorcycles & Bicycles along shopfronts (detailed frames & wheels, smashable!)
	for m_idx in [11, 16, 39, 78, 99, 111]:
		var mp: Vector3 = samples[m_idx] + rights[m_idx] * 9.8
		var mt: Vector3 = tangents[m_idx]
		world_builder.spawn_destructible(self, "motorcycle", Vector3(mp.x, 0.16, mp.z), rad_to_deg(atan2(mt.x, mt.z)) + 25.0)
	for bk_idx in [19, 43, 74, 92, 105, 123]:
		var bp: Vector3 = samples[bk_idx] + rights[bk_idx] * 9.6
		var bt: Vector3 = tangents[bk_idx]
		world_builder.spawn_destructible(self, "bicycle", Vector3(bp.x, 0.16, bp.z), rad_to_deg(atan2(bt.x, bt.z)) - 20.0)

	# Street Poles & Flower Pots
	for pi in [8, 22, 37, 76, 97, 116]:
		var pp: Vector3 = samples[pi] + rights[pi] * 8.9
		world_builder.spawn_destructible(self, "pole", Vector3(pp.x, 0.15, pp.z))
	for poti in [12, 18, 33, 45, 72, 86, 101, 119]:
		var potp: Vector3 = samples[poti] + rights[poti] * 9.1
		world_builder.spawn_destructible(self, "pot", Vector3(potp.x, 0.15, potp.z))

	# Cardboard stacks, Wood Fences, Gerobak Bakso & Barrels
	for ci in [13, 36, 51, 77, 103]:
		var cp: Vector3 = samples[ci] + rights[ci] * 5.2
		world_builder.spawn_destructible(self, "cardboard", Vector3(cp.x, 0.10, cp.z), randf() * 90.0)
		world_builder.spawn_destructible(self, "cardboard", Vector3(cp.x + 0.9, 0.10, cp.z + 0.4), randf() * 90.0)
		world_builder.spawn_destructible(self, "cardboard", Vector3(cp.x + 0.45, 0.98, cp.z + 0.2), randf() * 90.0)
	for fi in [27, 70, 94]:
		var fp: Vector3 = samples[fi] - rights[fi] * 5.5
		world_builder.spawn_destructible(self, "fence", Vector3(fp.x, 0.10, fp.z), randf() * 90.0)
	for gi in [20, 48, 85, 114]:
		var gp: Vector3 = samples[gi] + rights[gi] * 6.4
		var gt: Vector3 = tangents[gi]
		world_builder.spawn_destructible(self, "gerobak", Vector3(gp.x, 0.10, gp.z), rad_to_deg(atan2(gt.x, gt.z)))
	for bri in [31, 53, 75, 107, 121]:
		var brp: Vector3 = samples[bri] - rights[bri] * 5.8
		world_builder.spawn_destructible(self, "barrel", Vector3(brp.x, 0.10, brp.z))

	# Dynamic Obstacles: Ayam menyeberang, Angkot Suzuki Carry 99 melaju, Penghalang bergerak!
	for ch_idx in [16, 44, 83, 112]:
		var cp: Vector3 = samples[ch_idx]
		var cr: Vector3 = rights[ch_idx]
		world_builder.spawn_dynamic_obstacle(self, "chicken", cp - cr * 7.5 + Vector3(0, 0.08, 0), cp + cr * 7.5 + Vector3(0, 0.08, 0), 6.8)
	world_builder.spawn_dynamic_obstacle(self, "angkot", samples[10] - rights[10] * 3.8 + Vector3(0, 0.08, 0), samples[22] - rights[22] * 3.8 + Vector3(0, 0.08, 0), 11.5)
	world_builder.spawn_dynamic_obstacle(self, "angkot", samples[74] - rights[74] * 3.8 + Vector3(0, 0.08, 0), samples[88] - rights[88] * 3.8 + Vector3(0, 0.08, 0), 12.0)
	for br_idx in [34, 102]:
		var bp: Vector3 = samples[br_idx]
		var br: Vector3 = rights[br_idx]
		world_builder.spawn_dynamic_obstacle(self, "barrier", bp - br * 5.5 + Vector3(0, 0.08, 0), bp + br * 5.5 + Vector3(0, 0.08, 0), 5.2)

	# Orang-orang berlari menghindar (Mix of Male & Female Pedestrians!)
	var ped_colors := [Color(0.92, 0.25, 0.30), Color(0.15, 0.65, 0.40), Color(0.22, 0.48, 0.92), Color(0.95, 0.72, 0.14), Color(0.84, 0.28, 0.68), Color(0.95, 0.45, 0.18)]
	var ped_indices := [11, 15, 20, 32, 41, 49, 73, 81, 91, 100, 111, 120]
	for i in range(ped_indices.size()):
		var pi: int = ped_indices[i]
		var side := 1.0 if (i % 3 != 2) else -1.0
		var home: Vector3 = samples[pi] + rights[pi] * (side * 9.0) + Vector3(0, 0.16, 0)
		var safe_dir: Vector3 = rights[pi] * side
		var is_female: bool = (i % 2 == 1)
		world_builder.spawn_pedestrian(self, home, safe_dir, ped_colors[i % ped_colors.size()], is_female)

	# Power-up Item Boxes (Rows along the 703m curved track, inside Tunnel & inside Park Shortcut!)
	for row_idx in [14, 38, 62, 86, 110]:
		var rp: Vector3 = samples[row_idx]
		var rr: Vector3 = rights[row_idx]
		for off in [-4.0, 0.0, 4.0]:
			var ip := rp + rr * float(off)
			world_builder.spawn_item_box(self, Vector3(ip.x, 0.10, ip.z))
	# Bonus item boxes inside Park Shortcut!
	world_builder.spawn_item_box(self, Vector3(-56.0, 0.10, -24.0))
	world_builder.spawn_item_box(self, Vector3(-82.0, 0.10, 20.0))


func _spawn_8_karts() -> void:
	var main_wps: Array[Vector3] = track_waypoints
	var sc_wps: Array[Vector3] = shortcut_waypoints

	# Grid positions (2 columns x 4 rows behind start line at Z=0, facing -Z along straight start boulevard)
	var grid_positions: Array[Vector3] = [
		Vector3(-2.6, 0.3, 4.5), Vector3(2.6, 0.3, 4.5),
		Vector3(-2.6, 0.3, 8.8), Vector3(2.6, 0.3, 8.8),
		Vector3(-2.6, 0.3, 13.1), Vector3(2.6, 0.3, 13.1),
		Vector3(-2.6, 0.3, 17.4), Vector3(2.6, 0.3, 17.4)
	]

	# Slot 0 = Player (from Garage config)
	player_kart = KART_SCRIPT.new()
	player_kart.setup_kart(GameConfig.get_player_kart_config(), true, false)
	player_kart.position = grid_positions[0]
	player_kart.waypoints = main_wps
	player_kart.shortcut_waypoints = sc_wps
	player_kart.shortcut_entry_wp = 4
	player_kart.shortcut_exit_wp = 18
	player_kart.controls_locked = true
	player_kart.powerup_used.connect(_on_kart_powerup_used)
	add_child(player_kart)
	karts.append(player_kart)

	# Slots 1..7 = 7 Distinct AI Opponents
	for i in range(7):
		var ai_def: Dictionary = GameConfig.AI_ROSTER[i]
		var ai_cfg := {
			"name": ai_def["name"],
			"personality": ai_def["personality"],
			"aggression": ai_def["aggression"],
			"shortcut_chance": ai_def["shortcut_chance"],
			"body_color": ai_def["color"],
			"spoiler_idx": i % 3,
			"wheel_scale": 1.0 + float(i % 2) * 0.1,
			"max_speed": 30.2 * float(ai_def["speed_mult"]),
			"accel": 21.5,
			"handling": 2.95,
			"drift_charge_rate": 42.0,
			"mass": 1.35 if ai_def["personality"] == "rammer" else 1.0,
			"nitro_power": 13.0
		}
		var ai_kart: KartController = KART_SCRIPT.new()
		ai_kart.setup_kart(ai_cfg, false, false)
		ai_kart.position = grid_positions[i + 1]
		ai_kart.waypoints = main_wps
		ai_kart.shortcut_waypoints = sc_wps
		ai_kart.shortcut_entry_wp = 4
		ai_kart.shortcut_exit_wp = 18
		ai_kart.controls_locked = true
		ai_kart.powerup_used.connect(_on_kart_powerup_used)
		add_child(ai_kart)
		karts.append(ai_kart)

	world_builder.active_karts = karts
	if player_kart.follow_camera:
		player_kart.follow_camera.current = true


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(20, 14)
	top_bar.add_theme_constant_override("separation", 24)
	cl.add_child(top_bar)

	hud_pos_label = _make_hud_pill(top_bar, "POSISI: 1 / 8", Color(1.0, 0.85, 0.18))
	hud_lap_label = _make_hud_pill(top_bar, "LAP: 1 / %d" % GameConfig.laps_count, Color(1.0, 1.0, 1.0))
	hud_item_label = _make_hud_pill(top_bar, "ITEM [E]: KOSONG", Color(0.45, 0.92, 1.0))
	hud_chaos_label = _make_hud_pill(top_bar, "CHAOS: 0", Color(1.0, 0.55, 0.2))
	hud_light_label = _make_hud_pill(top_bar, "LAMPU: MERAH", Color(1.0, 0.25, 0.2))
	hud_fps_label = _make_hud_pill(top_bar, "60 FPS", Color(0.55, 1.0, 0.55))

	# Bottom-right Speed + Nitro gauge
	var gauge_box := VBoxContainer.new()
	gauge_box.anchor_left = 1.0; gauge_box.anchor_right = 1.0
	gauge_box.anchor_top = 1.0; gauge_box.anchor_bottom = 1.0
	gauge_box.offset_left = -280; gauge_box.offset_right = -24
	gauge_box.offset_top = -125; gauge_box.offset_bottom = -20
	cl.add_child(gauge_box)

	hud_speed_label = Label.new()
	hud_speed_label.text = "0 km/h"
	hud_speed_label.add_theme_font_size_override("font_size", 32)
	hud_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gauge_box.add_child(hud_speed_label)

	var n_lbl := Label.new()
	n_lbl.text = "NITRO [Q] (Drift [Space] untuk isi)"
	n_lbl.add_theme_font_size_override("font_size", 14)
	gauge_box.add_child(n_lbl)

	hud_nitro_bar = ProgressBar.new()
	hud_nitro_bar.min_value = 0; hud_nitro_bar.max_value = 100; hud_nitro_bar.value = 35
	hud_nitro_bar.custom_minimum_size = Vector2(240, 24)
	gauge_box.add_child(hud_nitro_bar)

	# Controls hint bottom-left
	var hint := Label.new()
	hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
	hint.offset_left = 20; hint.offset_top = -40
	hint.text = "WASD/Panah: Setir | SPACE: Drift+Hop | Q: Nitro | E: Power-Up | H: Klakson | T: Telolet | R: Reset | V: Replay | ESC: Garage"
	hint.add_theme_font_size_override("font_size", 14)
	cl.add_child(hint)

	# Alert feed & center countdown banner
	hud_alert_label = Label.new()
	hud_alert_label.anchor_left = 0.5; hud_alert_label.anchor_right = 0.5
	hud_alert_label.offset_left = -300; hud_alert_label.offset_right = 300; hud_alert_label.offset_top = 72
	hud_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_alert_label.add_theme_font_size_override("font_size", 24)
	hud_alert_label.modulate = Color(1.0, 0.86, 0.2)
	cl.add_child(hud_alert_label)

	hud_center_label = Label.new()
	hud_center_label.anchor_left = 0.5; hud_center_label.anchor_right = 0.5
	hud_center_label.anchor_top = 0.35; hud_center_label.anchor_bottom = 0.35
	hud_center_label.offset_left = -340; hud_center_label.offset_right = 340
	hud_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_center_label.add_theme_font_size_override("font_size", 54)
	hud_center_label.modulate = Color(1.0, 0.92, 0.22)
	cl.add_child(hud_center_label)

	# Post-race Replay Camera Control Panel
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
	var b_cam := Button.new(); b_cam.text = "Ganti Sudut Replay"
	b_cam.pressed.connect(func(): replay_sys.cycle_camera_angle())
	rbox.add_child(b_cam)
	var b_again := Button.new(); b_again.text = "Balap Lagi"
	b_again.pressed.connect(func(): get_tree().reload_current_scene())
	rbox.add_child(b_again)
	var b_gar := Button.new(); b_gar.text = "Kembali ke Garage"
	b_gar.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	rbox.add_child(b_gar)


func _make_hud_pill(parent: Control, text: String, col: Color) -> Label:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var lbl := Label.new()
	lbl.text = " " + text + " "
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", 18)
	panel.add_child(lbl)
	return lbl


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if Input.is_key_pressed(KEY_V) and race_started and not replay_sys.is_playing:
		_enter_replay_camera("REPLAY KAMERA SINEMATIK")
		return

	if replay_sys.is_playing:
		replay_sys.tick(delta)
		return

	if not race_started:
		countdown_timer -= delta
		if countdown_timer > 0.2:
			var cur_num: int = int(ceil(countdown_timer))
			hud_center_label.text = str(cur_num)
			if cur_num < last_countdown_num and cur_num >= 1:
				last_countdown_num = cur_num
				ComedySfx.play(self, "countdown_beep", -4.5)
		else:
			race_started = true
			hud_center_label.text = "GAS POL!"
			ComedySfx.play(self, "race_go", -3.5)
			alert_timer = 1.3
			for k in karts:
				k.controls_locked = false
		return

	race_time += delta
	if alert_timer > 0.0:
		alert_timer -= delta
		if alert_timer <= 0.0:
			hud_alert_label.text = ""
			if not race_finished:
				hud_center_label.text = ""

	if Input.is_action_just_pressed("reset_kart"):
		var wp: Vector3 = player_kart.waypoints[player_kart.current_wp]
		var next_wp: Vector3 = player_kart.waypoints[(player_kart.current_wp + 1) % player_kart.waypoints.size()]
		player_kart.global_position = wp + Vector3(0.0, 1.0, 0.0)
		player_kart.look_at(Vector3(next_wp.x, player_kart.global_position.y, next_wp.z), Vector3.UP)
		player_kart.velocity = Vector3.ZERO
		player_kart.forward_speed = 0.0

	world_builder.tick_world(self, delta)
	replay_sys.tick(delta)

	# Compute rankings across all 8 karts
	var sorted_karts := karts.duplicate()
	sorted_karts.sort_custom(func(a, b): return a.total_progress > b.total_progress)
	var player_rank := sorted_karts.find(player_kart) + 1

	# Update HUD
	hud_pos_label.text = " %s | POS: %d / 8 " % [player_kart.racer_name.to_upper(), player_rank]
	hud_lap_label.text = " LAP: %d / %d " % [min(player_kart.current_lap, GameConfig.laps_count), GameConfig.laps_count]
	hud_item_label.text = " ITEM [E]: %s " % ITEM_NAMES.get(player_kart.held_item, "KOSONG")
	hud_chaos_label.text = " CHAOS: %d " % chaos_score
	hud_light_label.text = " LAMPU: %s " % ("MERAH!" if world_builder.traffic_state == "RED" else ("KUNING" if world_builder.traffic_state == "YELLOW" else "HIJAU"))
	hud_light_label.modulate = Color(1, 0.22, 0.2) if world_builder.traffic_state == "RED" else (Color(1, 0.85, 0.15) if world_builder.traffic_state == "YELLOW" else Color(0.25, 0.95, 0.35))
	hud_fps_label.text = " %d FPS " % int(Engine.get_frames_per_second())
	hud_speed_label.text = "%d km/h" % int(abs(player_kart.forward_speed) * 3.4)
	hud_nitro_bar.value = player_kart.nitro_energy

	# Check Finish -> Trigger Cinematic Replay Camera!
	if not race_finished and player_kart.current_lap > GameConfig.laps_count:
		race_finished = true
		_enter_replay_camera("%s FINIS #%d!  (CHAOS: %d)" % [player_kart.racer_name.to_upper(), player_rank, chaos_score])


func _enter_replay_camera(banner: String) -> void:
	hud_center_label.text = banner
	replay_panel.visible = true
	replay_sys.start_replay()


func _on_kart_powerup_used(kart: KartController, item_type: String) -> void:
	world_builder.trigger_powerup(self, kart, item_type)
	if kart == player_kart:
		_show_alert("PAKAI POWER-UP: " + ITEM_NAMES.get(item_type, item_type))


func _on_red_light_violated(kart: KartController) -> void:
	if kart == player_kart:
		chaos_score += 250
		_show_alert("TEROBOS LAMPU MERAH! +250 CHAOS +NITRO!")


func _on_prop_smashed(prop_kind: String, _pos: Vector3, kart: KartController) -> void:
	if kart == player_kart:
		chaos_score += 100
		_show_alert("TABRAK %s! +100 CHAOS" % prop_kind.to_upper())


func _show_alert(msg: String) -> void:
	hud_alert_label.text = msg
	alert_timer = 2.0
