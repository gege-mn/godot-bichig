class_name BichigText
extends RefCounted
## Text in the traditional Mongolian script, laid out in columns that run top to bottom and
## follow each other left to right, to draw on any canvas item.
##
## The engine shapes the text as a horizontal line, which is how a Mongolian font is drawn,
## and each line is turned a quarter clockwise. Characters that Unicode stands upright in a
## vertical line (CJK, fullwidth forms, ‼, emoji) are set upright, in their vertical forms.

enum Alignment { TOP, CENTER, BOTTOM }

const Orientation := preload("orientation.gd")
const TURN := Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2.ZERO)

## A line break starts a new column.
var text := "":
	set(value):
		_dirty = _dirty or value != text
		text = value
var font: Font:
	set(value):
		_dirty = _dirty or value != font
		font = value
var font_size := 16:
	set(value):
		_dirty = _dirty or value != font_size
		font_size = value
## A column longer than this breaks. Zero or less never breaks one.
var wrap_height := -1.0:
	set(value):
		_dirty = _dirty or value != wrap_height
		wrap_height = value
var column_spacing := 0.0:
	set(value):
		_dirty = _dirty or value != column_spacing
		column_spacing = value
var language := "mn":
	set(value):
		_dirty = _dirty or value != language
		language = value
var alignment := Alignment.TOP
## How many characters of the text are drawn, for a reveal. Less than zero draws all. The
## letters keep the forms they have in the whole word while it appears.
var visible_characters := -1

var _buffers: Array[RID] = []
var _columns: Array[RID] = []
var _starts: PackedInt32Array = []
var _upright: Array[Dictionary] = []
var _size := Vector2.ZERO
var _dirty := true


func _notification(what: int) -> void:
	# No method of its own can be called on an object that is being deleted.
	if what == NOTIFICATION_PREDELETE:
		var server := TextServerManager.get_primary_interface()
		for column in _columns:
			if not column in _buffers:
				server.free_rid(column)
		for buffer in _buffers:
			server.free_rid(buffer)


## Shape again after the font itself changed.
func invalidate() -> void:
	_dirty = true


## The width of the columns and the length of the longest one.
func get_size() -> Vector2:
	_shape()
	return _size


func get_column_count() -> int:
	_shape()
	return _columns.size()


## Draws the columns with their top left corner at [param at]. They are aligned within
## [param extent], or within the longest column when it is zero. The canvas item's drawing
## transform is set while drawing and left at [param transform]: pass the one set with
## [method CanvasItem.draw_set_transform], if any.
func draw(canvas: RID, at: Vector2, color := Color.WHITE, extent := 0.0, transform := Transform2D.IDENTITY) -> void:
	_draw(canvas, at, color, extent, 0, transform)


func draw_outline(canvas: RID, at: Vector2, outline_size: int, color := Color.BLACK, extent := 0.0, transform := Transform2D.IDENTITY) -> void:
	if outline_size > 0:
		_draw(canvas, at, color, extent, outline_size, transform)


func _free() -> void:
	var server := TextServerManager.get_primary_interface()
	for column in _columns:
		if not column in _buffers:
			server.free_rid(column)
	for buffer in _buffers:
		server.free_rid(buffer)
	_columns.clear()
	_buffers.clear()


