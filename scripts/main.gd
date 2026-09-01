extends Control
## Stage-C: free tap / simon follow, high score, menu.

const COLS := 4
const ROWS := 4
const CELL := 68.0
const TIME_LIMIT := 40.0
const COLORS: Array[Color] = [
	Color(0.95, 0.4, 0.55), Color(0.4, 0.85, 0.9), Color(0.95, 0.8, 0.35),
	Color(0.55, 0.75, 0.95), Color(0.7, 0.5, 0.95), Color(0.45, 0.9, 0.55),
]

@onready var _grid: GridContainer = $Center/Grid
@onready var _hud: Label = $UI/HUD
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry

var _score: int = 0
var _taps: int = 0
var _time_left: float = TIME_LIMIT
var _alive: bool = false
var _in_menu: bool = true
var _simon: bool = false
var _seq: Array[int] = []
var _seq_idx: int = 0
var _showing: bool = false
var _cells: Array[Button] = []
var _rng := RandomNumberGenerator.new()
var _menu: ColorRect
var _to_menu: Button

func _ready() -> void:
	_rng.randomize()
	_retry.pressed.connect(_restart_play)
	_grid.columns = COLS
	_build_grid()
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0.1, 0.12, 0.16, 1)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -140
	vb.offset_top = -130
	vb.offset_right = 140
	vb.offset_bottom = 130
	vb.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Mikutap"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.7))
	vb.add_child(title)
	var hi := Label.new()
	hi.name = "High"
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hi)
	var free_b := Button.new()
	free_b.text = "自由点按 · 40s"
	free_b.custom_minimum_size = Vector2(260, 42)
	free_b.pressed.connect(func() -> void: _start_mode(false))
	vb.add_child(free_b)
	var sim_b := Button.new()
	sim_b.text = "跟敲模式 · 序列"
	sim_b.custom_minimum_size = Vector2(260, 42)
	sim_b.pressed.connect(func() -> void: _start_mode(true))
	vb.add_child(sim_b)
	_menu.add_child(vb)
	$UI.add_child(_menu)
	_to_menu = Button.new()
	_to_menu.text = "返回菜单"
	_to_menu.pressed.connect(_show_menu)
	$UI/Overlay/VBox.add_child(_to_menu)

func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_cells.clear()
	for i in COLS * ROWS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(CELL, CELL)
		var idx := i
		b.pressed.connect(func() -> void: _on_cell(idx))
		_grid.add_child(b)
		_cells.append(b)
		_style_cell(i, false)

func _style_cell(i: int, flash: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[i % COLORS.size()]
	if flash:
		style.bg_color = style.bg_color.lightened(0.35)
	style.set_corner_radius_all(12)
	_cells[i].add_theme_stylebox_override("normal", style)
	_cells[i].add_theme_stylebox_override("hover", style)
	_cells[i].text = ""

func _show_menu() -> void:
	_alive = false
	_in_menu = true
	_overlay.visible = false
	_menu.visible = true
	$Center.visible = false
	(_menu.get_node("VBoxContainer/High") as Label).text = "最高分 %d" % SaveData.high_score
	_hud.text = "Mikutap"

func _start_mode(simon: bool) -> void:
	_simon = simon
	_in_menu = false
	_menu.visible = false
	$Center.visible = true
	_restart_play()

func _restart_play() -> void:
	_score = 0
	_taps = 0
	_time_left = TIME_LIMIT
	_alive = true
	_seq.clear()
	_seq_idx = 0
	_showing = false
	_overlay.visible = false
	for i in _cells.size():
		_style_cell(i, false)
	if _simon:
		_extend_seq()
		_play_seq()
	_update_hud()

func _process(delta: float) -> void:
	if not _alive or _in_menu or _simon:
		return
	_time_left -= delta
	_update_hud()
	if _time_left <= 0.0:
		_end()

func _extend_seq() -> void:
	_seq.append(_rng.randi_range(0, COLS * ROWS - 1))

func _play_seq() -> void:
	_showing = true
	_seq_idx = 0
	_flash_seq_step(0)

func _flash_seq_step(i: int) -> void:
	if not _alive or not _simon:
		return
	if i >= _seq.size():
		_showing = false
		_seq_idx = 0
		_update_hud()
		return
	var cell: int = _seq[i]
	_style_cell(cell, true)
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if cell < _cells.size():
			_style_cell(cell, false)
		get_tree().create_timer(0.15).timeout.connect(func() -> void: _flash_seq_step(i + 1))
	)

func _on_cell(i: int) -> void:
	if not _alive or _in_menu or _showing:
		return
	if _simon:
		if i == _seq[_seq_idx]:
			_seq_idx += 1
			_taps += 1
			_score += 10 + _seq.size()
			_style_cell(i, true)
			get_tree().create_timer(0.1).timeout.connect(func() -> void:
				if i < _cells.size():
					_style_cell(i, false)
			)
			if _seq_idx >= _seq.size():
				_score += 20
				_extend_seq()
				get_tree().create_timer(0.4).timeout.connect(_play_seq)
			_update_hud()
		else:
			_end()
		return
	_taps += 1
	_score += 5 + (_taps % 8)
	_style_cell(i, true)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if i < _cells.size():
			_style_cell(i, false)
	)
	_update_hud()

func _update_hud() -> void:
	if _simon:
		_hud.text = "跟敲  得分 %d  最高 %d\n序列长度 %d  进度 %d/%d" % [
			_score, SaveData.high_score, _seq.size(), _seq_idx, _seq.size()
		]
	else:
		_hud.text = "自由  得分 %d  最高 %d\n点击 %d  剩余 %.1fs" % [
			_score, SaveData.high_score, _taps, maxf(0.0, _time_left)
		]

func _end() -> void:
	_alive = false
	var best: int = SaveData.record(_score)
	_over_msg.text = "结束\n得分 %d\n点击 %d\n最高 %d" % [_score, _taps, best]
	_overlay.visible = true
