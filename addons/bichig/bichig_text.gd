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

var _paragraphs: Array[TextParagraph] = []
var _starts: PackedInt32Array = []
var _upright: Array[Dictionary] = []
var _size := Vector2.ZERO
var _dirty := true


## Shape again after the font itself changed.
func invalidate() -> void:
	_dirty = true


## The width of the columns and the length of the longest one.
func get_size() -> Vector2:
	_shape()
	return _size


func get_column_count() -> int:
	_shape()
	var count := 0
	for paragraph in _paragraphs:
		count += paragraph.get_line_count()
	return count


## Draws the columns with their top left corner at [param at]. They are aligned within
## [param extent], or within the longest column when it is zero.
func draw(canvas: RID, at: Vector2, color := Color.WHITE, extent := 0.0) -> void:
	_draw(canvas, at, color, extent, 0)


func draw_outline(canvas: RID, at: Vector2, outline_size: int, color := Color.BLACK, extent := 0.0) -> void:
	if outline_size > 0:
		_draw(canvas, at, color, extent, outline_size)


func _shape() -> void:
	if not _dirty:
		return
	_dirty = false
	_paragraphs.clear()
	_starts.clear()
	_upright.clear()
	_size = Vector2.ZERO
	if font == null:
		return
	var server := TextServerManager.get_primary_interface()
	var across := font.get_height(font_size)
	var start := 0
	for source in text.split("\n"):
		var paragraph := TextParagraph.new()
		paragraph.width = wrap_height if wrap_height > 0 else -1.0
		var run := ""
		var at := 0
		while at < source.length():
			var stop := _cluster(source, at)
			var stood := {} if stop == at else _stand(server, source.substr(at, stop - at))
			if stood.is_empty():
				stop = maxi(stop, at + 1)
				run += source.substr(at, stop - at)
			else:
				if run:
					paragraph.add_string(run, font, font_size, language)
					run = ""
				stood.start = start + at
				paragraph.add_object(_upright.size(), Vector2(stood.advance, across), INLINE_ALIGNMENT_CENTER, stop - at)
				_upright.append(stood)
			at = stop
		# An empty paragraph still takes a column.
		paragraph.add_string(run if run or at else " ", font, font_size, language)
		_paragraphs.append(paragraph)
		_starts.append(start)
		start += source.length() + 1
		for line in paragraph.get_line_count():
			_size.x += _across(paragraph, line) + column_spacing
			_size.y = maxf(_size.y, paragraph.get_line_width(line))
	_size.x = maxf(_size.x - column_spacing, 0.0)


# The end of the upright cluster at `at`, or `at` when the character there lies along the line.
func _cluster(source: String, at: int) -> int:
	if Orientation.of(source.unicode_at(at)) == 0:
		return at
	var stop := at + 1
	while stop < source.length():
		var code := source.unicode_at(stop)
		if code == 0x200D and stop + 1 < source.length():
			stop += 2
		elif (code >= 0xFE00 and code <= 0xFE0F) or (code >= 0x1F3FB and code <= 0x1F3FF) or code == 0x20E3 or (code >= 0xE0020 and code <= 0xE007F) or (code >= 0xE0100 and code <= 0xE01EF):
			stop += 1
		else:
			break
	return stop


# The glyphs of an upright cluster, or nothing when it has to lie along the line: a bracket
# or a mark of kind 2 that the font gives no vertical form.
func _stand(server: TextServer, cluster: String) -> Dictionary:
	var shaped := server.create_shaped_text(TextServer.DIRECTION_LTR, TextServer.ORIENTATION_VERTICAL)
	server.shaped_text_add_string(shaped, cluster, font.get_rids(), font_size, font.get_opentype_features(), language)
	server.shaped_text_shape(shaped)
	var glyphs := server.shaped_text_get_glyphs(shaped)
	server.free_rid(shaped)
	var advance := 0.0
	for glyph in glyphs:
		advance += glyph.advance
	if glyphs.is_empty():
		return {}
	if Orientation.of(cluster.unicode_at(0)) == 2:
		var first: Dictionary = glyphs[0]
		if not first.font_rid.is_valid() or first.index == server.font_get_glyph_index(first.font_rid, font_size, cluster.unicode_at(0), 0):
			return {}
	if advance <= 0.0:
		advance = font.get_height(font_size)
	return {glyphs = glyphs, advance = advance}


func _across(paragraph: TextParagraph, line: int) -> float:
	return paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)


func _glyph(server: TextServer, canvas: RID, glyph: Dictionary, at: Vector2, color: Color, outline: int) -> void:
	if not glyph.font_rid.is_valid():
		return
	if outline > 0:
		server.font_draw_glyph_outline(glyph.font_rid, canvas, glyph.font_size, outline, at + glyph.offset, glyph.index, color)
	else:
		server.font_draw_glyph(glyph.font_rid, canvas, glyph.font_size, at + glyph.offset, glyph.index, color)


func _draw(canvas: RID, at: Vector2, color: Color, extent: float, outline: int) -> void:
	_shape()
	var server := TextServerManager.get_primary_interface()
	var within := extent if extent > 0 else _size.y
	var x := at.x
	for index in _paragraphs.size():
		var paragraph := _paragraphs[index]
		var start := _starts[index]
		for line in paragraph.get_line_count():
			var across := _across(paragraph, line)
			var y := at.y
			match alignment:
				Alignment.CENTER:
					y += floorf((within - paragraph.get_line_width(line)) / 2.0)
				Alignment.BOTTOM:
					y += within - paragraph.get_line_width(line)
			# The top of the line faces right, so the line hangs from the column's right edge.
			var origin := Vector2(x + across, y)
			RenderingServer.canvas_item_add_set_transform(canvas, TURN.translated(origin))
			var pen := Vector2(0, paragraph.get_line_ascent(line))
			for glyph in server.shaped_text_get_glyphs(paragraph.get_line_rid(line)):
				var shown: bool = visible_characters < 0 or start + glyph.start < visible_characters
				for again in glyph.get("repeat", 1):
					if shown:
						_glyph(server, canvas, glyph, pen, color, outline)
					pen.x += glyph.advance
			RenderingServer.canvas_item_add_set_transform(canvas, Transform2D.IDENTITY)
			for key in paragraph.get_line_objects(line):
				var stood: Dictionary = _upright[key]
				if visible_characters >= 0 and stood.start >= visible_characters:
					continue
				var cell := paragraph.get_line_object_rect(line, key)
				var top := Vector2(origin.x - cell.position.y - cell.size.y / 2.0, origin.y + cell.position.x)
				for glyph in stood.glyphs:
					_glyph(server, canvas, glyph, top, color, outline)
					top.y += glyph.advance
			x += across + column_spacing
