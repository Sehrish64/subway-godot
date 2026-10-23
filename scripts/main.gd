extends Node3D
## Subway Lahore — core demo. Game state, camera feel, HUD, input
## (keyboard + touch swipe), plus two headless drivers:
##   --autotest : scripted verification (assertions, exit code)
##   --capture  : simple self-playing AI for movie frame capture

var player: Player
var track: TrackManager
var camera: Camera3D
var rng := RandomNumberGenerator.new()

var coins := 0
var dead_shown := false
var dead_timer := 0.0
var shake := 0.0
var elapsed := 0.0
var final_score := 0

var score_label: Label
var coins_label: Label
var speed_label: Label
var hint_label: Label
var gameover_root: CenterContainer
var gameover_score: Label

var capture_mode := false
var _cap_cooldown := 0
var _cap_dead_frames := 0

# touch / mouse swipe state
var _touch_start := Vector2.ZERO
var _touch_active := false
var _swipe_fired := false

# ------------------------------------------------------------ autotest state
var test_mode := false
var _t_frame := 0
var _t_step := 0
var _t_wait := 0
var _t_pass := 0
var _t_total := 0
var _t_fail: Array = []
var _t_barrier_z := 0.0
var _t_max_y := 0.0
var _t_acted := false
var _t_slide_at_cross := false
var _t_coins_before := 0
var _t_coin_z := 0.0

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	rng.randomize()
	_build_environment()

	player = Player.new()
	add_child(player)
	track = TrackManager.new()
	add_child(track)
	track.player = player
	player.died.connect(_on_player_died)

	camera = Camera3D.new()
	camera.far = 300.0
	add_child(camera)
	_snap_camera()

	_build_hud()

	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		test_mode = true
		track.test_mode = true
		track.test_clear_all()
		player.speed_locked = true
		player.speed = 15.0
		print("AUTOTEST: starting scripted verification run")
	elif args.has("--capture"):
		capture_mode = true
		print("CAPTURE: self-playing mode")

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.07, 0.15, 0.45)
	sm.sky_horizon_color = Color(1.0, 0.52, 0.22)
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.08, 0.06, 0.08)
	sm.ground_horizon_color = Color(0.85, 0.45, 0.22)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.60, 0.45)
	env.fog_density = 0.007
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(1.0, 0.85, 0.68)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)

