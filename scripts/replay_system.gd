extends Node
class_name ReplaySystem

var frames: Array = []
var record_timer: float = 0.0
var is_recording: bool = false
var is_playing: bool = false
var play_time: float = 0.0
var duration: float = 0.0
var cam_angle_idx: int = 0
var cam_switch_timer: float = 0.0

var tracked_karts: Array = []
var replay_camera: Camera3D = null
var trackside_points: Array[Vector3] = [
	Vector3(12.0, 5.5, 16.0),
	Vector3(-28.0, 6.5, -45.0),
	Vector3(46.0, 7.0, -52.0),
	Vector3(0.0, 11.0, 6.0)
]


func setup(karts: Array, cam: Camera3D, points: Array[Vector3] = []) -> void:
	tracked_karts = karts
	replay_camera = cam
	if points.size() > 0:
		trackside_points = points
	frames.clear()
	record_timer = 0.0
	play_time = 0.0
	duration = 0.0
	is_recording = true
	is_playing = false


func tick(delta: float) -> void:
	if is_recording:
		record_timer += delta
		duration += delta
		if record_timer >= 0.066: # ~15 FPS lightweight transform snapshots
			record_timer = 0.0
			var snap: Array = []
			for k in tracked_karts:
				if is_instance_valid(k):
					snap.append({
						"pos": k.global_position,
						"rot": k.global_rotation,
						"vis": k.visible
					})
			frames.append({"t": duration, "karts": snap})
			if frames.size() > 1400:
				frames.pop_front()
	elif is_playing and frames.size() >= 2 and replay_camera != null:
		play_time += delta
		cam_switch_timer += delta
		if cam_switch_timer >= 4.2:
			cam_switch_timer = 0.0
			cam_angle_idx = (cam_angle_idx + 1) % 3

		var start_t: float = frames[0]["t"]
		var end_t: float = frames[-1]["t"]
		var span: float = max(end_t - start_t, 0.1)
		var sample_t: float = start_t + fmod(play_time, span)

		var idx := 0
		for i in range(frames.size() - 1):
			if frames[i + 1]["t"] >= sample_t:
				idx = i
				break
		var f0: Dictionary = frames[idx]
		var f1: Dictionary = frames[min(idx + 1, frames.size() - 1)]
		var alpha: float = clamp((sample_t - float(f0["t"])) / max(float(f1["t"]) - float(f0["t"]), 0.001), 0.0, 1.0)

		for i in range(min(tracked_karts.size(), f0["karts"].size())):
			var k = tracked_karts[i]
			if is_instance_valid(k):
				var p0: Vector3 = f0["karts"][i]["pos"]
				var p1: Vector3 = f1["karts"][i]["pos"]
				var r0: Vector3 = f0["karts"][i]["rot"]
				var r1: Vector3 = f1["karts"][i]["rot"]
				k.global_position = p0.lerp(p1, alpha)
				k.global_rotation = Vector3(
					lerp_angle(r0.x, r1.x, alpha),
					lerp_angle(r0.y, r1.y, alpha),
					lerp_angle(r0.z, r1.z, alpha)
				)
				k.visible = f0["karts"][i]["vis"]

		if tracked_karts.size() > 0 and is_instance_valid(tracked_karts[0]):
			var focus = tracked_karts[0]
			var focus_pos: Vector3 = focus.global_position
			var fwd: Vector3 = -focus.global_basis.z
			var target_cam_pos: Vector3
			if cam_angle_idx == 0:
				# Low cinematic hero chase
				target_cam_pos = focus_pos - fwd * 6.2 + Vector3(0.0, 2.4, 0.0) + focus.global_basis.x * 1.4
			elif cam_angle_idx == 1:
				# Dramatic 360 orbit around action
				var ang := play_time * 0.9
				target_cam_pos = focus_pos + Vector3(cos(ang) * 7.5, 3.6, sin(ang) * 7.5)
			else:
				# Trackside broadcast camera (nearest point)
				var best_pt: Vector3 = trackside_points[0]
				var best_d := 999999.0
				for pt in trackside_points:
					var d := pt.distance_to(focus_pos)
					if d < best_d:
						best_d = d
						best_pt = pt
				target_cam_pos = best_pt
			replay_camera.global_position = replay_camera.global_position.lerp(target_cam_pos, clamp(delta * 4.5, 0.0, 1.0))
			replay_camera.look_at(focus_pos + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func start_replay() -> void:
	is_recording = false
	is_playing = true
	play_time = 0.0
	cam_angle_idx = 0
	cam_switch_timer = 0.0
	for k in tracked_karts:
		if is_instance_valid(k):
			k.set_physics_process(false)
			k.set_process(false)
	if replay_camera != null:
		replay_camera.current = true


func cycle_camera_angle() -> void:
	cam_angle_idx = (cam_angle_idx + 1) % 3
	cam_switch_timer = 0.0
