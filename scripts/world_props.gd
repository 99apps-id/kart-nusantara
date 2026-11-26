extends Node3D
class_name ChaosWorldBuilder

signal red_light_violated(kart: KartController)
signal prop_smashed(prop_kind: String, pos: Vector3, kart: KartController)

# Model & Texture paths (loaded & cached safely on demand so clean --import never fails)
const P_INDOMARET := "res://assets/models/ruko_indomaret.glb"
const P_ALFAMART := "res://assets/models/ruko_alfamart.glb"
const P_KIOS_BUAH := "res://assets/models/kios_buah.glb"
const P_GAPURA := "res://assets/models/gapura.glb"
const P_TRAFFIC := "res://assets/models/traffic_light.glb"
const P_POLE := "res://assets/models/street_pole.glb"
const P_POT := "res://assets/models/plant_pot.glb"
const P_TREE := "res://assets/models/street_tree.glb"
const P_CARDBOARD := "res://assets/models/cardboard_box.glb"
const P_FENCE := "res://assets/models/wooden_fence.glb"
const P_GEROBAK := "res://assets/models/gerobak.glb"
const P_BARREL := "res://assets/models/barrel.glb"
const P_CHICKEN := "res://assets/models/chicken.glb"
const P_ANGKOT := "res://assets/models/angkot.glb"
const P_BARRIER := "res://assets/models/barrier.glb"
const P_PEDESTRIAN := "res://assets/models/pedestrian.glb"
const P_VINTAGE_LAMP := "res://assets/models/vintage_lamp.glb"
const P_BENCH := "res://assets/models/street_bench.glb"
const P_PALM := "res://assets/models/palm_tree.glb"
const P_TIRE_STACK := "res://assets/models/tire_stack.glb"
const P_GUARDRAIL := "res://assets/models/track_guardrail.glb"
const P_ITEM_BOX := "res://assets/models/item_box.glb"
const P_BANANA := "res://assets/models/banana_peel.glb"
const P_ROCKET := "res://assets/models/rocket.glb"
const P_WATER_BOMB := "res://assets/models/water_bomb.glb"
const P_OIL := "res://assets/models/oil_slick.glb"
const P_GEDUNG_KANTOR := "res://assets/models/gedung_kantor.glb"
const P_RUKO_KAFE := "res://assets/models/ruko_kafe.glb"
const P_RUMAH := "res://assets/models/rumah_nusantara.glb"
const P_BUSH := "res://assets/models/bush_tropical.glb"
const P_FLOWER_BED := "res://assets/models/flower_bed.glb"
const P_GAZEBO := "res://assets/models/park_gazebo.glb"
const P_SPEED_BUMP := "res://assets/models/speed_bump.glb"
const P_CONE := "res://assets/models/traffic_cone.glb"
const P_MOTOR := "res://assets/models/parked_motorcycle.glb"
const P_BICYCLE := "res://assets/models/parked_bicycle.glb"
const P_PEDESTRIAN_F := "res://assets/models/pedestrian_female.glb"

const PT_ASPHALT_A := "res://assets/textures/tex_asphalt_albedo.png"
const PT_ASPHALT_N := "res://assets/textures/tex_asphalt_normal.png"
const PT_ASPHALT_R := "res://assets/textures/tex_asphalt_roughness.png"
const PT_SIDEWALK_A := "res://assets/textures/tex_sidewalk_albedo.png"
const PT_SIDEWALK_N := "res://assets/textures/tex_sidewalk_normal.png"
const PT_SIDEWALK_R := "res://assets/textures/tex_sidewalk_roughness.png"
const PT_CURB_A := "res://assets/textures/tex_stone_curb_albedo.png"
const PT_CURB_N := "res://assets/textures/tex_stone_curb_normal.png"
const PT_GRASS_A := "res://assets/textures/tex_grass_albedo.png"
const PT_GRASS_N := "res://assets/textures/tex_grass_normal.png"

static var _res_cache: Dictionary = {}

static func get_model(path: String) -> PackedScene:
	if not _res_cache.has(path):
		_res_cache[path] = load(path)
	return _res_cache[path] as PackedScene

static func get_tex(path: String) -> Texture2D:
	if not _res_cache.has(path):
		_res_cache[path] = load(path)
	return _res_cache[path] as Texture2D

var active_karts: Array = []
var item_boxes: Array = []
var active_hazards: Array = []
var active_projectiles: Array = []
var dynamic_obstacles: Array = []
var pedestrians: Array = []
var flying_debris: Array = []
var comic_popups: Array = []
var traffic_lights: Array = []
var speed_bumps: Array = []
var speed_bump_cd: Dictionary = {}
var red_light_cooldown: Dictionary = {}
var ped_scream_global_cd: float = 0.0

var traffic_timer: float = 0.0
var traffic_state: String = "RED" # RED -> GREEN -> YELLOW


func setup_tropical_lighting(parent: Node3D) -> void:
	# Luminous Indonesian Golden-Hour Senja — bright, clear, natural road colors (not dark, not oversaturated)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.36, 0.68)
	sky_mat.sky_horizon_color = Color(0.96, 0.62, 0.40)
	sky_mat.sky_curve = 0.24
	sky_mat.ground_bottom_color = Color(0.20, 0.19, 0.24)
	sky_mat.ground_horizon_color = Color(0.46, 0.38, 0.42)
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.14
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Bright open twilight ambient so shadows, karts & road details stay clearly visible
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.54, 0.66)
	env.ambient_light_energy = 0.52

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.06
	env.tonemap_white = 3.2

	# Bright, balanced golden-hour color grading: readable shadows, non-oversaturated road
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.02

	# Subtle glow only for emissive lamps, traffic lights, nitro, and ruko signs
	env.glow_enabled = true
	env.glow_intensity = 0.16
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.55

	# Light golden-hour aerial perspective
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.58, 0.52)
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.20

	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	# Bright 3/4 golden-hour setting sun (warm glow ahead-left + crisp long shadows)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.84, 0.66)
	sun.light_energy = 1.30
	sun.shadow_enabled = true
	sun.shadow_blur = 1.25
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.rotation_degrees = Vector3(-20.0, 128.0, 0.0)
	parent.add_child(sun)

	# Open twilight sky bounce from rear-right so kart backs, drivers & road stay bright and legible
	var sky_fill := DirectionalLight3D.new()
	sky_fill.light_color = Color(0.76, 0.80, 0.94)
	sky_fill.light_energy = 0.46
	sky_fill.rotation_degrees = Vector3(-32.0, -42.0, 0.0)
	parent.add_child(sky_fill)

	# Natural tropical Indonesian late-afternoon birds ambience
	var birds := AudioStreamPlayer.new()
	birds.name = "BirdsAmbienceAudio"
	birds.stream = ComedySfx.get_stream("birds_ambience")
	birds.volume_db = -17.0
	birds.autoplay = true
	parent.add_child(birds)