# ---------------------------------------------------------------- HUD
func _make_label(text: String, size: int, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_preset(preset)
	l.position = offset
	return l

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	score_label = _make_label("SCORE 0", 34, Control.PRESET_TOP_LEFT, Vector2(22, 14))
	cl.add_child(score_label)
	coins_label = _make_label("COINS 0", 34, Control.PRESET_TOP_RIGHT, Vector2(-190, 14))
	cl.add_child(coins_label)
	speed_label = _make_label("0 km/h", 22, Control.PRESET_TOP_RIGHT, Vector2(-190, 58))
	cl.add_child(speed_label)
	hint_label = _make_label("Arrows / WASD / Swipe — dodge trains, jump low boards, slide under high boards", 24, Control.PRESET_CENTER_BOTTOM, Vector2(-430, -64))
	cl.add_child(hint_label)

	gameover_root = CenterContainer.new()
	gameover_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameover_root.visible = false
	cl.add_child(gameover_root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	gameover_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var title := _make_label("CRASHED!", 58, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _make_label("SUBWAY LAHORE", 24, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	gameover_score = _make_label("Score: 0", 30, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	gameover_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(gameover_score)
	var hint := _make_label("Press R or tap to run again", 24, Control.PRESET_TOP_LEFT, Vector2.ZERO)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		var code := k.keycode
		if code == 0:
			code = k.physical_keycode
		match code:
			KEY_LEFT, KEY_A:
				player.cmd_left()
			KEY_RIGHT, KEY_D:
				player.cmd_right()
			KEY_UP, KEY_W, KEY_SPACE:
				player.cmd_jump()
			KEY_DOWN, KEY_S:
				player.cmd_slide()
			KEY_R:
				if player.dead:
					restart_game()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_start = t.position
			_touch_active = true
			_swipe_fired = false
		else:
			if _touch_active and not _swipe_fired:
				_handle_swipe(t.position - _touch_start, true)
			_touch_active = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touch_active and not _swipe_fired:
			_handle_swipe(d.position - _touch_start, false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_start = mb.position
				_touch_active = true
				_swipe_fired = false
			else:
				if _touch_active and not _swipe_fired:
					_handle_swipe(mb.position - _touch_start, true)
				_touch_active = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touch_active and not _swipe_fired and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_handle_swipe(mm.position - _touch_start, false)

func _handle_swipe(delta: Vector2, released: bool) -> void:
	if delta.length() < 48.0:
		if released and player.dead:
			restart_game()
		return
	_swipe_fired = true
	if absf(delta.x) > absf(delta.y):
		if delta.x > 0.0:
			player.cmd_right()
		else:
			player.cmd_left()
	else:
		if delta.y < 0.0:
			player.cmd_jump()
		else:
			player.cmd_slide()

# ---------------------------------------------------------------- game flow
func _on_player_died() -> void:
	final_score = int(player.distance) + coins * 10
	dead_timer = 0.0
	dead_shown = false
	shake = 0.45

func restart_game() -> void:
	track.reset_world()
	player.reset()
	coins = 0
	dead_shown = false
	gameover_root.visible = false
	_snap_camera()

func current_score() -> int:
	return int(player.distance) + coins * 10

# ---------------------------------------------------------------- per-frame
func _physics_process(_delta: float) -> void:
	if test_mode:
		_autotest_tick()
		return

	if not player.dead:
		var hit := track.check_collision(player)
		if hit != "":
			player.die()
		else:
			coins += track.collect_coins(player)

	if capture_mode:
		_capture_ai()

func _process(delta: float) -> void:
	elapsed += delta
	_update_camera(delta)

	score_label.text = "SCORE %d" % current_score()
	coins_label.text = "COINS %d" % coins
	speed_label.text = "%d km/h" % int(player.speed * 3.6)
	if hint_label.visible and elapsed > 6.0:
		hint_label.visible = false

	if player.dead and not dead_shown:
		dead_timer += delta
		if dead_timer > 0.6:
			dead_shown = true
			gameover_score.text = "Score: %d   Coins: %d" % [final_score, coins]
			gameover_root.visible = true
	shake = maxf(0.0, shake - delta)

func _snap_camera() -> void:
	camera.position = Vector3(0, 5.1, 7.6)
	camera.look_at(Vector3(0, 1.3, -9), Vector3.UP)
	camera.fov = 68.0

func _update_camera(delta: float) -> void:
	var target := Vector3(
		player.position.x * 0.55,
		5.1 + player.position.y * 0.25,
		player.position.z + 7.6)
	var w := 1.0 - exp(-8.0 * delta)
	camera.position = camera.position.lerp(target, w)
	if shake > 0.0:
		camera.position += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * shake * 0.25
	var look := player.position + Vector3(player.position.x * 0.25, 1.3, -9.0)
	if camera.position.distance_squared_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)
	var speed_t := clampf((player.speed - 11.0) / 19.0, 0.0, 1.0)
	var target_fov := 68.0 + speed_t * 14.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-3.0 * delta))

# ---------------------------------------------------------------- capture AI
func _capture_ai() -> void:
	if player.dead:
		_cap_dead_frames += 1
		if _cap_dead_frames > 55:
			_cap_dead_frames = 0
			restart_game()
		return
	_cap_dead_frames = 0
	_cap_cooldown -= 1
	var obs := track.next_obstacle(player.lane, player.position.z, 14.0)
	if not obs.is_empty():
		var d: float = obs.dist
		match obs.kind:
			"train":
				if d < 11.0 and _cap_cooldown <= 0:
					for dir in [-1, 1]:
						var nl: int = player.lane + dir
						if nl < 0 or nl > 2:
							continue
						var other := track.next_obstacle(nl, player.position.z, 15.0)
						if other.is_empty() or other.dist > 13.0:
							if dir < 0:
								player.cmd_left()
							else:
								player.cmd_right()
							_cap_cooldown = 10
							break
			"low":
				if d >= 3.0 and d <= 4.8 and _cap_cooldown <= 0:
					player.cmd_jump()
					_cap_cooldown = 8
			"high":
				if d >= 2.6 and d <= 4.2 and _cap_cooldown <= 0:
					player.cmd_slide()
					_cap_cooldown = 8
	elif _cap_cooldown <= 0:
		if rng.randf() < 0.02:
			if rng.randf() < 0.5:
				player.cmd_left()
			else:
				player.cmd_right()
			_cap_cooldown = 14

# ---------------------------------------------------------------- autotest
func _t_assert(cond: bool, name: String, detail := "") -> void:
	_t_total += 1
	if cond:
		_t_pass += 1
		print("AUTOTEST PASS: ", name)
	else:
		_t_fail.append(name + " " + detail)
		print("AUTOTEST FAIL: ", name, " ", detail)

func _t_finish() -> void:
	var lines := PackedStringArray()
	lines.append("AUTOTEST RESULT: %d/%d passed" % [_t_pass, _t_total])
	for f in _t_fail:
		lines.append("FAILED: " + f)
	var txt := "\n".join(lines)
	print(txt)
	var path := ProjectSettings.globalize_path("res://autotest_results.txt")
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string(txt + "\n")
		fa.close()
	get_tree().quit(0 if _t_fail.is_empty() else 1)

func _autotest_tick() -> void:
	_t_frame += 1
	if _t_frame > 60 * 45:
		_t_assert(false, "timeout", "step=%d" % _t_step)
		_t_finish()
		return

	# collisions/coins still run in test mode (that is the point)
	if not player.dead:
		var hit := track.check_collision(player)
		if hit != "":
			player.die()
		else:
			coins += track.collect_coins(player)

	match _t_step:
		0:
			if _t_frame >= 12:
				_t_assert(player.lane == 1 and absf(player.position.x) < 0.01, "start_center", "lane=%d x=%.2f" % [player.lane, player.position.x])
				player.cmd_right()
				_t_wait = 25
				_t_step = 1
		1:
			_t_wait -= 1
			if _t_wait <= 0:
				_t_assert(player.lane == 2 and absf(player.position.x - 2.2) < 0.06, "lane_right", "lane=%d x=%.2f" % [player.lane, player.position.x])
				player.cmd_left()
				player.cmd_left()
				_t_wait = 30
				_t_step = 2
		2:
			_t_wait -= 1
			if _t_wait <= 0:
				_t_assert(player.lane == 0 and absf(player.position.x + 2.2) < 0.06, "lane_left_x2", "lane=%d x=%.2f" % [player.lane, player.position.x])
				player.cmd_right()
				_t_wait = 20
				_t_step = 3
		3:
			_t_wait -= 1
			if _t_wait <= 0:
				_t_assert(player.lane == 1, "back_center", "lane=%d" % player.lane)
				_t_barrier_z = player.position.z - 45.0
				var ok := track.test_place("low", 1, _t_barrier_z)
				_t_assert(ok, "place_low_barrier")
				_t_max_y = 0.0
				_t_acted = false
				_t_step = 4
		4:
			if absf(player.position.z - _t_barrier_z) < 1.2:
				_t_max_y = maxf(_t_max_y, player.position.y)
			if not _t_acted and player.position.z <= _t_barrier_z + 4.2 and player.position.z > _t_barrier_z:
				player.cmd_jump()
				_t_acted = true
			if player.position.z < _t_barrier_z - 3.0:
				_t_assert(not player.dead, "jump_over_low_barrier")
				_t_assert(_t_max_y > 0.9, "jump_height_at_barrier", "max_y=%.2f" % _t_max_y)
				_t_barrier_z = player.position.z - 40.0
				var ok2 := track.test_place("high", 1, _t_barrier_z)
				_t_assert(ok2, "place_high_barrier")
				_t_acted = false
				_t_slide_at_cross = false
				_t_step = 5
		5:
			if absf(player.position.z - _t_barrier_z) < 0.7:
				_t_slide_at_cross = player.is_slide_effective()
			if not _t_acted and player.position.z <= _t_barrier_z + 3.2 and player.position.z > _t_barrier_z:
				player.cmd_slide()
				_t_acted = true
			if player.position.z < _t_barrier_z - 3.0:
				_t_assert(not player.dead, "slide_under_high_barrier")
				_t_assert(_t_slide_at_cross, "slide_state_at_board")
				_t_coins_before = coins
				_t_coin_z = player.position.z - 25.0
				var placed := track.test_place_coins(1, _t_coin_z, 5, 2.2)
				_t_assert(placed == 5, "place_coins", "placed=%d" % placed)
				_t_step = 6
		6:
			if player.position.z < _t_coin_z - 14.0:
				_t_assert(coins - _t_coins_before >= 4, "collect_coins", "got=%d" % (coins - _t_coins_before))
				_t_barrier_z = player.position.z - 40.0
				var ok3 := track.test_place("train", 1, _t_barrier_z)
				_t_assert(ok3, "place_train")
				_t_step = 7
		7:
			if player.dead:
				_t_assert(true, "train_kills")
				_t_assert(current_score() >= 50, "score_accrues", "score=%d" % current_score())
				_t_wait = 15
				_t_step = 8
			elif player.position.z < _t_barrier_z - 12.0:
				_t_assert(false, "train_kills", "ran through train")
				_t_wait = 15
				_t_step = 8
		8:
			_t_wait -= 1
			if _t_wait <= 0:
				restart_game()
				_t_wait = 12
				_t_step = 9
		9:
			_t_wait -= 1
			if _t_wait <= 0:
				_t_assert(not player.dead, "restart_alive")
				_t_assert(coins == 0, "restart_coins_reset")
				_t_assert(absf(player.position.z) < 4.0, "restart_position", "z=%.2f" % player.position.z)
				_t_assert(player.lane == 1, "restart_lane")
				_t_finish()