func _shape() -> void:
	if not _dirty:
		return
	_dirty = false
	_free()
	_starts.clear()
	_upright.clear()
	_size = Vector2.ZERO
	if font == null or font_size <= 0:
		return
	var server := TextServerManager.get_primary_interface()
	var across := font.get_height(font_size)
	var start := 0
	for source in text.split("\n"):
		var buffer := server.create_shaped_text()
		_buffers.append(buffer)
		var run := ""
		var at := 0
		var graphemes := server.string_get_character_breaks(source, language)
		var grapheme := 0
		while at < source.length():
			while grapheme < graphemes.size() and graphemes[grapheme] <= at:
				grapheme += 1
			var end := graphemes[grapheme] if grapheme < graphemes.size() else source.length()
			var stop := end if _stands(source, at, end) else at
			var stood := {} if stop == at else _stand(server, source.substr(at, stop - at))
			if stood.is_empty():
				stop = maxi(stop, at + 1)
				run += source.substr(at, stop - at)
			else:
				if run:
					_add(server, buffer, run)
					run = ""
				stood.start = start + at
				server.shaped_text_add_object(buffer, _upright.size(), Vector2(stood.advance, across), INLINE_ALIGNMENT_CENTER, stop - at)
				_upright.append(stood)
			at = stop
		# An empty paragraph still takes a column.
		_add(server, buffer, run if run or at else " ")
		server.shaped_text_shape(buffer)
		for column in _break(server, buffer, source):
			_columns.append(column)
			_starts.append(start)
			_size.x += _across(server, column) + column_spacing
			_size.y = maxf(_size.y, server.shaped_text_get_width(column))
		start += source.length() + 1
	_size.x = maxf(_size.x - column_spacing, 0.0)


func _add(server: TextServer, buffer: RID, run: String) -> void:
	server.shaped_text_add_string(buffer, run, font.get_rids(), font_size, font.get_opentype_features(), language)


# The columns of a paragraph. The engine's own breaker is not used: it would end a column
# before an upright mark, which it sees as an object, and it counts the space after a
# column's last word against the column.
func _break(server: TextServer, buffer: RID, source: String) -> Array[RID]:
	if wrap_height <= 0 or source.is_empty() or server.shaped_text_get_width(buffer) <= wrap_height:
		return [buffer]
	var plain := server.create_shaped_text()
	_add(server, plain, source)
	# A column too short for anything ends at every place the text may break.
	var ranges := server.shaped_text_get_line_breaks(plain, 1.0)
	var ends: PackedInt32Array = []
	for index in range(1, ranges.size(), 2):
		if ranges[index] < source.length() and (ends.is_empty() or ranges[index] > ends[-1]):
			ends.append(ranges[index])
	server.free_rid(plain)
	ends.append(source.length())
	# The length of each stretch between two places a column may end, and of the spaces that close it.
	var lengths: PackedFloat32Array = []
	var spaces: PackedFloat32Array = []
	lengths.resize(ends.size())
	spaces.resize(ends.size())
	var stretch := 0
	for glyph in server.shaped_text_sort_logical(buffer):
		while glyph.start >= ends[stretch]:
			stretch += 1
		var advance: float = glyph.advance * glyph.get("repeat", 1)
		lengths[stretch] += advance
		spaces[stretch] = spaces[stretch] + advance if source.unicode_at(glyph.start) == 0x20 else 0.0
	var columns: Array[RID] = []
	var first := 0
	var length := 0.0
	for index in ends.size() + 1:
		if index == ends.size() or (index > first and length + lengths[index] - spaces[index] > wrap_height):
			var from := ends[first - 1] if first else 0
			var to := ends[index - 1]
			while to > from + 1 and source.unicode_at(to - 1) == 0x20:
				to -= 1
			columns.append(server.shaped_text_substr(buffer, from, to - from))
			first = index
			length = 0.0
		if index < ends.size():
			length += lengths[index]
	return columns


# Whether the grapheme stands upright: by its first character, or as an emoji that a
# character lying along the line starts, such as a keycap.
func _stands(source: String, at: int, end: int) -> bool:
	if Orientation.of(source.unicode_at(at)) != 0:
		return true
	for index in range(at + 1, end):
		var code := source.unicode_at(index)
		if code == 0xFE0F or code == 0x20E3:
			return true
	return false