func make_pbr_mat(albedo_tex: Texture2D, normal_tex: Texture2D, uv_scale: Vector3, roughness: float = 0.82, tint: Color = Color.WHITE, rough_tex: Texture2D = null, normal_strength: float = 1.5, use_triplanar: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo_tex
	m.albedo_color = tint
	if normal_tex != null:
		m.normal_enabled = true
		m.normal_texture = normal_tex
		m.normal_scale = normal_strength
	m.roughness = roughness
	if rough_tex != null:
		m.roughness_texture = rough_tex
		m.roughness = 1.0
	m.uv1_scale = uv_scale
	m.uv1_triplanar = use_triplanar
	m.uv1_world_triplanar = use_triplanar
	return m


func spawn_overhead_cables(parent: Node3D, p1: Vector3, p2: Vector3, sag: float = 1.35) -> void:
	# Overhead sagging catenary utility cables strung across the street
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.14, 0.16, 0.19)
	wire_mat.roughness = 0.65
	var offsets := [Vector3(0, 0.0, 0), Vector3(0, -0.32, 0.25), Vector3(0, 0.28, -0.22)]
	for off in offsets:
		var a: Vector3 = p1 + off
		var b: Vector3 = p2 + off
		var segs := 8
		for i in range(segs):
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var v0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * sag, 0)
			var v1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * sag, 0)
			var mid := (v0 + v1) * 0.5
			var dist := v0.distance_to(v1)
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.028
			cyl.bottom_radius = 0.028
			cyl.height = dist
			cyl.radial_segments = 6
			mi.mesh = cyl
			mi.material_override = wire_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			mi.global_position = mid
			var dir := (v1 - v0).normalized()
			var up_ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
			var basis := Basis.looking_at(dir, up_ref)
			mi.global_basis = basis * Basis(Vector3.RIGHT, PI * 0.5)


func spawn_sky_rainbow(parent: Node3D) -> void:
	# Subtle translucent tropical rainbow arc high in the sunny sky background
	var colors := [
		Color(1.0, 0.25, 0.22, 0.13),
		Color(1.0, 0.65, 0.18, 0.12),
		Color(1.0, 0.95, 0.28, 0.11),
		Color(0.25, 0.90, 0.45, 0.11),
		Color(0.22, 0.65, 1.0, 0.12),
		Color(0.55, 0.30, 0.95, 0.10),
	]
	var holder := Node3D.new()
	holder.position = Vector3(-12.0, -18.0, -155.0)
	holder.rotation_degrees = Vector3(0.0, -8.0, 0.0)
	parent.add_child(holder)
	for i in range(colors.size()):
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.outer_radius = 96.0 - i * 1.9
		torus.inner_radius = 94.0 - i * 1.9
		torus.rings = 32
		torus.ring_segments = 8
		mi.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = colors[i]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)


func add_ground_slab(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_y: float = 0.0, rot_x: float = 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation = Vector3(rot_x, rot_y, 0.0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	sb.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	parent.add_child(sb)
	return sb


# ---------------------------------------------------------------------------
# Curved ribbon road builder (Catmull-Rom spline driven, smooth drivable curbs & ramps)
# ---------------------------------------------------------------------------

static func catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func sample_closed_spline(ctrl: Array, samples_per_seg: int = 10) -> Array:
	var out: Array = []
	var n := ctrl.size()
	if n < 3:
		return out
	for i in range(n):
		var p0: Vector3 = ctrl[(i - 1 + n) % n]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[(i + 1) % n]
		var p3: Vector3 = ctrl[(i + 2) % n]
		for s in range(samples_per_seg):
			out.append(catmull_rom(p0, p1, p2, p3, float(s) / float(samples_per_seg)))
	return out


static func sample_open_spline(ctrl: Array, samples_per_seg: int = 8) -> Array:
	var out: Array = []
	var n := ctrl.size()
	if n < 2:
		return out
	for i in range(n - 1):
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, n - 1)]
		for s in range(samples_per_seg):
			out.append(catmull_rom(p0, p1, p2, p3, float(s) / float(samples_per_seg)))
	out.append(ctrl[n - 1])
	return out


# Builds a continuous curved road + gently sloped curbs + sidewalks + gentle ramps down to park grass.
# Maximum slope is ~8 degrees so karts freely drive across sidewalks and parks and re-enter anywhere!
func build_curved_road(parent: Node3D, ctrl_pts: Array, road_width: float, mat_asphalt: Material, mats: Dictionary, samples_per_seg: int = 10) -> Dictionary:
	var samples := sample_closed_spline(ctrl_pts, samples_per_seg)
	return _build_road_from_samples(parent, samples, road_width, mat_asphalt, mats, true)


func build_open_curved_road(parent: Node3D, ctrl_pts: Array, road_width: float, mat_asphalt: Material, mats: Dictionary, samples_per_seg: int = 8) -> Dictionary:
	var samples := sample_open_spline(ctrl_pts, samples_per_seg)
	return _build_road_from_samples(parent, samples, road_width, mat_asphalt, mats, false)


func _build_road_from_samples(parent: Node3D, samples: Array, road_width: float, mat_asphalt: Material, mats: Dictionary, closed: bool) -> Dictionary:
	var n := samples.size()
	var tangents: Array = []
	var rights: Array = []
	var arc_lengths: Array = []
	var accum := 0.0

	for i in range(n):
		if i > 0:
			accum += (samples[i] as Vector3).distance_to(samples[i - 1] as Vector3)
		arc_lengths.append(accum)
		var a: Vector3 = samples[(i - 1 + n) % n] if closed else samples[maxi(i - 1, 0)]
		var b: Vector3 = samples[(i + 1) % n] if closed else samples[mini(i + 1, n - 1)]
		var t_vec := (b - a)
		t_vec.y = 0.0
		if t_vec.length() < 0.0001:
			t_vec = Vector3.FORWARD
		t_vec = t_vec.normalized()
		var r_vec := t_vec.cross(Vector3.UP).normalized()
		tangents.append(t_vec)
		rights.append(r_vec)

	var total_len := accum
	if closed and n > 1:
		total_len += (samples[0] as Vector3).distance_to(samples[n - 1] as Vector3)

	var half_w := road_width * 0.5
	var curb_w: float = float(mats.get("curb_w", 0.55))
	var walk_w: float = float(mats.get("walk_w", 3.2))
	var ramp_w: float = float(mats.get("ramp_w", 1.5))
	var road_y: float = float(mats.get("road_y", 0.06))
	var walk_y: float = float(mats.get("walk_y", 0.14))
	var add_sidewalks: bool = bool(mats.get("sidewalks", true))

	# 1. Drivable Asphalt Deck
	_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, -half_w, half_w, road_y, road_y, mat_asphalt, closed, 1.0, 14.0, true)

	if add_sidewalks:
		var mat_curb: Material = mats.get("curb", mat_asphalt)
		var mat_walk: Material = mats.get("walk", mat_asphalt)
		var mat_ramp: Material = mats.get("ramp", mat_walk)

		# Left side: smooth sloped curb (road_y -> walk_y), flat sidewalk, smooth ramp down to grass (walk_y -> 0.0)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, -(half_w + curb_w), -half_w, walk_y, road_y, mat_curb, closed, 1.0, 4.0, true)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, -(half_w + curb_w + walk_w), -(half_w + curb_w), walk_y, walk_y, mat_walk, closed, 1.0, 5.0, true)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, -(half_w + curb_w + walk_w + ramp_w), -(half_w + curb_w + walk_w), 0.0, walk_y, mat_ramp, closed, 1.0, 6.0, true)

		# Right side: smooth sloped curb (road_y -> walk_y), flat sidewalk, smooth ramp down to grass (walk_y -> 0.0)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, half_w, half_w + curb_w, road_y, walk_y, mat_curb, closed, 1.0, 4.0, true)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, half_w + curb_w, half_w + curb_w + walk_w, walk_y, walk_y, mat_walk, closed, 1.0, 5.0, true)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, half_w + curb_w + walk_w, half_w + curb_w + walk_w + ramp_w, walk_y, 0.0, mat_ramp, closed, 1.0, 6.0, true)
	else:
		# Shortcut / alley: gentle beveled shoulder slopes directly down to park grass
		var mat_shoulder: Material = mats.get("curb", mat_asphalt)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, -(half_w + 1.1), -half_w, 0.0, road_y, mat_shoulder, closed, 1.0, 6.0, true)
		_build_ribbon_band(parent, samples, rights, arc_lengths, total_len, half_w, half_w + 1.1, road_y, 0.0, mat_shoulder, closed, 1.0, 6.0, true)

	return {
		"samples": samples,
		"tangents": tangents,
		"rights": rights,
		"arc_lengths": arc_lengths,
		"total_length": total_len,
		"road_width": road_width
	}


