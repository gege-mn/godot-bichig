extends Control
# The same text three ways:  godot --path . res://demo/compare.tscn -- [font.ttf size scale]

const CAPTIONS := ["Label, turned a quarter", "TextServer, ORIENTATION_VERTICAL", "BichigLabel"]

var face: Font = preload("res://demo/fonts/NotoSansMongolian-Regular.ttf")
var em := 24
var sample := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var loaded := FontFile.new()
		loaded.load_dynamic_font(args[0])
		loaded.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		loaded.hinting = TextServer.HINTING_NONE
		loaded.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		face = loaded
		em = int(args[1]) if args.size() > 1 else 16
		if args.size() > 2:
			get_window().content_scale_factor = float(args[2])
	sample = "\n".join(FileAccess.get_file_as_string("res://demo/sample.txt").strip_edges().split("\n").slice(0, 2))
	var back := ColorRect.new()
	back.color = Color(0.09, 0.1, 0.13)
	back.set_anchors_preset(PRESET_FULL_RECT)
	add_child(back)
	await get_tree().process_frame
	var cell := Vector2(floorf(size.x / 3.0), size.y)
	var area := Rect2(12, 34, cell.x - 24, cell.y - 46)
	for at in 3:
		var panel := Control.new()
		panel.position = Vector2(cell.x * at, 0)
		add_child(panel)
		var caption := Label.new()
		caption.text = CAPTIONS[at]
		caption.position = Vector2(12, 8)
		caption.add_theme_font_size_override(&"font_size", 11)
		caption.modulate = Color(1, 1, 1, 0.6)
		panel.add_child(caption)
		match at:
			0:
				var label := Label.new()
				label.text = sample
				label.add_theme_font_override(&"font", face)
				label.add_theme_font_size_override(&"font_size", em)
				label.autowrap_mode = TextServer.AUTOWRAP_WORD
				label.size = Vector2(area.size.y, area.size.x)
				label.rotation = PI / 2
				label.position = area.position + Vector2(area.size.x, 0)
				panel.add_child(label)
			1:
				var canvas := Control.new()
				canvas.position = area.position
				panel.add_child(canvas)
				var x := 0.0
				var paragraphs: Array[TextParagraph] = []
				for source in sample.split("\n"):
					var paragraph := TextParagraph.new()
					paragraph.orientation = TextServer.ORIENTATION_VERTICAL
					paragraph.width = area.size.y
					paragraph.add_string(source, face, em, "mn")
					paragraphs.append(paragraph)
				canvas.draw.connect(func() -> void:
					var left := x
					for paragraph in paragraphs:
						paragraph.draw(canvas.get_canvas_item(), Vector2(left, 0))
						left += maxf(paragraph.get_size().x, em))
			2:
				var label := BichigLabel.new()
				label.text = sample
				label.font = face
				label.font_size = em
				label.position = area.position
				label.size.y = area.size.y
				panel.add_child(label)
