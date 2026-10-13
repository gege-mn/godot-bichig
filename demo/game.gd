extends Node2D
# A dialogue box that fills column by column. Walk with the arrow keys, or leave it and the
# hero walks on alone. Pass a font to try it:  godot --path . -- path/to/font.ttf [size]

const SCALE := 3.0
const VIEW := Vector2(384, 240)
const LENGTH := 1060.0
const GROUND := 128.0
const NIGHT := Color("10122b")
const PAPER := Color("f6efd9")
const GOLD := Color("ffc93c")
const P := {
	"k": Color("10122b"), "f": Color("f2c79a"), "r": Color("e8452c"), "y": Color("ffc93c"), "b": Color("3d6bd6"), "w": Color("f6efd9"),
	"n": Color("8a5a2b"), "d": Color("5c3a1c"), "g": Color("6bcb5a"), "p": Color("b45ad6"), "s": Color("4cc9f0"),
}
const SKY := ["1b1642", "231a52", "2a1d5e", "4a2a7a", "7a3a8a", "c0507a", "f08a5d", "ffc93c"]
const S := {
	"hero": ["...kkkk...", "..kkkkkk..", "..kffffk..", "..fkffkf..", "..ffffff..", "...rrrr...", "..rrrrrr..", ".rryrryrr.", ".frrrrrrf.", "..rrrrrr..", "..rryyrr.."],
	"legs": [["..bb..bb..", "..bb..bb..", ".kkk..kkk."], ["...bbbb...", "..bb..bb..", ".kk....kk."]],
	"elder": ["....yy....", "...rrrr...", "..rrrrrr..", "..kffffk..", "..fkffkf..", "..fwwwwf..", "...wwww...", "..bbwwbb..", ".bbbyybbb.", ".fbbbbbbf.", "..bbbbbb..", "..bbbbbb..", "..bbbbbb..", ".kkk..kkk."],
	"bard": ["...pppp...", "..pppppp..", "..kffffk..", "..fkffkf..", "..ffffff..", "...gggg...", "..gggggg..", ".ggnnnngg.", ".fgnyyngf.", "..gnnnng..", "..gggggg..", "..gg..gg..", "..gg..gg..", ".kkk..kkk."],
	"traveller": ["..ssssss..", ".ssssssss.", "..kffffk..", "..fkffkf..", "..ffffff..", "...yyyy...", "..yyyyyy..", ".yyyrryyy.", ".fyyyyyyf.", "..yyyyyy..", "..yyyyyy..", "..nn..nn..", "..nn..nn..", ".kkk..kkk."],
	"horse": ["..............kk..", ".............knnk.", "............knnnnn", ".kk........knnnn.n", "knnkkkkkkkknnnk...", "knnnnnnnnnnnnnk...", ".knnnnnnnnnnnnk...", ".knnnnnnnnnnnk....", ".knkknkkkknkknk...", ".knk.knk..knk.knk.", ".knk.knk..knk.knk.", ".knk.knk..knk.knk.", ".kk..kk...kk..kk.."],
}

var scene: Array[Dictionary] = []
var x := 60.0
var face := 1
var idle := 99.0
var wait := 0.0
var next := 0
var move := 0
var time := 0.0
var shown := -1
var stops: PackedInt32Array = []
var told := 0
var since := 0.0

var say := BichigLabel.new()
var who := Label.new()
var gloss := Label.new()


