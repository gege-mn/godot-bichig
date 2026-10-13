@tool
class_name BichigLabel
extends Control
## Sets text in the traditional Mongolian script: each column runs top to bottom, and the
## columns follow each other left to right.
##
## The engine shapes the text as a horizontal line, which is how a Mongolian font is drawn,
## and the label turns each line a quarter clockwise. Characters that Unicode stands upright
## in a vertical line (CJK, fullwidth forms, ‼, emoji) are set upright, in their vertical forms.

enum Alignment { TOP, CENTER, BOTTOM }

const Orientation := preload("orientation.gd")
const TURN := Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2.ZERO)

@export_multiline var text := "":
	set(value):
		text = value
		_queue_shape()
## Falls back to the theme's Label font.
@export var font: Font:
	set(value):
		if font and font.changed.is_connected(_queue_shape):
			font.changed.disconnect(_queue_shape)
		font = value
		if font:
			font.changed.connect(_queue_shape)
		_queue_shape()
## Zero falls back to the theme's Label font size.
@export_range(0, 256, 1, "or_greater", "suffix:px") var font_size := 0:
	set(value):
		font_size = value
		_queue_shape()
@export var font_color := Color.WHITE:
	set(value):
		font_color = value
		queue_redraw()
## Breaks a column that is longer than the label is tall.
@export var autowrap := true:
	set(value):
		autowrap = value
		_queue_shape()
@export var alignment := Alignment.TOP:
	set(value):
		alignment = value
		queue_redraw()
@export_range(-64, 64, 1, "or_less", "or_greater", "suffix:px") var column_spacing := 0.0:
	set(value):
		column_spacing = value
		_queue_shape()
@export var language := "mn":
	set(value):
		language = value
		_queue_shape()

var _paragraphs: Array[TextParagraph] = []
var _upright: Array[Dictionary] = []
var _width := 0.0
var _longest := 0.0
var _dirty := true
var _shaped_height := -1.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_queue_shape()
		NOTIFICATION_RESIZED:
			if autowrap and size.y != _shaped_height:
				_queue_shape()


func _get_minimum_size() -> Vector2:
	_shape()
	return Vector2(_width, 0.0 if autowrap else _longest)


## The number of columns the text takes at the label's height.
func get_column_count() -> int:
	_shape()
	var count := 0
	for paragraph in _paragraphs:
		count += paragraph.get_line_count()
	return count


func _queue_shape() -> void:
	_dirty = true
	update_minimum_size()
	queue_redraw()


func _font() -> Font:
	return font if font else get_theme_font(&"font", &"Label")


func _font_size() -> int:
	return font_size if font_size > 0 else get_theme_font_size(&"font_size", &"Label")


func _shape() -> void:
	if not _dirty:
		return
	_dirty = false
	_shaped_height = size.y
	_paragraphs.clear()
	_upright.clear()
	_width = 0.0
	_longest = 0.0
	var used := _font()
	var em := _font_size()
	if used == null:
		return
	var server := TextServerManager.get_primary_interface()
	var across := used.get_height(em)
	for source in text.split("\n"):
		var paragraph := TextParagraph.new()
		paragraph.width = size.y if autowrap and size.y > 0 else -1.0
		var run := ""
		var at := 0
		while at < source.length():
			var stop := _cluster(source, at)
			var stood := {} if stop == at else _stand(server, source.substr(at, stop - at), used, em)
			if stood.is_empty():
				stop = maxi(stop, at + 1)
				run += source.substr(at, stop - at)
			else:
				if run:
					paragraph.add_string(run, used, em, language)
					run = ""
				paragraph.add_object(_upright.size(), Vector2(stood.advance, across), INLINE_ALIGNMENT_CENTER, stop - at)
				_upright.append(stood)
			at = stop
		# An empty paragraph still takes a column.
		paragraph.add_string(run if run or at else " ", used, em, language)
		_paragraphs.append(paragraph)
		for line in paragraph.get_line_count():
			_width += _across(paragraph, line) + column_spacing
			_longest = maxf(_longest, paragraph.get_line_width(line))
	_width = maxf(_width - column_spacing, 0.0)


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
func _stand(server: TextServer, cluster: String, used: Font, em: int) -> Dictionary:
	var shaped := server.create_shaped_text(TextServer.DIRECTION_LTR, TextServer.ORIENTATION_VERTICAL)
	server.shaped_text_add_string(shaped, cluster, used.get_rids(), em, used.get_opentype_features(), language)
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
		if not first.font_rid.is_valid() or first.index == server.font_get_glyph_index(first.font_rid, em, cluster.unicode_at(0), 0):
			return {}
	if advance <= 0.0:
		advance = used.get_height(em)
	return {glyphs = glyphs, advance = advance}


func _across(paragraph: TextParagraph, line: int) -> float:
	return paragraph.get_line_ascent(line) + paragraph.get_line_descent(line)


func _draw() -> void:
	_shape()
	var canvas := get_canvas_item()
	var server := TextServerManager.get_primary_interface()
	var x := 0.0
	for paragraph in _paragraphs:
		for line in paragraph.get_line_count():
			var across := _across(paragraph, line)
			var y := 0.0
			match alignment:
				Alignment.CENTER:
					y = floorf((size.y - paragraph.get_line_width(line)) / 2.0)
				Alignment.BOTTOM:
					y = size.y - paragraph.get_line_width(line)
			# The top of the line faces right, so the line hangs from the column's right edge.
			var origin := Vector2(x + across, y)
			draw_set_transform_matrix(TURN.translated(origin))
			paragraph.draw_line(canvas, Vector2.ZERO, line, font_color)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			for key in paragraph.get_line_objects(line):
				var cell := paragraph.get_line_object_rect(line, key)
				var pen := Vector2(origin.x - cell.position.y - cell.size.y / 2.0, origin.y + cell.position.x)
				for glyph in _upright[key].glyphs:
					if glyph.font_rid.is_valid():
						server.font_draw_glyph(glyph.font_rid, canvas, glyph.font_size, pen + glyph.offset, glyph.index, font_color)
					pen.y += glyph.advance
			x += across + column_spacing
