extends SceneTree
# Sets each text of a JSON list in a font and writes the pixels back as rows of # and .
#   godot --path . --script tests/render.gd -- font.ttf size texts.json rows.json [height]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var face := FontFile.new()
	face.load_dynamic_font(args[0])
	face.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	face.hinting = TextServer.HINTING_NONE
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var texts: Array = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	var out := []
	for text in texts:
		var viewport := SubViewport.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var label := BichigLabel.new()
		label.font = face
		label.font_size = int(args[1])
		label.text = text
		label.autowrap = args.size() > 4
		viewport.add_child(label)
		root.add_child(viewport)
		if label.autowrap:
			label.size.y = int(args[4])
			await process_frame
		var area := label.get_combined_minimum_size()
		if label.autowrap:
			area.y = int(args[4])
		viewport.size = area.max(Vector2.ONE)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var rows := []
		for y in image.get_height():
			var row := ""
			for x in image.get_width():
				row += "#" if image.get_pixel(x, y).r > 0.5 else "."
			rows.append(row)
		out.append(rows)
		viewport.queue_free()
	FileAccess.open(args[3], FileAccess.WRITE).store_string(JSON.stringify(out))
	quit()