func _build_ribbon_band(parent: Node3D, samples: Array, rights: Array, arc_lengths: Array, total_len: float, off_left: float, off_right: float, y_left: float, y_right: float, mat: Material, closed: bool, u_repeat: float, v_step: float, with_collision: bool) -> MeshInstance3D:
	var n := samples.size()
	var seg_count := n if closed else (n - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(seg_count):
		var j := (i + 1) % n
		var ci: Vector3 = samples[i]
		var cj: Vector3 = samples[j]
		var ri: Vector3 = rights[i]
		var rj: Vector3 = rights[j]

		var a0 := ci + ri * off_left + Vector3(0.0, y_left, 0.0)
		var b0 := ci + ri * off_right + Vector3(0.0, y_right, 0.0)
		var a1 := cj + rj * off_left + Vector3(0.0, y_left, 0.0)
		var b1 := cj + rj * off_right + Vector3(0.0, y_right, 0.0)

		var v0: float = float(arc_lengths[i]) / v_step
		var v1: float = (total_len if (closed and j == 0) else float(arc_lengths[j])) / v_step

		# CW winding viewed from +Y so face normals point strictly UP (+Y)
		st.set_uv(Vector2(0.0, v0)); st.add_vertex(a0)
		st.set_uv(Vector2(0.0, v1)); st.add_vertex(a1)
		st.set_uv(Vector2(u_repeat, v1)); st.add_vertex(b1)

		st.set_uv(Vector2(0.0, v0)); st.add_vertex(a0)
		st.set_uv(Vector2(u_repeat, v1)); st.add_vertex(b1)
		st.set_uv(Vector2(u_repeat, v0)); st.add_vertex(b0)

	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)

	if with_collision:
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		if shape is ConcavePolygonShape3D:
			(shape as ConcavePolygonShape3D).backface_collision = true
		col.shape = shape
		sb.add_child(col)
		parent.add_child(sb)
	return mi


