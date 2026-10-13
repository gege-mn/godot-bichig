extends Control
# Pass a font to try it:  godot --path . -- path/to/font.ttf [size] [scale]

@onready var label: BichigLabel = $Margin/Label


func _ready() -> void:
	label.text = FileAccess.get_file_as_string("res://demo/sample.txt").strip_edges()
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var face := FontFile.new()
	face.load_dynamic_font(args[0])
	# A pixel font stays on its grid only with all three off, at a multiple of its size.
	face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	face.hinting = TextServer.HINTING_NONE
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	label.font = face
	label.font_size = int(args[1]) if args.size() > 1 else 16
	if args.size() > 2:
		get_window().content_scale_factor = float(args[2])
