class_name Player
extends Node3D
## Kinematic endless-runner character with a fully procedural body.
## No imported models: the runner is built from boxes with two-segment
## arms/legs, animated in code (run cycle, jump tuck, slide, fall).

signal died

const LANE_X := [-2.2, 0.0, 2.2]
const GRAVITY := 34.0
const JUMP_VEL := 9.8
const LANE_SPEED := 17.0 # m/s sideways -> a 2.2 m lane switch takes ~0.13 s

var lane := 1
var target_x := 0.0
var vy := 0.0
var grounded := true
var sliding := false
var slide_timer := 0.0
var pending_slide := false
var dead := false

var speed := 11.0
var max_speed := 30.0
var ramp := 0.33
var speed_locked := false
var distance := 0.0
var x_vel := 0.0

var run_phase := 0.0
var _air_w := 0.0
var _slide_w := 0.0
var _dead_w := 0.0

var visual: Node3D
var _thigh_l: Node3D
var _shin_l: Node3D
var _thigh_r: Node3D
var _shin_r: Node3D
var _arm_l: Node3D
var _fore_l: Node3D
var _arm_r: Node3D
var _fore_r: Node3D
var _torso: Node3D

var _mats := {}

# ---------------------------------------------------------------- materials
func _mat(color: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var key := str(color) + "|" + str(rough) + "|" + str(metallic)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	_mats[key] = m
	return m

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- body build
func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var jacket := _mat(Color(0.92, 0.42, 0.10)) # warm orange jacket
	var jacket_dark := _mat(Color(0.75, 0.30, 0.06))
	var pants := _mat(Color(0.13, 0.16, 0.30)) # deep blue trousers
	var skin := _mat(Color(0.72, 0.50, 0.36), 0.65)
	var cap_red := _mat(Color(0.78, 0.10, 0.14))
	var shoe := _mat(Color(0.92, 0.92, 0.94), 0.6)
	var pack := _mat(Color(0.05, 0.55, 0.55)) # teal backpack

	# ---- legs (hip pivots on the visual root) ----
	_thigh_l = _make_leg(-0.13, pants, skin, shoe)
	_thigh_r = _make_leg(0.13, pants, skin, shoe)
	_shin_l = _thigh_l.get_node("Knee") as Node3D
	_shin_r = _thigh_r.get_node("Knee") as Node3D

	# ---- torso pivot (hips) ----
	_torso = Node3D.new()
	_torso.name = "Torso"
	_torso.position = Vector3(0, 0.98, 0)
	visual.add_child(_torso)
	_box(_torso, Vector3(0.44, 0.22, 0.27), Vector3(0, 0.02, 0), pants) # pelvis
	_box(_torso, Vector3(0.52, 0.62, 0.29), Vector3(0, 0.40, 0), jacket) # chest
	_box(_torso, Vector3(0.40, 0.50, 0.16), Vector3(0, 0.40, 0.225), pack) # backpack

	# head + cap
	var head := Node3D.new()
	head.position = Vector3(0, 0.78, 0)
	_torso.add_child(head)
	_box(head, Vector3(0.34, 0.36, 0.34), Vector3(0, 0.18, 0), skin)
	_box(head, Vector3(0.38, 0.10, 0.38), Vector3(0, 0.40, 0), cap_red)
	_box(head, Vector3(0.36, 0.05, 0.22), Vector3(0, 0.35, -0.27), cap_red) # brim (faces -Z)

	# ---- arms (shoulder pivots on the torso) ----
	_arm_l = _make_arm(-0.335, jacket_dark, skin)
	_arm_r = _make_arm(0.335, jacket_dark, skin)
	_fore_l = _arm_l.get_node("Elbow") as Node3D
	_fore_r = _arm_r.get_node("Elbow") as Node3D

func _make_leg(x: float, pants: Material, skin: Material, shoe: Material) -> Node3D:
	var hip := Node3D.new()
	hip.name = "Hip"
	hip.position = Vector3(x, 0.96, 0)
	visual.add_child(hip)
	_box(hip, Vector3(0.17, 0.52, 0.18), Vector3(0, -0.24, 0), pants)
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(0, -0.50, 0)
	hip.add_child(knee)
	_box(knee, Vector3(0.14, 0.46, 0.15), Vector3(0, -0.21, 0), skin)
	_box(knee, Vector3(0.16, 0.09, 0.31), Vector3(0, -0.45, -0.05), shoe)
	return hip

func _make_arm(x: float, sleeve: Material, skin: Material) -> Node3D:
	var sh := Node3D.new()
	sh.name = "Shoulder"
	sh.position = Vector3(x, 0.64, 0)
	_torso.add_child(sh)
	_box(sh, Vector3(0.14, 0.48, 0.14), Vector3(0, -0.21, 0), sleeve)
	var el := Node3D.new()
	el.name = "Elbow"
	el.position = Vector3(0, -0.46, 0)
	sh.add_child(el)
	_box(el, Vector3(0.12, 0.42, 0.12), Vector3(0, -0.19, 0), skin)
	return sh

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	_build_body()

func reset() -> void:
	position = Vector3.ZERO
	lane = 1
	target_x = 0.0
	vy = 0.0
	grounded = true
	sliding = false
	slide_timer = 0.0
	pending_slide = false
	dead = false
	speed = 11.0
	distance = 0.0
	run_phase = 0.0
	_air_w = 0.0
	_slide_w = 0.0
	_dead_w = 0.0
	if visual:
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO

# ---------------------------------------------------------------- commands
func cmd_left() -> void:
	if dead:
		return
	if lane > 0:
		lane -= 1
		target_x = LANE_X[lane]

func cmd_right() -> void:
	if dead:
		return
	if lane < 2:
		lane += 1
		target_x = LANE_X[lane]

func cmd_jump() -> void:
	if dead:
		return
	if sliding:
		sliding = false
		slide_timer = 0.0
	if grounded:
		vy = JUMP_VEL
		grounded = false

func cmd_slide() -> void:
	if dead:
		return
	if not grounded:
		vy = min(vy, -22.0) # slam down, then slide on landing
		pending_slide = true
	else:
		_start_slide()

func _start_slide() -> void:
	sliding = true
	slide_timer = 0.75

func die() -> void:
	if dead:
		return
	dead = true
	emit_signal("died")

func is_slide_effective() -> bool:
	return sliding and grounded

# ---------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	if dead:
		speed = move_toward(speed, 0.0, delta * 26.0)
		position.z -= speed * delta
		distance += speed * delta
		return

	if not speed_locked:
		speed = min(max_speed, speed + ramp * delta)
	position.z -= speed * delta
	distance += speed * delta

	var old_x := position.x
	position.x = move_toward(position.x, target_x, LANE_SPEED * delta)
	x_vel = (position.x - old_x) / max(delta, 0.0001)

	if not grounded:
		vy -= GRAVITY * delta
		position.y += vy * delta
		if position.y <= 0.0:
			position.y = 0.0
			vy = 0.0
			grounded = true
			if pending_slide:
				pending_slide = false
				_start_slide()

	if sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			sliding = false

# ---------------------------------------------------------------- animation
func _process(delta: float) -> void:
	if not visual:
		return
	var stride := (5.0 + speed * 0.62) * (1.0 if grounded else 0.35)
	if not dead:
		run_phase += delta * stride

	_air_w = move_toward(_air_w, 0.0 if grounded else 1.0, delta * 9.0)
	_slide_w = move_toward(_slide_w, 1.0 if sliding else 0.0, delta * 11.0)
	_dead_w = move_toward(_dead_w, 1.0 if dead else 0.0, delta * 4.5)

	var s := sin(run_phase)
	var c := cos(run_phase)

	# --- run cycle ---
	var th_l := s * 0.95
	var th_r := -s * 0.95
	var sh_l := 0.15 + 1.15 * pow(maxf(0.0, sin(run_phase - 2.0)), 1.5)
	var sh_r := 0.15 + 1.15 * pow(maxf(0.0, sin(run_phase + PI - 2.0)), 1.5)
	var ar_l := -s * 0.75
	var ar_r := s * 0.75
	var fo_l := -0.85 + c * 0.18
	var fo_r := -0.85 - c * 0.18

	# --- jump pose (blend by air weight) ---
	th_l = lerpf(th_l, -1.0, _air_w)
	sh_l = lerpf(sh_l, 1.45, _air_w)
	th_r = lerpf(th_r, 0.55, _air_w)
	sh_r = lerpf(sh_r, 0.85, _air_w)
	ar_l = lerpf(ar_l, -2.35, _air_w)
	ar_r = lerpf(ar_r, -1.15, _air_w)
	fo_l = lerpf(fo_l, -0.35, _air_w)
	fo_r = lerpf(fo_r, -0.55, _air_w)

	# --- slide pose (blend by slide weight) ---
	th_l = lerpf(th_l, -1.25, _slide_w)
	th_r = lerpf(th_r, -1.10, _slide_w)
	sh_l = lerpf(sh_l, 0.12, _slide_w)
	sh_r = lerpf(sh_r, 0.20, _slide_w)
	ar_l = lerpf(ar_l, 0.70, _slide_w)
	ar_r = lerpf(ar_r, 0.70, _slide_w)
	fo_l = lerpf(fo_l, -0.25, _slide_w)
	fo_r = lerpf(fo_r, -0.25, _slide_w)

	_thigh_l.rotation.x = th_l
	_shin_l.rotation.x = sh_l
	_thigh_r.rotation.x = th_r
	_shin_r.rotation.x = sh_r
	_arm_l.rotation.x = ar_l
	_fore_l.rotation.x = fo_l
	_arm_r.rotation.x = ar_r
	_fore_r.rotation.x = fo_r

	# --- whole-body feel: bob, lean, lane tilt, slide drop, death fall ---
	var bob := (0.03 + absf(s) * 0.07) * (1.0 - _air_w) * (1.0 - _slide_w)
	visual.position.y = bob - 0.52 * _slide_w
	var lean := (-0.10 - speed * 0.0025) * (1.0 - _slide_w) + 0.85 * _slide_w
	visual.rotation.x = lerpf(lean, 1.35, _dead_w)
	visual.rotation.z = clampf(-x_vel * 0.014, -0.30, 0.30) * (1.0 - _dead_w)
	_torso.rotation.x = -0.06 * (1.0 - _slide_w)