func build_curved_tunnel(parent: Node3D, road_data: Dictionary, start_idx: int, end_idx: int, inner_half_w: float = 9.4, wall_h: float = 2.6, arch_h: float = 5.2, thickness: float = 1.4) -> Node3D:
	# Drivable curved concrete tunnel following the spline road with portals, ceiling lamps, side reflectors & smooth guide walls
	var samples: Array = road_data["samples"]
	var rights: Array = road_data["rights"]
	var tangents: Array = road_data["tangents"]
	var arc_lengths: Array = road_data["arc_lengths"]
	var n_samp: int = samples.size()

	var root := Node3D.new()
	root.name = "CurvedTunnel"
	parent.add_child(root)

	# Collect ordered ring indices from start_idx to end_idx (inclusive)
	var idxs: Array[int] = []
	var cur := ((start_idx % n_samp) + n_samp) % n_samp
	var stop := ((end_idx % n_samp) + n_samp) % n_samp
	for _guard in range(n_samp + 1):
		idxs.append(cur)
		if cur == stop:
			break
		cur = (cur + 1) % n_samp
	if idxs.size() < 2:
		return root

	# Build cross-section profile points (local X, Y) from left floor -> left wall -> arch -> right wall -> right floor
	var arch_segs := 10
	var inner_prof: Array[Vector2] = [Vector2(-inner_half_w, -0.05), Vector2(-inner_half_w, wall_h)]
	var outer_prof: Array[Vector2] = [Vector2(-(inner_half_w + thickness), -0.05), Vector2(-(inner_half_w + thickness), wall_h)]
	for a in range(1, arch_segs):
		var ang := PI * (1.0 - float(a) / float(arch_segs)) # PI (left) -> 0 (right)
		var cx := cos(ang)
		var sy := sin(ang)
		inner_prof.append(Vector2(cx * inner_half_w, wall_h + sy * arch_h))
		outer_prof.append(Vector2(cx * (inner_half_w + thickness), wall_h + sy * (arch_h + thickness)))
	inner_prof.append(Vector2(inner_half_w, wall_h))
	inner_prof.append(Vector2(inner_half_w, -0.05))
	outer_prof.append(Vector2(inner_half_w + thickness, wall_h))
	outer_prof.append(Vector2(inner_half_w + thickness, -0.05))

	var p_count := inner_prof.size()
	var mat_inner := make_pbr_mat(get_tex(PT_CURB_A), get_tex(PT_CURB_N), Vector3(1.0, 1.0, 1.0), 0.88, Color(0.76, 0.78, 0.82), null, 1.8, false)
	mat_inner.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_outer := make_pbr_mat(get_tex(PT_CURB_A), get_tex(PT_CURB_N), Vector3(1.0, 1.0, 1.0), 0.92, Color(0.56, 0.58, 0.62), null, 2.0, false)
	mat_outer.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st_in := SurfaceTool.new()
	st_in.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_out := SurfaceTool.new()
	st_out.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_col := SurfaceTool.new()
	st_col.begin(Mesh.PRIMITIVE_TRIANGLES)

	for s in range(idxs.size() - 1):
		var i0 := idxs[s]
		var i1 := idxs[s + 1]
		var c0: Vector3 = samples[i0]
		var c1: Vector3 = samples[i1]
		var r0: Vector3 = rights[i0]
		var r1: Vector3 = rights[i1]
		var v0 := float(arc_lengths[i0]) / 7.5
		var v1 := float(arc_lengths[i1]) / 7.5
		if v1 < v0:
			v1 = v0 + c0.distance_to(c1) / 7.5

		for k in range(p_count - 1):
			var u0 := float(k) / float(p_count - 1) * 4.0
			var u1 := float(k + 1) / float(p_count - 1) * 4.0

			# Inner vault quad (facing inward toward road)
			var ia0 := c0 + r0 * inner_prof[k].x + Vector3(0.0, inner_prof[k].y, 0.0)
			var ib0 := c0 + r0 * inner_prof[k + 1].x + Vector3(0.0, inner_prof[k + 1].y, 0.0)
			var ia1 := c1 + r1 * inner_prof[k].x + Vector3(0.0, inner_prof[k].y, 0.0)
			var ib1 := c1 + r1 * inner_prof[k + 1].x + Vector3(0.0, inner_prof[k + 1].y, 0.0)

			st_in.set_uv(Vector2(u0, v0)); st_in.add_vertex(ia0)
			st_in.set_uv(Vector2(u1, v1)); st_in.add_vertex(ib1)
			st_in.set_uv(Vector2(u0, v1)); st_in.add_vertex(ia1)
			st_in.set_uv(Vector2(u0, v0)); st_in.add_vertex(ia0)
			st_in.set_uv(Vector2(u1, v0)); st_in.add_vertex(ib0)
			st_in.set_uv(Vector2(u1, v1)); st_in.add_vertex(ib1)

			# Only add smooth side-wall collider on lower left (k==0) and lower right (k==p_count-2) walls
			if k == 0 or k == p_count - 2:
				st_col.add_vertex(ia0); st_col.add_vertex(ib1); st_col.add_vertex(ia1)
				st_col.add_vertex(ia0); st_col.add_vertex(ib0); st_col.add_vertex(ib1)

			# Outer concrete shell quad
			var oa0 := c0 + r0 * outer_prof[k].x + Vector3(0.0, outer_prof[k].y, 0.0)
			var ob0 := c0 + r0 * outer_prof[k + 1].x + Vector3(0.0, outer_prof[k + 1].y, 0.0)
			var oa1 := c1 + r1 * outer_prof[k].x + Vector3(0.0, outer_prof[k].y, 0.0)
			var ob1 := c1 + r1 * outer_prof[k + 1].x + Vector3(0.0, outer_prof[k + 1].y, 0.0)

			st_out.set_uv(Vector2(u0, v0)); st_out.add_vertex(oa0)
			st_out.set_uv(Vector2(u0, v1)); st_out.add_vertex(oa1)
			st_out.set_uv(Vector2(u1, v1)); st_out.add_vertex(ob1)
			st_out.set_uv(Vector2(u0, v0)); st_out.add_vertex(oa0)
			st_out.set_uv(Vector2(u1, v1)); st_out.add_vertex(ob1)
			st_out.set_uv(Vector2(u1, v0)); st_out.add_vertex(ob0)

	# Cap both entrance & exit tunnel portal rings (connect inner_prof to outer_prof)
	for cap_end in [0, idxs.size() - 1]:
		var ci_idx := idxs[cap_end]
		var cc: Vector3 = samples[ci_idx]
		var rr: Vector3 = rights[ci_idx]
		for k in range(p_count - 1):
			var p_in0 := cc + rr * inner_prof[k].x + Vector3(0.0, inner_prof[k].y, 0.0)
			var p_in1 := cc + rr * inner_prof[k + 1].x + Vector3(0.0, inner_prof[k + 1].y, 0.0)
			var p_out0 := cc + rr * outer_prof[k].x + Vector3(0.0, outer_prof[k].y, 0.0)
			var p_out1 := cc + rr * outer_prof[k + 1].x + Vector3(0.0, outer_prof[k + 1].y, 0.0)
			st_out.set_uv(Vector2(0.0, 0.0)); st_out.add_vertex(p_in0)
			st_out.set_uv(Vector2(1.0, 0.0)); st_out.add_vertex(p_out0)
			st_out.set_uv(Vector2(1.0, 1.0)); st_out.add_vertex(p_out1)
			st_out.set_uv(Vector2(0.0, 0.0)); st_out.add_vertex(p_in0)
			st_out.set_uv(Vector2(1.0, 1.0)); st_out.add_vertex(p_out1)
			st_out.set_uv(Vector2(0.0, 1.0)); st_out.add_vertex(p_in1)

	st_in.generate_normals()
	var mi_in := MeshInstance3D.new()
	mi_in.mesh = st_in.commit()
	mi_in.material_override = mat_inner
	root.add_child(mi_in)

	st_out.generate_normals()
	var mi_out := MeshInstance3D.new()
	mi_out.mesh = st_out.commit()
	mi_out.material_override = mat_outer
	root.add_child(mi_out)

	# Smooth side-wall collision body (keeps karts safely guided inside the tunnel without ever snagging ceiling or floor)
	var col_mesh := st_col.commit()
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := col_mesh.create_trimesh_shape()
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	col.shape = shape
	sb.add_child(col)
	root.add_child(sb)

	# Decorative Concrete Portal Arches + Overhead Nameplates ("TEROWONGAN NUSANTARA") at entrance & exit
	var mat_portal := StandardMaterial3D.new()
	mat_portal.albedo_color = Color(0.92, 0.72, 0.12)
	mat_portal.roughness = 0.55
	var mat_sign := StandardMaterial3D.new()
	mat_sign.albedo_color = Color(0.08, 0.42, 0.22)
	mat_sign.roughness = 0.45
	for end_i in [0, idxs.size() - 1]:
		var pi := idxs[end_i]
		var pc: Vector3 = samples[pi]
		var pt: Vector3 = tangents[pi]
		var yaw := atan2(pt.x, pt.z)
		var sign_root := Node3D.new()
		sign_root.position = pc + Vector3(0.0, wall_h + arch_h + 0.55, 0.0)
		sign_root.rotation.y = yaw + (PI if end_i == 0 else 0.0)
		root.add_child(sign_root)

		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(11.5, 1.55, 0.35)
		board.mesh = bm
		board.material_override = mat_sign
		sign_root.add_child(board)

		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(12.0, 0.22, 0.42)
		trim.mesh = tm
		trim.position = Vector3(0.0, -0.82, 0.0)
		trim.material_override = mat_portal
		sign_root.add_child(trim)

		var lbl := Label3D.new()
		lbl.text = "TEROWONGAN NUSANTARA"
		lbl.font_size = 96
		lbl.pixel_size = 0.0082
		lbl.modulate = Color(1.0, 0.96, 0.80)
		lbl.outline_size = 10
		lbl.outline_modulate = Color(0.05, 0.14, 0.08)
		lbl.position = Vector3(0.0, 0.02, 0.22)
		sign_root.add_child(lbl)

	# Glowing Overhead Ceiling Lights + Warm Side Reflectors + Real OmniLights inside the Tunnel!
	var mat_lamp := StandardMaterial3D.new()
	mat_lamp.albedo_color = Color(1.0, 0.94, 0.76)
	mat_lamp.emission_enabled = true
	mat_lamp.emission = Color(1.0, 0.86, 0.55)
	mat_lamp.emission_energy_multiplier = 2.6
	var mat_refl := StandardMaterial3D.new()
	mat_refl.albedo_color = Color(1.0, 0.58, 0.10)
	mat_refl.emission_enabled = true
	mat_refl.emission = Color(1.0, 0.50, 0.08)
	mat_refl.emission_energy_multiplier = 2.0

	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(1.6, 0.18, 2.4)
	var refl_mesh := BoxMesh.new()
	refl_mesh.size = Vector3(0.14, 0.22, 1.4)

	for s in range(1, idxs.size() - 1):
		var si := idxs[s]
		var sc: Vector3 = samples[si]
		var st_dir: Vector3 = tangents[si]
		var sr: Vector3 = rights[si]
		var yaw := atan2(st_dir.x, st_dir.z)

		# Side glowing chevron reflectors on both walls
		for side_sign in [-1.0, 1.0]:
			var rf := MeshInstance3D.new()
			rf.mesh = refl_mesh
			rf.material_override = mat_refl
			rf.position = sc + sr * (side_sign * (inner_half_w - 0.12)) + Vector3(0.0, 1.15, 0.0)
			rf.rotation.y = yaw
			rf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rf)

		# Ceiling fluorescent strip lamps every 2 rings + warm OmniLight3D every 3 rings
		if s % 2 == 1:
			var lm := MeshInstance3D.new()
			lm.mesh = lamp_mesh
			lm.material_override = mat_lamp
			lm.position = sc + Vector3(0.0, wall_h + arch_h - 0.25, 0.0)
			lm.rotation.y = yaw
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(lm)
		if s % 3 == 1:
			var ol := OmniLight3D.new()
			ol.position = sc + Vector3(0.0, wall_h + arch_h - 1.2, 0.0)
			ol.light_color = Color(1.0, 0.88, 0.68)
			ol.light_energy = 2.2
			ol.omni_range = 20.0
			ol.omni_attenuation = 1.15
			ol.shadow_enabled = false
			root.add_child(ol)

	return root


