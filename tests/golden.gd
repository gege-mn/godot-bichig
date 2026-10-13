extends SceneTree
# Sets every case of tests/cases.json and compares its pixels with the approved ones in
# tests/golden. It needs a window: the headless renderer draws nothing.
#
#   godot --path . --script tests/golden.gd                 check
#   godot --path . --script tests/golden.gd -- --approve    take what is drawn now as right
#
# The set "noto" is drawn in the demo's font. A further set is checked when its font is at
# hand: `-- --font path/to/font.ttf --size 16 --set name`. Gege Pixel is looked for in
# $GEGE_PIXEL_FONT and beside this repository.

const GEGE := "../gege-pixel-font/dist/GegePixel-Regular.ttf"

var failed := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var approve := args.has("--approve")
	var sets := [["noto", ProjectSettings.globalize_path("res://demo/fonts/NotoSansMongolian-Regular.ttf"), 16]]
	var gege := OS.get_environment("GEGE_PIXEL_FONT")
	if gege.is_empty():
		gege = ProjectSettings.globalize_path("res://").path_join(GEGE).simplify_path()
	if FileAccess.file_exists(gege):
		sets.append(["gege-pixel", gege, 16])
	if args.has("--font"):
		sets = [[_after(args, "--set", "font"), _after(args, "--font", ""), int(_after(args, "--size", "16"))]]
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/cases.json"))
	for each in sets:
		await _run(each[0], each[1], each[2], cases, approve)
	print("golden: approved" if approve else ("golden: %d differ" % failed if failed else "golden: all the same"))
	quit(1 if failed else 0)


func _after(args: PackedStringArray, flag: String, otherwise: String) -> String:
	var at := args.find(flag)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else otherwise


func _run(name: String, file: String, em: int, cases: Array, approve: bool) -> void:
	var face := FontFile.new()
	face.load_dynamic_font(file)
	# Without smoothing the pixels are the same on every machine.
	face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	face.hinting = TextServer.HINTING_NONE
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var path := "res://tests/golden/%s.txt" % name
	var drawn := ""
	for case in cases:
		drawn += "== %s\n%s\n" % [case.name, "\n".join(await _rows(case, face, em))]
	if approve:
		FileAccess.open(path, FileAccess.WRITE).store_string(drawn)
		print("%s: %d cases approved" % [name, cases.size()])
		return
	if not FileAccess.file_exists(path):
		print("%s: nothing approved yet" % name)
		failed += 1
		return
	var want := _split(FileAccess.get_file_as_string(path))
	var got := _split(drawn)
	var differ := 0
	for case in cases:
		if not _same(want.get(case.name, ""), got[case.name], name == "noto"):
			differ += 1
			print("%s: %s differs\n-- approved\n%s\n-- drawn\n%s" % [name, case.name, want.get(case.name, "(none)"), got[case.name]])
	print("%s: %d of %d cases the same" % [name, cases.size() - differ, cases.size()])
	failed += differ


# An outline font is not rasterised alike by every version of the engine: a few pixels in a
# hundred may fall the other way. A pixel font is the same everywhere.
func _same(want: String, got: String, smooth: bool) -> bool:
	if want == got or not smooth or want.length() != got.length() or want.find("
") != got.find("
"):
		return want == got
	var off := 0
	for at in want.length():
		off += int(want[at] != got[at])
	return off <= 4 + (want.count("#") + want.count("o")) / 50


func _split(all: String) -> Dictionary:
	var found := {}
	for part in all.split("== ", false):
		var at := part.find("\n")
		found[part.substr(0, at)] = part.substr(at + 1).strip_edges()
	return found


func _rows(case: Dictionary, face: Font, em: int) -> PackedStringArray:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var label := BichigLabel.new()
	label.font = face
	label.font_size = em
	label.text = case.text
	label.autowrap = case.wrap > 0
	label.visible_characters = case.get("visible", -1)
	label.alignment = case.get("alignment", 0)
	label.column_spacing = case.get("spacing", 0)
	label.outline_size = case.get("outline", 0)
	label.outline_color = Color(0.5, 0.5, 0.5)
	viewport.add_child(label)
	root.add_child(viewport)
	if label.autowrap:
		label.size.y = case.wrap * em
		await process_frame
	var area := label.get_combined_minimum_size()
	if label.autowrap:
		area.y = case.wrap * em
	viewport.size = area.max(Vector2.ONE)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var rows: PackedStringArray = []
	for y in image.get_height():
		var row := ""
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			row += "." if pixel.a < 0.5 else ("#" if pixel.r > 0.75 else "o")
		rows.append(row)
	viewport.queue_free()
	return rows