func _ready() -> void:
	for row in FileAccess.get_file_as_string("res://demo/dialogue.tsv").strip_edges().split("\n"):
		var cells := row.split("\t")
		scene.append({kind = cells[0], x = float(cells[1]), who = cells[2], text = cells[3], gloss = cells[4]})
	var stage := Node2D.new()
	stage.scale = Vector2(SCALE, SCALE)
	add_child(stage)
	say.position = Vector2(18, 146)
	say.size = Vector2(348, 80)
	say.font = preload("res://demo/fonts/NotoSansMongolian-Regular.ttf")
	say.font_size = 16
	say.font_color = PAPER
	say.column_spacing = 4
	say.autowrap = true
	who.position = Vector2(18, 122)
	who.add_theme_color_override(&"font_color", NIGHT)
	who.add_theme_font_size_override(&"font_size", 12)
	stage.add_child(say)
	stage.add_child(who)
	gloss.position = Vector2(16, VIEW.y * SCALE + 14)
	gloss.add_theme_color_override(&"font_color", PAPER)
	add_child(gloss)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var face_file := FontFile.new()
		face_file.load_dynamic_font(args[0])
		# A pixel font stays on its grid only with all three off, at a multiple of its size.
		face_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		face_file.hinting = TextServer.HINTING_NONE
		face_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		say.font = face_file
		say.font_size = int(args[1]) if args.size() > 1 else 16
		who.add_theme_font_override(&"font", face_file)
		who.add_theme_font_size_override(&"font_size", say.font_size)
	_speak(-1)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	time += delta
	idle += delta
	var held := int(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	if held:
		idle = 0.0
	move = held
	if not held and idle > 5.0:
		if wait <= 0 and next < scene.size() and scene[next].x - 14 < x - 2:
			next = scene.size()
			for at in scene.size():
				if scene[at].x - 14 > x + 2:
					next = at
					break
		var goal: float = scene[next].x - 14 if next < scene.size() else LENGTH + 20
		if wait > 0:
			wait -= delta
		elif absf(goal - x) < 1.5:
			wait = 5.5
			next += 1
		else:
			move = signi(int(signf(goal - x)))
		if x > LENGTH:
			x = 20.0
			next = 0
	if move:
		x = clampf(x + move * 46 * delta, 12, LENGTH + 30)
		face = move
	var near := -1
	for at in scene.size():
		if absf(scene[at].x - 14 - x) < 20 or absf(scene[at].x + 14 - x) < 12:
			near = at
			break
	if near != shown:
		_speak(near)
	# The words of a line appear one by one.
	if shown >= 0 and told < stops.size():
		since += delta
		if since >= 0.26:
			since = 0.0
			say.visible_characters = stops[told]
			told += 1
	queue_redraw()


func _speak(at: int) -> void:
	shown = at
	say.visible = at >= 0
	who.visible = at >= 0
	gloss.text = ""
	if at < 0:
		return
	var thing := scene[at]
	who.text = thing.who
	gloss.text = "%s: %s" % [thing.who, thing.gloss]
	say.text = thing.text
	say.visible_characters = 0
	stops.clear()
	for index in thing.text.length():
		if thing.text[index] == " ":
			stops.append(index + 1)
	stops.append(thing.text.length())
	told = 0
	since = 0.0


func _box(left: float, top: float, width: float, height: float, colour: Color) -> void:
	draw_rect(Rect2(roundf(left), roundf(top), width, height), colour)


func _sprite(rows: Array, left: float, top: float, flip := false) -> void:
	for row in rows.size():
		var cells: String = rows[row]
		for at in cells.length():
			if cells[at] != ".":
				_box(left + (cells.length() - 1 - at if flip else at), top + row, 1, 1, P[cells[at]])


func _noise(n: float) -> float:
	var v := sin(n * 127.1) * 43758.5453
	return v - floorf(v)


func _thing(kind: String, at: float) -> void:
	match kind:
		"sign":
			_box(at + 5, GROUND - 12, 2, 12, P.d); _box(at - 1, GROUND - 20, 14, 9, P.d); _box(at, GROUND - 19, 12, 7, Color("c98f4a"))
			_box(at + 2, GROUND - 17, 8, 1, P.d); _box(at + 2, GROUND - 15, 6, 1, P.d)
		"chest":
			_box(at - 1, GROUND - 10, 16, 10, P.k); _box(at, GROUND - 9, 14, 9, P.n); _box(at, GROUND - 9, 14, 3, Color("a8743a"))
			_box(at, GROUND - 6, 14, 1, P.k); _box(at + 6, GROUND - 7, 2, 3, P.y)
		"letter":
			_box(at - 2, GROUND - 5, 16, 5, Color("56507a")); _box(at, GROUND - 7, 12, 3, Color("6d6794")); _box(at, GROUND - 15, 12, 8, P.w)
			_box(at, GROUND - 15, 12, 1, Color("c9c0a3")); _box(at + 1, GROUND - 14, 1, 1, Color("c9c0a3")); _box(at + 10, GROUND - 14, 1, 1, Color("c9c0a3"))
			_box(at + 5, GROUND - 12, 2, 2, P.r)
		_:
			_sprite(S[kind], at, GROUND - 14, true)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(SCALE, SCALE))
	var cam := clampf(x - 180, 0, LENGTH - VIEW.x)
	for at in SKY.size():
		_box(0, at * 14, VIEW.x, 14, Color(SKY[at]))
	for at in 40:
		if fmod(time * 2 + at, 5) > 1:
			_box(fmod(_noise(at) * 600 - cam * 0.05, VIEW.x), _noise(at + 50) * 60, 1, 1, P.w)
	_box(300 - cam * 0.05, 92, 28, 20, P.w)
	_box(296 - cam * 0.05, 98, 36, 14, P.w)
	for at in 4:
		var cloud := fmod(at * 190 + time * 4 - cam * 0.1, 760) - 60
		_box(cloud, 30 + at * 9, 34, 4, Color("ffffff33"))
		_box(cloud + 6, 26 + at * 9, 18, 4, Color("ffffff33"))
	for px in range(0, int(VIEW.x), 2):
		var far := 34 + sin((px + cam * 0.2) * 0.021) * 14 + sin((px + cam * 0.2) * 0.057) * 6
		_box(px, 112 - far, 2, far, Color("2a1d5e"))
		var hill := 14 + sin((px + cam * 0.5) * 0.034 + 2) * 8 + sin((px + cam * 0.5) * 0.09) * 3
		_box(px, 112 - hill, 2, hill + 16, Color("3c2a70"))
	_box(0, GROUND, VIEW.x, 112, Color("1f5a3a"))
	_box(0, GROUND, VIEW.x, 2, P.g)
	_box(0, GROUND + 8, VIEW.x, 104, Color("17452d"))
	for at in 90:
		var blade := _noise(at + 9) * LENGTH - cam
		if blade > -4 and blade < VIEW.x + 4:
			_box(blade, GROUND - 2, 1, 2, P.g)
	var ger := 430 - cam
	_box(ger, GROUND - 14, 40, 14, P.w)
	for at in 9:
		_box(ger + 2 + at * 2, GROUND - 15 - at, 36 - at * 4, 1, Color("e3d9bb") if at % 2 else P.w)
	_box(ger + 17, GROUND - 26, 6, 2, P.r)
	_box(ger, GROUND - 14, 40, 2, P.r)
	for at in range(1, 40, 4):
		_box(ger + at, GROUND - 14, 2, 1, P.y)
	_box(ger + 16, GROUND - 11, 8, 11, P.r)
	_box(ger + 18, GROUND - 9, 4, 9, P.y)
	var fire := 176 - cam
	_box(fire, GROUND - 2, 8, 2, P.d)
	_box(fire + 2, GROUND - 5 - (int(time * 6) & 1), 4, 4, P.r)
	_box(fire + 3, GROUND - 4, 2, 2, P.y)
	_sprite(S.horse, 560 - cam, GROUND - 13)
	for thing in scene:
		_thing(thing.kind, thing.x - cam)
	_sprite(S.hero, x - cam - 5, GROUND - 14, face < 0)
	_sprite(S.legs[int(time * 8) % 2 if move else 0], x - cam - 5, GROUND - 3, face < 0)
	if shown >= 0:
		_box(7, 137, 370, 98, NIGHT)
		_box(8, 138, 368, 96, PAPER)
		_box(10, 140, 364, 92, NIGHT)
		_box(14, 122, who.size.x + 8, 18, GOLD)
		if told >= stops.size() and fmod(time, 1.0) < 0.5:
			draw_colored_polygon([Vector2(364, 226), Vector2(370, 226), Vector2(367, 230)], GOLD)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_box(0, VIEW.y * SCALE, VIEW.x * SCALE, 56, NIGHT)