static func apply_realistic_glass(root: Node) -> void:
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.get_active_material(s)
					if mat != null and (mat.resource_name.begins_with("Mat_Glass") or mat.resource_name.begins_with("M_Glass")):
						var g := StandardMaterial3D.new()
						g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						g.albedo_color = Color(0.86, 0.95, 1.0, 0.26)
						g.roughness = 0.04
						g.metallic = 0.08
						g.clearcoat_enabled = true
						g.clearcoat = 1.0
						g.clearcoat_roughness = 0.03
						g.rim_enabled = true
						g.rim = 0.55
						g.rim_tint = 0.25
						g.cull_mode = BaseMaterial3D.CULL_DISABLED
						mi.set_surface_override_material(s, g)
					elif mat != null and mat.resource_name.begins_with("Mat_Visor"):
						# Realistic tinted helmet visor glass that dynamically reflects sky & sunlight
						var v := StandardMaterial3D.new()
						v.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						v.albedo_color = Color(0.08, 0.14, 0.22, 0.72)
						v.roughness = 0.03
						v.metallic = 0.55
						v.clearcoat_enabled = true
						v.clearcoat = 1.0
						v.clearcoat_roughness = 0.02
						v.rim_enabled = true
						v.rim = 0.75
						v.rim_tint = 0.45
						mi.set_surface_override_material(s, v)
		for ch in n.get_children():
			stack.append(ch)


func spawn_static_model(parent: Node3D, model_path: String, pos: Vector3, rot_y_deg: float, col_size: Vector3 = Vector3.ZERO, scale_val: float = 1.0) -> Node3D:
	var wrap := Node3D.new()
	wrap.position = pos
	wrap.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var inst := get_model(model_path).instantiate()
	apply_realistic_glass(inst)
	inst.scale = Vector3(scale_val, scale_val, scale_val)
	wrap.add_child(inst)
	if col_size != Vector3.ZERO:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = col_size
		cs.shape = bx
		cs.position = Vector3(0.0, col_size.y * 0.5, 0.0)
		sb.add_child(cs)
		wrap.add_child(sb)
	parent.add_child(wrap)
	return wrap


func spawn_destructible(parent: Node3D, kind: String, pos: Vector3, rot_y_deg: float = 0.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.position = pos
	rb.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var model_path: String = P_CARDBOARD
	var csize := Vector3(0.9, 0.85, 0.85)
	var mass_val := 1.2
	match kind:
		"cardboard":
			model_path = P_CARDBOARD; csize = Vector3(0.9, 0.85, 0.85); mass_val = 0.7
		"fence":
			model_path = P_FENCE; csize = Vector3(2.2, 1.1, 0.35); mass_val = 1.8
		"gerobak":
			model_path = P_GEROBAK; csize = Vector3(1.2, 2.0, 2.0); mass_val = 3.2
		"barrel":
			model_path = P_BARREL; csize = Vector3(0.8, 1.15, 0.8); mass_val = 2.0
		"pole":
			model_path = P_POLE; csize = Vector3(0.45, 4.4, 0.45); mass_val = 3.6
		"pot":
			model_path = P_POT; csize = Vector3(0.95, 1.35, 0.95); mass_val = 1.6
		"cone":
			model_path = P_CONE; csize = Vector3(0.55, 0.78, 0.55); mass_val = 0.45
		"motorcycle":
			model_path = P_MOTOR; csize = Vector3(0.95, 1.25, 2.05); mass_val = 2.6
		"bicycle":
			model_path = P_BICYCLE; csize = Vector3(0.65, 1.15, 1.75); mass_val = 1.1
	rb.mass = mass_val
	rb.linear_damp = 0.35
	rb.angular_damp = 0.35

	var inst := get_model(model_path).instantiate()
	apply_realistic_glass(inst)
	rb.add_child(inst)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = csize
	cs.shape = bx
	cs.position = Vector3(0.0, csize.y * 0.5, 0.0)
	rb.add_child(cs)

	# Attach lightweight hit callback via metadata + signal hook
	rb.set_meta("prop_kind", kind)
	rb.set_meta("smashed", false)
	parent.add_child(rb)
	return rb


func spawn_traffic_light(parent: Node3D, pos: Vector3, rot_y_deg: float, stop_zone_center: Vector3) -> void:
	var inst := get_model(P_TRAFFIC).instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	parent.add_child(inst)
	var l_red := inst.find_child("Light_Red", true, false) as MeshInstance3D
	var l_yel := inst.find_child("Light_Yellow", true, false) as MeshInstance3D
	var l_grn := inst.find_child("Light_Green", true, false) as MeshInstance3D
	var entry := {
		"node": inst,
		"red": l_red,
		"yellow": l_yel,
		"green": l_grn,
		"zone": stop_zone_center
	}
	traffic_lights.append(entry)
	_apply_traffic_lamp_colors(entry, traffic_state)


func spawn_item_box(parent: Node3D, pos: Vector3) -> void:
	var inst := get_model(P_ITEM_BOX).instantiate() as Node3D
	inst.position = pos + Vector3(0.0, 0.65, 0.0)
	parent.add_child(inst)
	item_boxes.append({"node": inst, "pos": pos, "cooldown": 0.0})


func spawn_dynamic_obstacle(parent: Node3D, kind: String, point_a: Vector3, point_b: Vector3, speed: float) -> void:
	var model_path: String = P_CHICKEN
	var radius := 1.1
	match kind:
		"chicken": model_path = P_CHICKEN; radius = 0.9
		"angkot": model_path = P_ANGKOT; radius = 2.4
		"barrier": model_path = P_BARRIER; radius = 1.6
	var inst := get_model(model_path).instantiate() as Node3D
	apply_realistic_glass(inst)
	inst.position = point_a
	parent.add_child(inst)
	dynamic_obstacles.append({
		"node": inst,
		"kind": kind,
		"a": point_a,
		"b": point_b,
		"speed": speed,
		"t": randf(),
		"dir": 1.0,
		"radius": radius,
		"hit_cd": 0.0
	})


func spawn_speedbump(parent: Node3D, pos: Vector3, rot_y_deg: float, width_scale: float = 1.65) -> Node3D:
	var inst := get_model(P_SPEED_BUMP).instantiate() as Node3D
	inst.position = pos
	inst.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	inst.scale = Vector3(width_scale, 1.0, 1.15)
	parent.add_child(inst)
	var rad := deg_to_rad(rot_y_deg)
	var right_dir := Vector3(cos(rad), 0.0, -sin(rad)).normalized()
	var fwd_dir := Vector3(sin(rad), 0.0, cos(rad)).normalized()
	speed_bumps.append({
		"pos": pos,
		"right": right_dir,
		"fwd": fwd_dir,
		"half_w": 3.5 * width_scale
	})
	return inst


func spawn_pedestrian(parent: Node3D, home_pos: Vector3, safe_dir: Vector3, shirt_color: Color, is_female: bool = false) -> void:
	var model_path: String = P_PEDESTRIAN_F if is_female else P_PEDESTRIAN
	var inst := get_model(model_path).instantiate() as Node3D
	inst.position = home_pos
	parent.add_child(inst)
	# Tint shirt / blouse
	var torso := inst.find_child("Torso", true, false) as MeshInstance3D
	if torso == null:
		torso = inst.find_child("Blouse", true, false) as MeshInstance3D
	if torso != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = shirt_color
		m.roughness = 0.65
		torso.material_override = m
	pedestrians.append({
		"node": inst,
		"home": home_pos,
		"safe_dir": safe_dir.normalized(),
		"arm_l": inst.find_child("Arm_L", true, false) as Node3D,
		"arm_r": inst.find_child("Arm_R", true, false) as Node3D,
		"leg_l": inst.find_child("Leg_L", true, false) as Node3D,
		"leg_r": inst.find_child("Leg_R", true, false) as Node3D,
		"flee_timer": 0.0,
		"flee_dir": safe_dir.normalized(),
		"phase": randf() * TAU,
		"is_female": is_female,
		"scream_cd": 0.0
	})


func spawn_flying_chaos_burst(parent: Node3D, origin: Vector3, include_cardboard: bool = true) -> void:
	# Cap active flying debris for rock-solid 60 FPS during big chain crashes
	while flying_debris.size() > 38:
		var oldest: Dictionary = flying_debris.pop_front()
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Node).queue_free()
	# Floating/fluttering newspapers & papers in the air!
	for i in range(5):
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var plane := BoxMesh.new()
		plane.size = Vector3(randf_range(0.28, 0.45), 0.015, randf_range(0.36, 0.58))
		mi.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.94, 0.88) if i % 2 == 0 else Color(0.96, 0.86, 0.42)
		mat.roughness = 0.85
		mi.material_override = mat
		mi.position = origin + Vector3(randf_range(-1.2, 1.2), randf_range(0.6, 1.8), randf_range(-1.2, 1.2))
		parent.add_child(mi)
		flying_debris.append({
			"node": mi,
			"vel": Vector3(randf_range(-5.5, 5.5), randf_range(3.5, 7.5), randf_range(-5.5, 5.5)),
			"spin": Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7)),
			"gravity": 2.4, # Light paper floats slowly!
			"life": randf_range(3.2, 5.0),
			"flutter": randf() * TAU
		})
	# Floating/tumbling cardboard box!
	if include_cardboard:
		var cb := get_model(P_CARDBOARD).instantiate() as Node3D
		cb.scale = Vector3(0.68, 0.68, 0.68)
		cb.position = origin + Vector3(randf_range(-0.8, 0.8), 1.1, randf_range(-0.8, 0.8))
		parent.add_child(cb)
		flying_debris.append({
			"node": cb,
			"vel": Vector3(randf_range(-6.0, 6.0), randf_range(5.5, 9.0), randf_range(-6.0, 6.0)),
			"spin": Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)),
			"gravity": 6.8,
			"life": 3.8,
			"flutter": 0.0
		})


