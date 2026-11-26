extends Node

const KART_PRESETS := [
	{
		"id": "bajaj_turbo",
		"name": "Bajaj Turbo RT",
		"desc": "Seimbang dan lincah di gang sempit",
		"max_speed": 31.0,
		"accel": 22.0,
		"handling": 2.85,
		"drift_charge_rate": 42.0,
		"mass": 1.0,
		"default_color": Color(0.95, 0.38, 0.08)
	},
	{
		"id": "vespa_modif",
		"name": "Vespa Modif Drift",
		"desc": "Drift tajam dan pengisian nitro paling cepat",
		"max_speed": 32.5,
		"accel": 21.0,
		"handling": 3.2,
		"drift_charge_rate": 52.0,
		"mass": 0.85,
		"default_color": Color(0.12, 0.62, 0.82)
	},
	{
		"id": "gerobak_roket",
		"name": "Gerobak Roket",
		"desc": "Berat, jago menghantam lawan dan objek pasar",
		"max_speed": 29.8,
		"accel": 19.5,
		"handling": 2.45,
		"drift_charge_rate": 38.0,
		"mass": 1.45,
		"default_color": Color(0.76, 0.16, 0.16)
	}
]

const BODY_COLORS := [
	{"name": "Oranye Bajaj", "color": Color(0.95, 0.38, 0.08)},
	{"name": "Biru Bajaj Gas", "color": Color(0.11, 0.56, 0.88)},
	{"name": "Hijau Ojol", "color": Color(0.11, 0.68, 0.32)},
	{"name": "Merah Merdeka", "color": Color(0.86, 0.14, 0.16)},
	{"name": "Kuning Angkot", "color": Color(0.96, 0.76, 0.10)},
	{"name": "Ungu Pasar Malam", "color": Color(0.56, 0.22, 0.78)}
]

const SPOILER_STYLES := ["Standar", "Sayap Turbo", "Rak Keranjang"]
const WHEEL_STYLES := ["Jalan Raya", "Ban Balap Lebar", "Ban Offroad Kampung"]

const AI_ROSTER := [
	{"name": "Bang Jago", "personality": "aggressive", "color": Color(0.85, 0.15, 0.15), "speed_mult": 1.02, "aggression": 0.92, "shortcut_chance": 0.65},
	{"name": "Mbak Sari", "personality": "drifter", "color": Color(0.12, 0.68, 0.32), "speed_mult": 1.00, "aggression": 0.45, "shortcut_chance": 0.50},
	{"name": "Kang Bakso", "personality": "rammer", "color": Color(0.92, 0.72, 0.10), "speed_mult": 0.97, "aggression": 0.85, "shortcut_chance": 0.25},
	{"name": "Mas Ojol", "personality": "opportunist", "color": Color(0.08, 0.74, 0.44), "speed_mult": 1.01, "aggression": 0.55, "shortcut_chance": 0.85},
	{"name": "Pak RT", "personality": "balanced", "color": Color(0.14, 0.45, 0.85), "speed_mult": 0.98, "aggression": 0.40, "shortcut_chance": 0.35},
	{"name": "Neng Geulis", "personality": "speedster", "color": Color(0.86, 0.26, 0.64), "speed_mult": 1.03, "aggression": 0.35, "shortcut_chance": 0.60},
	{"name": "Si Udin", "personality": "wildcard", "color": Color(0.58, 0.24, 0.82), "speed_mult": 0.99, "aggression": 0.78, "shortcut_chance": 0.75}
]

const PROFILE_PATH := "user://player_profile.cfg"

var player_name: String = "Pembalap"
var selected_preset_idx: int = 0
var selected_color_idx: int = 0
var selected_spoiler_idx: int = 1
var selected_wheel_idx: int = 0
var engine_level: int = 1 # 0..2
var nitro_level: int = 1  # 0..2
var laps_count: int = 3


func _ready() -> void:
	_load_profile()


func get_clean_player_name() -> String:
	var cleaned := player_name.strip_edges()
	if cleaned.is_empty():
		return "Pembalap"
	return cleaned.substr(0, 20)


func set_player_name(new_name: String) -> void:
	player_name = new_name.strip_edges().substr(0, 20)
	_save_profile()


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		player_name = str(cfg.get_value("player", "name", "Pembalap")).strip_edges().substr(0, 20)


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", get_clean_player_name())
	cfg.save(PROFILE_PATH)


func get_player_kart_config() -> Dictionary:
	var preset: Dictionary = KART_PRESETS[selected_preset_idx]
	var body_color: Color = BODY_COLORS[selected_color_idx]["color"]
	var wheel_scale := 1.0
	var handling_bonus := 0.0
	var speed_bonus := float(engine_level) * 1.4
	if selected_wheel_idx == 1:
		wheel_scale = 1.12
		handling_bonus = 0.22
	elif selected_wheel_idx == 2:
		wheel_scale = 1.22
		speed_bonus += 0.4

	var nitro_mult := 1.0 + float(nitro_level) * 0.18
	var spoiler_handling := 0.18 if selected_spoiler_idx == 1 else 0.0

	return {
		"name": get_clean_player_name(),
		"preset_id": preset["id"],
		"body_color": body_color,
		"spoiler_idx": selected_spoiler_idx,
		"wheel_idx": selected_wheel_idx,
		"wheel_scale": wheel_scale,
		"max_speed": float(preset["max_speed"]) + speed_bonus,
		"accel": float(preset["accel"]) + float(engine_level) * 1.6,
		"handling": float(preset["handling"]) + handling_bonus + spoiler_handling,
		"drift_charge_rate": float(preset["drift_charge_rate"]) * nitro_mult,
		"mass": float(preset["mass"]) + (0.15 if selected_spoiler_idx == 2 else 0.0),
		"nitro_power": 13.5 + float(nitro_level) * 2.2
	}
