class_name TrackManager
extends Node3D
## Recycled 3-lane railway world. Each segment is 24 m; 9 segments give
## ~216 m of visible track. Obstacles and coins are children of segments,
## stored as data dicts so collision checks are cheap and deterministic
## (no physics bodies — reliable headless autotest).

const LANE_X := [-2.2, 0.0, 2.2]
const SEG_LEN := 24.0
const SEG_COUNT := 9

var player: Player = null
var test_mode := false

var segments: Array = [] # {node: Node3D, z: float, obstacles: Array, coins: Array}
var rng := RandomNumberGenerator.new()
var _mats := {}

# ---------------------------------------------------------------- materials
func _mat(color: Color, rough := 0.85, metallic := 0.0, emission := Color(0, 0, 0), e_energy := 0.0) -> StandardMaterial3D:
	var key := str(color) + "|" + str(rough) + "|" + str(metallic) + "|" + str(emission)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if e_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = e_energy
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

# ---------------------------------------------------------------- build
func _ready() -> void:
	rng.randomize()
	for i in range(SEG_COUNT):
		var z := 14.0 - float(i) * SEG_LEN
		var node := _build_segment()
		node.position.z = z
		add_child(node)
		var seg := {"node": node, "z": z, "obstacles": [], "coins": []}
		segments.append(seg)
		if i >= 2:
			_spawn_pattern(seg, false)
		elif i == 1:
			_place_coin_line(seg, 1, -8.0, 5, 2.2, 0.0)

func reset_world() -> void:
	for i in range(SEG_COUNT):
		var seg: Dictionary = segments[i]
		seg.z = 14.0 - float(i) * SEG_LEN
		(seg.node as Node3D).position.z = seg.z
		_clear_contents(seg)
		if test_mode:
			continue
		if i >= 2:
			_spawn_pattern(seg, false)
		elif i == 1:
			_place_coin_line(seg, 1, -8.0, 5, 2.2, 0.0)

func _build_segment() -> Node3D:
	var root := Node3D.new()
	var ballast := _mat(Color(0.13, 0.12, 0.14))
	var dirt := _mat(Color(0.24, 0.19, 0.15))
	var steel := _mat(Color(0.62, 0.64, 0.68), 0.35, 0.9)
	var wood := _mat(Color(0.25, 0.17, 0.11))
	var concrete := _mat(Color(0.36, 0.34, 0.33))

	_box(root, Vector3(70, 0.1, SEG_LEN), Vector3(0, -0.09, -SEG_LEN * 0.5), dirt)
	_box(root, Vector3(15, 0.12, SEG_LEN), Vector3(0, 0.0, -SEG_LEN * 0.5), ballast)

	# rails: two per track
	for lx in LANE_X:
		for off in [-0.75, 0.75]:
			_box(root, Vector3(0.09, 0.14, SEG_LEN), Vector3(lx + off, 0.13, -SEG_LEN * 0.5), steel)

	# sleepers via MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := BoxMesh.new()
	sm.size = Vector3(8.6, 0.07, 0.55)
	sm.material = wood
	mm.mesh = sm
	mm.instance_count = 16
	for i in range(16):
		var t := Transform3D(Basis(), Vector3(0, 0.045, -1.2 - float(i) * 1.5))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)

	# side walls
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.4, 1.15, SEG_LEN), Vector3(side * 7.8, 0.6, -SEG_LEN * 0.5), concrete)

	# building silhouettes (deterministic-ish per segment via rng is fine)
	var palette := [Color(0.12, 0.11, 0.22), Color(0.17, 0.11, 0.09), Color(0.09, 0.14, 0.24), Color(0.19, 0.14, 0.10)]
	for side in [-1.0, 1.0]:
		for j in range(3):
			var h := rng.randf_range(5.0, 18.0)
			var w := rng.randf_range(6.0, 9.0)
			var bx: float = side * rng.randf_range(12.5, 17.0)
			var bz := -3.0 - float(j) * 8.0 + rng.randf_range(-1.5, 1.5)
			var col: Color = palette[rng.randi_range(0, palette.size() - 1)]
			_box(root, Vector3(w, h, 6.0), Vector3(bx, h * 0.5 - 0.1, bz), _mat(col))
	return root