func spawn_comic_popup(parent: Node3D, pos: Vector3, text: String, col: Color = Color(1.0, 0.90, 0.15)) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 56
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = col
	lbl.outline_size = 12
	lbl.position = pos + Vector3(0.0, 2.2, 0.0)
	parent.add_child(lbl)
	comic_popups.append({"node": lbl, "age": 0.0, "life": 1.35})


func trigger_powerup(parent: Node3D, kart: KartController, item_type: String) -> void:
	var fwd := -kart.global_basis.z
	match item_type:
		"shield":
			kart.activate_shield(6.5)
		"banana":
			var b := get_model(P_BANANA).instantiate() as Node3D
			b.position = kart.global_position - fwd * 2.8
			b.position.y = 0.05
			parent.add_child(b)
			active_hazards.append({"node": b, "kind": "banana", "owner": kart, "arm": 0.6, "radius": 1.4})
		"oil":
			var o := get_model(P_OIL).instantiate() as Node3D
			o.position = kart.global_position - fwd * 3.0
			o.position.y = 0.04
			parent.add_child(o)
			active_hazards.append({"node": o, "kind": "oil", "owner": kart, "arm": 0.6, "radius": 2.1})
		"rocket":
			var r := get_model(P_ROCKET).instantiate() as Node3D
			r.position = kart.global_position + fwd * 2.4 + Vector3(0.0, 0.7, 0.0)
			r.rotation = kart.global_rotation
			parent.add_child(r)
			active_projectiles.append({
				"node": r, "kind": "rocket", "owner": kart,
				"vel": fwd * 54.0, "life": 4.0, "gravity": 0.0
			})
		"water_bomb":
			var wb := get_model(P_WATER_BOMB).instantiate() as Node3D
			wb.position = kart.global_position + fwd * 2.0 + Vector3(0.0, 1.3, 0.0)
			parent.add_child(wb)
			active_projectiles.append({
				"node": wb, "kind": "water_bomb", "owner": kart,
				"vel": fwd * 32.0 + Vector3(0.0, 10.5, 0.0), "life": 3.0, "gravity": 24.0
			})


func tick_world(parent: Node3D, delta: float) -> void:
	_tick_traffic_lights(parent, delta)
	_tick_speed_bumps(parent, delta)
	_tick_item_boxes(delta)
	_tick_hazards(parent, delta)
	_tick_projectiles(parent, delta)
	_tick_dynamic_obstacles(parent, delta)
	_tick_pedestrians(parent, delta)
	_tick_flying_debris(delta)
	_tick_comic_popups(delta)
	_tick_smashed_props_check(parent)


func _tick_traffic_lights(parent: Node3D, delta: float) -> void:
	traffic_timer += delta
	var cycle := fmod(traffic_timer, 12.0)
	var new_state := "RED" if cycle < 5.0 else ("GREEN" if cycle < 10.5 else "YELLOW")
	if new_state != traffic_state:
		traffic_state = new_state
		for tl in traffic_lights:
			_apply_traffic_lamp_colors(tl, traffic_state)

	for k_id in red_light_cooldown.keys():
		red_light_cooldown[k_id] = max(0.0, float(red_light_cooldown[k_id]) - delta)

	if traffic_state == "RED":
		for tl in traffic_lights:
			var zone: Vector3 = tl["zone"]
			for k in active_karts:
				if not is_instance_valid(k):
					continue
				var kid: int = k.get_instance_id()
				if float(red_light_cooldown.get(kid, 0.0)) > 0.0:
					continue
				if k.global_position.distance_to(zone) < 8.5 and abs(k.forward_speed) > 10.0:
					red_light_cooldown[kid] = 5.0
					k.nitro_energy = min(100.0, k.nitro_energy + 20.0)
					spawn_flying_chaos_burst(parent, k.global_position, false)
					spawn_comic_popup(parent, k.global_position, "WEE-WOO! TEROBOS!", Color(1.0, 0.25, 0.2))
					if k.is_player:
						ComedySfx.play(parent, "siren", -5.0)
						k.add_camera_shake(0.35)
					emit_signal("red_light_violated", k)


func _apply_traffic_lamp_colors(tl: Dictionary, state: String) -> void:
	# Keep all 3 lenses (Red, Yellow, Green) visibly colored while highlighting the active signal brightly!
	_set_emissive(tl["red"], Color(1.0, 0.08, 0.05) if state == "RED" else Color(0.45, 0.05, 0.04), 5.0 if state == "RED" else 0.35)
	_set_emissive(tl["yellow"], Color(1.0, 0.82, 0.05) if state == "YELLOW" else Color(0.48, 0.38, 0.04), 5.0 if state == "YELLOW" else 0.35)
	_set_emissive(tl["green"], Color(0.08, 0.96, 0.24) if state == "GREEN" else Color(0.05, 0.42, 0.12), 5.0 if state == "GREEN" else 0.35)


func _set_emissive(mi: MeshInstance3D, col: Color, strength: float) -> void:
	if mi == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = strength
	mi.material_override = mat


