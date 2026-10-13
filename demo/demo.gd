extends Control
# Pass a font to try it:  godot --path . -- path/to/font.ttf [size] [scale]

@onready var label: BichigLabel = $Margin/Row/Label
@onready var replay: BichigButton = $Margin/Row/Replay
@onready var outline: BichigButton = $Margin/Row/Outline


func _ready() -> void:
	var lines := FileAccess.get_file_as_string("res://demo/sample.txt").strip_edges().split("\n")
	label.text = "\n".join(lines)
	var words := lines[2].split(" ")
	replay.text = words[0]
	outline.text = words[1]
	replay.pressed.connect(_reveal)
	outline.toggled.connect(func(on: bool) -> void: label.outline_size = 1 if on else 0)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var face := FontFile.new()
		face.load_dynamic_font(args[0])
		# A pixel font stays on its grid only with all three off, at a multiple of its size.
		face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		face.hinting = TextServer.HINTING_NONE
		face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		for node: Control in [label, replay, outline]:
			node.font = face
			node.font_size = int(args[1]) if args.size() > 1 else 16
		if args.size() > 2:
			get_window().content_scale_factor = float(args[2])
	_reveal()


func _reveal() -> void:
	label.visible_ratio = 0.0
	create_tween().tween_property(label, ^"visible_ratio", 1.0, 3.0)
