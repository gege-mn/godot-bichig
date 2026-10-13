# godot-bichig

Vertical text for the traditional Mongolian script in Godot 4: columns run top to bottom and
follow each other left to right.

Godot shapes Mongolian correctly, but only along a horizontal line. Its controls have no
vertical mode, and the text server's `ORIENTATION_VERTICAL` stacks the letters one by one
without joining them. Turning a `Label` a quarter gives the right columns in the wrong order,
right to left.

`BichigLabel` lets the engine shape each line horizontally, turns it a quarter clockwise, and
lays the columns out left to right. Characters that Unicode stands upright in a vertical line
(CJK, fullwidth forms, `‼`, emoji) are set upright in their `vert` forms, as a browser sets
them under `writing-mode: vertical-lr`.

## Install

Copy `addons/bichig` into your project and enable **Bichig** under Project Settings → Plugins.
Godot 4.4 or later, with the default (advanced) text server.

## Use

Add a `BichigLabel` node, or from code:

```gdscript
var label := BichigLabel.new()
label.font = preload("res://fonts/my_mongolian_font.ttf")
label.font_size = 16
label.text = tr("GREETING")
add_child(label)
```

| Property | |
| --- | --- |
| `text` | A line break starts a new column. |
| `font`, `font_size` | Fall back to the theme's `Label` font and size. |
| `font_color` | |
| `autowrap` | Breaks a column longer than the label is tall. The label's minimum width follows the columns. |
| `alignment` | `TOP`, `CENTER` or `BOTTOM` within the label's height. |
| `column_spacing` | Extra pixels between columns. |
| `language` | Passed to the shaper; `mn` by default. |

### Pixel fonts

Import the font with antialiasing off, hinting none and subpixel positioning disabled, use a
whole multiple of its design size, and keep the label at whole-pixel positions. The label
turns the text with an exact matrix, so every pixel stays on the grid.

## Demo

Open the project in Godot and run it. It ships Noto Sans Mongolian (SIL OFL, see
`demo/fonts/OFL.txt`). To try another font:

    godot --path . -- path/to/font.ttf 16 3

The arguments are the font, its size and a window scale.

## Not yet

Text entry, rich text, a caret or selection, and justified columns.

## Development

`addons/bichig/orientation.gd` is generated from Unicode's `VerticalOrientation.txt`:

    python3 -I tools/orientation.py path/to/VerticalOrientation.txt

`tests/render.gd` sets a list of texts and writes the pixels back as text, to compare with
another renderer.

## License

MIT. The demo font is under the SIL Open Font License.