func _tick_speed_bumps(parent: Node3D, delta: float) -> void:
	for k_id in speed_bump_cd.keys():
		speed_bump_cd[k_id] = maxf(0.0, float(speed_bump_cd[k_id]) - delta)
	for sb in speed_bumps:
		var bp: Vector3 = sb["pos"]
		var r_dir: Vector3 = sb["right"]
		var f_dir: Vector3 = sb["fwd"]
		var hw: float = float(sb["half_w"])
		for k in active_karts:
			if not is_instance_valid(k):
				continue
			var kid: int = k.get_instance_id()
			if float(speed_bump_cd.get(kid, 0.0)) > 0.0:
				continue
			var rel: Vector3 = k.global_position - bp
			rel.y = 0.0
			if absf(rel.dot(f_dir)) < 1.15 and absf(rel.dot(r_dir)) < hw:
				speed_bump_cd[kid] = 1.1
				k.apply_speedbump_hop(4.8)
				if k.is_player and absf(k.forward_speed) > 16.0:
					spawn_comic_popup(parent, k.global_position, "POLISI TIDUR!!", Color(1.0, 0.88, 0.15))
					ComedySfx.play(k, "bonk", -7.0)


func _tick_item_boxes(delta: float) -> void:
	const ITEMS := ["banana", "rocket", "water_bomb", "oil", "shield"]
	for b in item_boxes:
		var node: Node3D = b["node"]
		if float(b["cooldown"]) > 0.0:
			b["cooldown"] = float(b["cooldown"]) - delta
			if float(b["cooldown"]) <= 0.0:
				node.visible = true
			continue
		node.rotate_y(delta * 2.2)
		node.position.y = float(b["pos"].y) + 0.7 + sin(Time.get_ticks_msec() * 0.004) * 0.18
		for k in active_karts:
			if is_instance_valid(k) and k.global_position.distance_to(b["pos"]) < 2.2:
				if k.held_item == "":
					k.give_powerup(ITEMS[randi() % ITEMS.size()])
					b["cooldown"] = 4.5
					node.visible = false
					break


func _tick_hazards(parent: Node3D, delta: float) -> void:
	var to_remove: Array = []
	for h in active_hazards:
		h["arm"] = max(0.0, float(h["arm"]) - delta)
		if float(h["arm"]) > 0.0:
			continue
		var node: Node3D = h["node"]
		if not is_instance_valid(node):
			to_remove.append(h)
			continue
		for k in active_karts:
			if not is_instance_valid(k):
				continue
			if k.global_position.distance_to(node.global_position) < float(h["radius"]):
				if h["kind"] == "banana":
					k.apply_spinout(1.35)
					spawn_comic_popup(parent, k.global_position, "KEPLESET PISANG!", Color(1.0, 0.92, 0.15))
					if k.is_player:
						ComedySfx.play(k, "slip", -5.0)
						k.add_camera_shake(0.45)
					node.queue_free()
					to_remove.append(h)
					break
				elif h["kind"] == "oil":
					k.apply_oil_slip(2.2)
					spawn_comic_popup(parent, k.global_position, "LICIN OLI!!", Color(0.7, 0.85, 1.0))
					if k.is_player:
						ComedySfx.play(k, "slip", -7.0)
	for r in to_remove:
		active_hazards.erase(r)