# ---------------------------------------------------------------- obstacles
func _make_train(parent: Node, lane: int, lz: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(LANE_X[lane], 0, lz)
	parent.add_child(root)
	var body := _mat(Color(0.48, 0.09, 0.11), 0.55, 0.25)
	var dark := _mat(Color(0.08, 0.08, 0.10), 0.7)
	var glass := _mat(Color(0.05, 0.09, 0.14), 0.25, 0.6)
	var lamp := _mat(Color(1, 0.9, 0.6), 0.4, 0.0, Color(1, 0.85, 0.45), 2.5)
	_box(root, Vector3(2.7, 2.9, 12.0), Vector3(0, 1.75, 0), body)
	_box(root, Vector3(2.8, 0.35, 12.1), Vector3(0, 3.35, 0), dark) # roof
	_box(root, Vector3(2.75, 0.8, 12.05), Vector3(0, 0.45, 0), dark) # under-skirt
	_box(root, Vector3(2.2, 0.9, 0.12), Vector3(0, 2.45, 6.03), glass) # windshield (faces player)
	_box(root, Vector3(0.34, 0.34, 0.1), Vector3(-0.8, 1.05, 6.03), lamp)
	_box(root, Vector3(0.34, 0.34, 0.1), Vector3(0.8, 1.05, 6.03), lamp)
	_box(root, Vector3(2.72, 0.5, 12.02), Vector3(0, 1.62, 0), _mat(Color(0.85, 0.72, 0.15), 0.5, 0.3)) # stripe
	return root

func _make_low_barrier(parent: Node, lane: int, lz: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(LANE_X[lane], 0, lz)
	parent.add_child(root)
	var orange := _mat(Color(0.92, 0.45, 0.08), 0.6)
	var white := _mat(Color(0.93, 0.93, 0.93), 0.6)
	_box(root, Vector3(2.3, 0.82, 0.42), Vector3(0, 0.46, 0), orange)
	_box(root, Vector3(2.3, 0.20, 0.46), Vector3(0, 0.97, 0), white)
	_box(root, Vector3(0.16, 0.12, 0.5), Vector3(-1.0, 0.06, 0), orange)
	_box(root, Vector3(0.16, 0.12, 0.5), Vector3(1.0, 0.06, 0), orange)
	return root

func _make_high_barrier(parent: Node, lane: int, lz: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(LANE_X[lane], 0, lz)
	parent.add_child(root)
	var post := _mat(Color(0.45, 0.47, 0.52), 0.5, 0.6)
	var board := _mat(Color(0.10, 0.16, 0.38), 0.6)
	var chev := _mat(Color(0.95, 0.78, 0.10), 0.55)
	for sx in [-1.3, 1.3]:
		_box(root, Vector3(0.18, 2.8, 0.18), Vector3(sx, 1.4, 0), post)
	_box(root, Vector3(2.8, 1.5, 0.22), Vector3(0, 1.98, 0), board) # spans y 1.23..2.73
	_box(root, Vector3(0.5, 0.5, 0.1), Vector3(-0.7, 1.98, 0.14), chev)
	_box(root, Vector3(0.5, 0.5, 0.1), Vector3(0.7, 1.98, 0.14), chev)
	_box(root, Vector3(0.5, 0.5, 0.1), Vector3(0.0, 1.98, 0.14), chev)
	return root

func _add_obstacle(seg: Dictionary, kind: String, lane: int, lz: float) -> void:
	var node: Node3D
	var zhalf := 0.3
	match kind:
		"train":
			node = _make_train(seg.node, lane, lz)
			zhalf = 6.0
		"low":
			node = _make_low_barrier(seg.node, lane, lz)
		"high":
			node = _make_high_barrier(seg.node, lane, lz)
		_:
			return
	(seg.obstacles as Array).append({"node": node, "lane": lane, "lz": lz, "kind": kind, "zhalf": zhalf})

func _make_coin(parent: Node, lane: int, lz: float, y: float) -> Dictionary:
	var pivot := Node3D.new()
	pivot.position = Vector3(LANE_X[lane], y, lz)
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.09
	mi.mesh = cm
	mi.rotation_degrees.x = 90.0
	mi.material_override = _mat(Color(0.98, 0.78, 0.16), 0.3, 0.85, Color(1.0, 0.75, 0.2), 0.4)
	pivot.add_child(mi)
	return {"node": pivot, "lane": lane, "lz": lz, "y": y, "taken": false}

func _place_coin_line(seg: Dictionary, lane: int, lz_start: float, count: int, spacing: float, arc_peak: float) -> void:
	for i in range(count):
		var t := 0.0
		if count > 1:
			t = float(i) / float(count - 1)
		var y := 0.95 + sin(t * PI) * arc_peak
		(seg.coins as Array).append(_make_coin(seg.node, lane, lz_start - float(i) * spacing, y))

func _clear_contents(seg: Dictionary) -> void:
	for o in seg.obstacles:
		(o.node as Node).queue_free()
	for cn in seg.coins:
		(cn.node as Node).queue_free()
	(seg.obstacles as Array).clear()
	(seg.coins as Array).clear()

# ---------------------------------------------------------------- spawning
func _spawn_pattern(seg: Dictionary, _easy: bool) -> void:
	_clear_contents(seg)
	if test_mode:
		return
	var r := rng.randf()
	var row_lz := -13.0
	if r < 0.15:
		return # empty segment
	elif r < 0.33:
		_place_coin_line(seg, rng.randi_range(0, 2), -5.0, 6, 2.2, 0.0)
	elif r < 0.53:
		var lane := rng.randi_range(0, 2)
		_add_obstacle(seg, "low", lane, row_lz)
		_place_coin_line(seg, lane, row_lz + 4.4, 5, 2.2, 1.5) # arc over the barrier
		if rng.randf() < 0.5:
			_place_coin_line(seg, (lane + 1) % 3, -5.0, 4, 2.2, 0.0)
	elif r < 0.68:
		var lane := rng.randi_range(0, 2)
		_add_obstacle(seg, "high", lane, row_lz)
		_place_coin_line(seg, (lane + 2) % 3, -5.0, 5, 2.2, 0.0)
	elif r < 0.86:
		var lane := rng.randi_range(0, 2)
		_add_obstacle(seg, "train", lane, row_lz)
		_place_coin_line(seg, (lane + 1) % 3, -5.0, 6, 2.2, 0.0)
	else:
		# double block: two lanes blocked (mixed), one lane always free
		var free_lane := rng.randi_range(0, 2)
		for lane in range(3):
			if lane == free_lane:
				continue
			_add_obstacle(seg, "low" if rng.randf() < 0.5 else "high", lane, row_lz)
		_place_coin_line(seg, free_lane, -5.0, 6, 2.2, 0.0)

# ---------------------------------------------------------------- recycling
func _physics_process(_delta: float) -> void:
	if player == null:
		return
	for seg in segments:
		if seg.z > player.position.z + 38.0:
			seg.z -= SEG_LEN * float(SEG_COUNT)
			(seg.node as Node3D).position.z = seg.z
			_spawn_pattern(seg, false)

func _process(delta: float) -> void:
	for seg in segments:
		for cn in seg.coins:
			if not cn.taken:
				(cn.node as Node3D).rotation.y += delta * 3.5

# ---------------------------------------------------------------- queries
func check_collision(p: Player) -> String:
	for seg in segments:
		if p.position.z > seg.z + 1.0 or p.position.z < seg.z - SEG_LEN - 1.0:
			continue
		for o in seg.obstacles:
			var wz: float = seg.z + o.lz
			if absf(p.position.z - wz) >= o.zhalf + 0.35:
				continue
			if absf(p.position.x - LANE_X[o.lane]) >= 1.15:
				continue
			match o.kind:
				"train":
					return "train"
				"low":
					if p.position.y < 0.85:
						return "low"
				"high":
					if not p.is_slide_effective():
						return "high"
	return ""

func collect_coins(p: Player) -> int:
	var got := 0
	for seg in segments:
		if p.position.z > seg.z + 1.0 or p.position.z < seg.z - SEG_LEN - 1.0:
			continue
		for cn in seg.coins:
			if cn.taken:
				continue
			var wz: float = seg.z + cn.lz
			if absf(p.position.z - wz) >= 0.75:
				continue
			if absf(p.position.x - LANE_X[cn.lane]) >= 0.85:
				continue
			if absf((p.position.y + 0.95) - cn.y) >= 1.05:
				continue
			cn.taken = true
			(cn.node as Node3D).visible = false
			got += 1
	return got

func next_obstacle(lane: int, from_z: float, within: float) -> Dictionary:
	var best := {}
	var best_dist := within
	for seg in segments:
		for o in seg.obstacles:
			if o.lane != lane:
				continue
			var wz: float = seg.z + o.lz
			var dist := from_z - wz
			if dist > 0.0 and dist < best_dist:
				best_dist = dist
				best = {"kind": o.kind, "z": wz, "dist": dist}
	return best

# ---------------------------------------------------------------- test API
func test_clear_all() -> void:
	for seg in segments:
		_clear_contents(seg)

func _segment_for(world_z: float) -> Dictionary:
	for seg in segments:
		if world_z <= seg.z and world_z >= seg.z - SEG_LEN:
			return seg
	return {}

func test_place(kind: String, lane: int, world_z: float) -> bool:
	var seg := _segment_for(world_z)
	if seg.is_empty():
		return false
	_add_obstacle(seg, kind, lane, world_z - seg.z)
	return true

func test_place_coins(lane: int, world_z_start: float, count: int, spacing: float) -> int:
	var placed := 0
	for i in range(count):
		var wz := world_z_start - float(i) * spacing
		var seg := _segment_for(wz)
		if seg.is_empty():
			continue
		(seg.coins as Array).append(_make_coin(seg.node, lane, wz - seg.z, 0.95))
		placed += 1
	return placed