# The glyphs of an upright cluster, or nothing when it has to lie along the line: a bracket
# or a mark of kind 2 that the font gives no vertical form.
func _stand(server: TextServer, cluster: String) -> Dictionary:
	var shaped := server.create_shaped_text(TextServer.DIRECTION_LTR, TextServer.ORIENTATION_VERTICAL)
	server.shaped_text_add_string(shaped, cluster, font.get_rids(), font_size, font.get_opentype_features(), language)
	server.shaped_text_shape(shaped)
	var glyphs := server.shaped_text_get_glyphs(shaped)
	server.free_rid(shaped)
	if glyphs.is_empty():
		return {}
	var advance := 0.0
	for glyph in glyphs:
		advance += glyph.advance
		# The engine sets a colour glyph off the middle of the column.
		if glyph.font_rid.is_valid():
			glyph.offset.x = -server.font_get_glyph_advance(glyph.font_rid, glyph.font_size, glyph.index).x / 2.0
	if Orientation.of(cluster.unicode_at(0)) == 2:
		var first: Dictionary = glyphs[0]
		if not first.font_rid.is_valid() or first.index == server.font_get_glyph_index(first.font_rid, font_size, cluster.unicode_at(0), 0):
			return {}
	if advance <= 0.0:
		advance = font.get_height(font_size)
	return {glyphs = glyphs, advance = advance}


func _across(server: TextServer, column: RID) -> float:
	return server.shaped_text_get_ascent(column) + server.shaped_text_get_descent(column)


func _glyph(server: TextServer, canvas: RID, glyph: Dictionary, at: Vector2, color: Color, outline: int) -> void:
	if not glyph.font_rid.is_valid():
		# No font has the character: the engine's box with its code, as a Label draws.
		if glyph.index != 0 and outline == 0 and not glyph.flags & (TextServer.GRAPHEME_IS_VIRTUAL | TextServer.GRAPHEME_IS_EMBEDDED_OBJECT):
			server.draw_hex_code_box(canvas, glyph.font_size, at + glyph.offset, glyph.index, color)
		return
	if outline > 0:
		server.font_draw_glyph_outline(glyph.font_rid, canvas, glyph.font_size, outline, at + glyph.offset, glyph.index, color)
	else:
		server.font_draw_glyph(glyph.font_rid, canvas, glyph.font_size, at + glyph.offset, glyph.index, color)


func _draw(canvas: RID, at: Vector2, color: Color, extent: float, outline: int, base: Transform2D) -> void:
	_shape()
	var server := TextServerManager.get_primary_interface()
	var within := extent if extent > 0 else _size.y
	var x := at.x
	for index in _columns.size():
		var column := _columns[index]
		var start := _starts[index]
		var across := _across(server, column)
		var length := server.shaped_text_get_width(column)
		var y := at.y
		match alignment:
			Alignment.CENTER:
				y += floorf((within - length) / 2.0)
			Alignment.BOTTOM:
				y += within - length
		# The top of the line faces right, so the line hangs from the column's right edge.
		var origin := Vector2(x + across, y)
		var ascent := server.shaped_text_get_ascent(column)
		RenderingServer.canvas_item_add_set_transform(canvas, base * TURN.translated(origin))
		var pen := Vector2(0, ascent)
		for glyph in server.shaped_text_get_glyphs(column):
			var shown: bool = visible_characters < 0 or start + glyph.start < visible_characters
			for again in glyph.get("repeat", 1):
				if shown:
					_glyph(server, canvas, glyph, pen, color, outline)
				pen.x += glyph.advance
		RenderingServer.canvas_item_add_set_transform(canvas, base)
		for key in server.shaped_text_get_objects(column):
			var stood: Dictionary = _upright[key]
			if visible_characters >= 0 and stood.start >= visible_characters:
				continue
			# The cell is measured from the baseline.
			var cell := server.shaped_text_get_object_rect(column, key)
			var top := Vector2(origin.x - ascent - cell.position.y - cell.size.y / 2.0, origin.y + cell.position.x)
			for glyph in stood.glyphs:
				_glyph(server, canvas, glyph, top, color, outline)
				top.y += glyph.advance
		x += across + column_spacing