func _tick_projectiles(parent: Node3D, delta: float) -> void:
	var to_remove: Array = []
	for p in active_projectiles:
		p["life"] = float(p["life"]) - delta
		var node: Node3D = p["node"]
		if not is_instance_valid(node) or float(p["life"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			to_remove.append(p)
			continue
		var vel: Vector3 = p["vel"]
		vel.y -= float(p["gravity"]) * delta
		p["vel"] = vel
		node.global_position += vel * delta
		if p["kind"] == "water_bomb" and node.global_position.y <= 0.45:
			# Splash blast radius!
			spawn_flying_chaos_burst(parent, node.global_position, true)
			spawn_comic_popup(parent, node.global_position, "BYUR!! BASAH KUYUP!", Color(0.25, 0.85, 1.0))
			ComedySfx.play(parent, "boom", -6.0)
			for k in active_karts:
				if is_instance_valid(k) and k != p["owner"] and k.global_position.distance_to(node.global_position) < 6.5:
					var dir: Vector3 = (k.global_position - node.global_position).normalized()
					k.apply_knockback_flip(dir * 16.0 + Vector3(0, 10.0, 0), p["owner"])
					if k.is_player: k.add_camera_shake(0.65)
			node.queue_free()
			to_remove.append(p)
			continue
		# Direct hit check
		for k in active_karts:
			if is_instance_valid(k) and k != p["owner"] and k.global_position.distance_to(node.global_position) < 2.2:
				var dir := vel.normalized()
				k.apply_knockback_flip(dir * 18.0 + Vector3(0, 11.0, 0), p["owner"])
				spawn_flying_chaos_burst(parent, k.global_position, true)
				spawn_comic_popup(parent, k.global_position, "DUAAR!! TERBANG!", Color(1.0, 0.35, 0.12))
				ComedySfx.play(parent, "boom", -5.0)
				if k.is_player: k.add_camera_shake(0.75)
				node.queue_free()
				to_remove.append(p)
				break
	for r in to_remove:
		active_projectiles.erase(r)


func _tick_dynamic_obstacles(parent: Node3D, delta: float) -> void:
	for ob in dynamic_obstacles:
		var node: Node3D = ob["node"]
		if not is_instance_valid(node):
			continue
		ob["hit_cd"] = max(0.0, float(ob["hit_cd"]) - delta)
		var dist: float = max(ob["a"].distance_to(ob["b"]), 1.0)
		ob["t"] = float(ob["t"]) + float(ob["dir"]) * (float(ob["speed"]) / dist) * delta
		if float(ob["t"]) >= 1.0:
			ob["t"] = 1.0; ob["dir"] = -1.0
		elif float(ob["t"]) <= 0.0:
			ob["t"] = 0.0; ob["dir"] = 1.0
		var prev_pos := node.position
		node.position = ob["a"].lerp(ob["b"], float(ob["t"]))
		var move_vec := node.position - prev_pos
		if move_vec.length() > 0.001:
			node.look_at(node.global_position + move_vec.normalized(), Vector3.UP)
		if ob["kind"] == "chicken":
			node.position.y = abs(sin(Time.get_ticks_msec() * 0.02)) * 0.35

		if float(ob["hit_cd"]) <= 0.0:
			for k in active_karts:
				if is_instance_valid(k) and k.global_position.distance_to(node.global_position) < float(ob["radius"]) + 1.1:
					ob["hit_cd"] = 1.2
					if ob["kind"] == "chicken":
						k.apply_spinout(0.95)
						spawn_comic_popup(parent, node.global_position, "PETOK-PETOK!!", Color(1.0, 0.95, 0.35))
						if k.is_player or _near_player(node.global_position, 28.0):
							ComedySfx.play(parent, "chicken_scream", -3.0 if k.is_player else -8.0, randf_range(0.92, 1.12))
						if k.is_player:
							k.add_camera_shake(0.30)
					else:
						var push: Vector3 = (k.global_position - node.global_position).normalized()
						k.apply_knockback_flip(push * 12.0 + Vector3(0, 7.0, 0))
						spawn_comic_popup(parent, node.global_position, "WADUH! NABRAK!", Color(1.0, 0.45, 0.15))
						if k.is_player or _near_player(node.global_position, 28.0):
							ComedySfx.play(parent, "crash_heavy", -3.5 if k.is_player else -9.0, randf_range(0.90, 1.08))
						if k.is_player:
							k.add_camera_shake(0.55)
					spawn_flying_chaos_burst(parent, node.global_position, false)
					break


func _near_player(pos: Vector3, max_dist: float) -> bool:
	for k in active_karts:
		if is_instance_valid(k) and k.is_player:
			return k.global_position.distance_to(pos) <= max_dist
	return false


func _tick_pedestrians(parent: Node3D, delta: float) -> void:
	const PANIC_LINES := ["AWAAAS!!", "MINGGIIIR!!", "WADUUUH!!", "NGEBUT AMAT!!"]
	ped_scream_global_cd = maxf(0.0, ped_scream_global_cd - delta)
	for ped in pedestrians:
		var node: Node3D = ped["node"]
		if not is_instance_valid(node):
			continue
		ped["scream_cd"] = maxf(0.0, float(ped["scream_cd"]) - delta)
		var closest_kart: KartController = null
		var closest_d := 13.5
		for k in active_karts:
			if is_instance_valid(k):
				var d: float = k.global_position.distance_to(node.global_position)
				if d < closest_d:
					closest_d = d
					closest_kart = k
		if closest_kart != null:
			if float(ped["flee_timer"]) <= 0.1 and closest_kart.is_player:
				spawn_comic_popup(parent, node.global_position, PANIC_LINES[randi() % PANIC_LINES.size()], Color(1.0, 1.0, 0.9))
			if float(ped["scream_cd"]) <= 0.0 and ped_scream_global_cd <= 0.0 and (closest_kart.is_player or _near_player(node.global_position, 22.0)):
				ped["scream_cd"] = 3.2
				ped_scream_global_cd = 0.65
				var scream_sfx := "ped_scream_female" if bool(ped["is_female"]) else "ped_scream_male"
				ComedySfx.play(parent, scream_sfx, -4.5 if closest_kart.is_player else -9.0, randf_range(0.92, 1.10))
			ped["flee_timer"] = 2.2
			var away := node.global_position - closest_kart.global_position
			away.y = 0.0
			ped["flee_dir"] = (away.normalized() * 0.65 + ped["safe_dir"] * 0.35).normalized()

		if float(ped["flee_timer"]) > 0.0:
			ped["flee_timer"] = float(ped["flee_timer"]) - delta
			var fdir: Vector3 = ped["flee_dir"]
			var dist_from_home := node.position.distance_to(ped["home"])
			if dist_from_home < 7.5:
				node.position += fdir * 6.8 * delta
			node.look_at(node.global_position + fdir, Vector3.UP)
			ped["phase"] = float(ped["phase"]) + delta * 18.0
			var swing := sin(float(ped["phase"]))
			if ped["leg_l"]: ped["leg_l"].rotation.x = swing * 0.85
			if ped["leg_r"]: ped["leg_r"].rotation.x = -swing * 0.85
			# Panic arms raised up!
			if ped["arm_l"]: ped["arm_l"].rotation.x = -2.4 + swing * 0.35
			if ped["arm_r"]: ped["arm_r"].rotation.x = -2.4 - swing * 0.35
		else:
			# Gently walk back toward sidewalk home
			var to_home: Vector3 = ped["home"] - node.position
			to_home.y = 0.0
			if to_home.length() > 0.4:
				var d := to_home.normalized()
				node.position += d * 2.2 * delta
				node.look_at(node.global_position + d, Vector3.UP)
				ped["phase"] = float(ped["phase"]) + delta * 8.0
				var sw := sin(float(ped["phase"]))
				if ped["leg_l"]: ped["leg_l"].rotation.x = sw * 0.4
				if ped["leg_r"]: ped["leg_r"].rotation.x = -sw * 0.4
			else:
				if ped["leg_l"]: ped["leg_l"].rotation.x = 0.0
				if ped["leg_r"]: ped["leg_r"].rotation.x = 0.0
			if ped["arm_l"]: ped["arm_l"].rotation.x = 0.0
			if ped["arm_r"]: ped["arm_r"].rotation.x = 0.0


func _tick_flying_debris(delta: float) -> void:
	var dead: Array = []
	for d in flying_debris:
		d["life"] = float(d["life"]) - delta
		var node: Node3D = d["node"]
		if not is_instance_valid(node) or float(d["life"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			dead.append(d)
			continue
		var vel: Vector3 = d["vel"]
		vel.y -= float(d["gravity"]) * delta
		if float(d["flutter"]) > 0.0:
			d["flutter"] = float(d["flutter"]) + delta * 7.0
			vel.x += sin(float(d["flutter"])) * 2.5 * delta
			vel.z += cos(float(d["flutter"])) * 2.5 * delta
			vel.y = max(vel.y, -1.8) # Fluttering paper glides gently!
		d["vel"] = vel
		node.position += vel * delta
		if node.position.y < 0.12:
			node.position.y = 0.12
			vel.y = abs(vel.y) * 0.35
			vel.x *= 0.7
			vel.z *= 0.7
			d["vel"] = vel
		var sp: Vector3 = d["spin"]
		node.rotation += sp * delta
	for x in dead:
		flying_debris.erase(x)


func _tick_comic_popups(delta: float) -> void:
	var dead: Array = []
	for p in comic_popups:
		p["age"] = float(p["age"]) + delta
		var lbl: Label3D = p["node"]
		if not is_instance_valid(lbl) or float(p["age"]) >= float(p["life"]):
			if is_instance_valid(lbl):
				lbl.queue_free()
			dead.append(p)
			continue
		var u: float = float(p["age"]) / float(p["life"])
		lbl.position.y += 2.6 * delta
		var sc: float = 1.0 + sin(minf(u * 4.0, 1.0) * PI * 0.5) * 0.35
		lbl.scale = Vector3(sc, sc, sc)
		lbl.modulate.a = 1.0 - maxf(0.0, (u - 0.55) / 0.45)
	for d in dead:
		comic_popups.erase(d)


func _tick_smashed_props_check(parent: Node3D) -> void:
	const SMASH_QUIPS := {
		"cardboard": "KARDUS TERBANG!",
		"gerobak": "GEROBAK AMBYAR!!",
		"pot": "POT PAK RT PECAH!",
		"pole": "TIANG MIRING!!",
		"fence": "PAGAR JEBOL!",
		"barrel": "TONG GLUNDUNG!",
		"cone": "CONE TERBANG!!",
		"motorcycle": "MOTOR PARKIR AMBRUK!",
		"bicycle": "SEPEDA KESENGGOL!"
	}
	for child in parent.get_children():
		if child is RigidBody3D and child.has_meta("prop_kind") and not bool(child.get_meta("smashed")):
			if child.linear_velocity.length() > 4.2:
				child.set_meta("smashed", true)
				var kind := str(child.get_meta("prop_kind"))
				spawn_flying_chaos_burst(parent, child.global_position, kind == "cardboard" or kind == "gerobak")
				spawn_comic_popup(parent, child.global_position, SMASH_QUIPS.get(kind, "BRAAK!!"), Color(1.0, 0.72, 0.15))
				var nearest: KartController = null
				var best_d := 12.0
				for k in active_karts:
					if is_instance_valid(k):
						var d: float = k.global_position.distance_to(child.global_position)
						if d < best_d:
							best_d = d
							nearest = k
				if nearest != null:
					nearest.nitro_energy = min(100.0, nearest.nitro_energy + 10.0)
					if nearest.is_player:
						ComedySfx.play(parent, "smash", -5.0)
						nearest.add_camera_shake(0.32)
					emit_signal("prop_smashed", kind, child.global_position, nearest)
