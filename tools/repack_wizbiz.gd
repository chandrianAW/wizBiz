extends SceneTree

const FRAME_SIZE = 48
const FRAME_COUNT = 64
const SOURCE_PATH = "res://Player/wizbiz_source.png"
const OUTPUT_PATH = "res://Player/Wizard.png"

func _init():
	call_deferred("_generate_atlas")

func _generate_atlas():
	var source = Image.new()
	var error = source.load(SOURCE_PATH)
	if error != OK:
		printerr("Could not load WizBiz sprite sheet: ", error)
		quit(1)
		return

	source.lock()
	var columns = _occupied_runs(source, true)
	var rows = _occupied_runs(source, false)
	if columns.size() != 4 or rows.size() != 4:
		printerr("Expected a 4x4 WizBiz sheet, found ", columns.size(), " columns and ", rows.size(), " rows")
		source.unlock()
		quit(1)
		return

	var atlas = Image.new()
	atlas.create(FRAME_SIZE * FRAME_COUNT, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	atlas.lock()
	var source_frames = _frame_map()
	var source_bounds = []
	var largest_width = 0
	var largest_height = 0
	for source_frame in range(16):
		var bounds = _source_frame_bounds(source, source_frame, columns, rows)
		source_bounds.append(bounds)
		largest_width = max(largest_width, int(bounds.size.x))
		largest_height = max(largest_height, int(bounds.size.y))
	var sprite_scale = min(26.0 / largest_width, 28.0 / largest_height)
	for output_frame in range(FRAME_COUNT):
		_copy_frame(source, atlas, source_frames[output_frame], output_frame, source_bounds, sprite_scale)
	atlas.unlock()
	source.unlock()

	error = atlas.save_png(OUTPUT_PATH)
	if error != OK:
		printerr("Could not save wizard atlas: ", error)
		quit(1)
		return

	print("Generated ", OUTPUT_PATH, " from ", SOURCE_PATH)
	quit()

func _occupied_runs(image, scan_columns):
	var limit = image.get_width() if scan_columns else image.get_height()
	var cross_limit = image.get_height() if scan_columns else image.get_width()
	var runs = []
	var run_start = -1
	for position in range(limit):
		var occupied = false
		for cross_position in range(cross_limit):
			var pixel = image.get_pixel(position, cross_position) if scan_columns else image.get_pixel(cross_position, position)
			if pixel.a > 0.08:
				occupied = true
				break
		if occupied and run_start == -1:
			run_start = position
		elif not occupied and run_start != -1:
			runs.append(Vector2(run_start, position))
			run_start = -1
	if run_start != -1:
		runs.append(Vector2(run_start, limit))
	return runs

func _frame_map():
	var frames = []
	# Godot's atlas order is Down, Right, Up, Left; WizBiz rows are Down, Left, Right, Back.
	for source_row in [0, 2, 3, 1]:
		for pose in range(6):
			frames.append(source_row * 4 + pose % 4)
	for pose in [3, 2, 1, 0]:
		frames.append(8 + pose)
	frames.append(14)
	frames.append(13)
	frames.append(12)
	frames.append(15)
	for pose in [3, 2, 1, 0]:
		frames.append(pose)
	for pose in [3, 2, 1, 0]:
		frames.append(4 + pose)
	for source_row in [2, 3, 1, 0]:
		for pose in range(5):
			frames.append(source_row * 4 + pose % 4)
	for pose in range(4):
		frames.append(pose)
	return frames

func _source_frame_bounds(source, source_frame, columns, rows):
	var column = source_frame % 4
	var row = int(source_frame / 4)
	var cell_left = int(columns[column].x)
	var cell_right = int(columns[column].y)
	var cell_top = int(rows[row].x)
	var cell_bottom = int(rows[row].y)
	var min_x = cell_right
	var min_y = cell_bottom
	var max_x = cell_left - 1
	var max_y = cell_top - 1

	for y in range(cell_top, cell_bottom):
		for x in range(cell_left, cell_right):
			if source.get_pixel(x, y).a > 0.08:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _copy_frame(source, atlas, source_frame, output_frame, source_bounds, sprite_scale):
	var bounds = source_bounds[source_frame]
	var min_x = int(bounds.position.x)
	var min_y = int(bounds.position.y)
	var sprite_width = int(bounds.size.x)
	var sprite_height = int(bounds.size.y)
	var output_width = max(1, int(round(sprite_width * sprite_scale)))
	var output_height = max(1, int(round(sprite_height * sprite_scale)))
	var offset_x = int((FRAME_SIZE - output_width) / 2)
	var offset_y = FRAME_SIZE - 3 - output_height
	var output_left = output_frame * FRAME_SIZE

	for y in range(output_height):
		for x in range(output_width):
			var source_x = min_x + int((x + 0.5) * sprite_width / output_width)
			var source_y = min_y + int((y + 0.5) * sprite_height / output_height)
			var pixel = source.get_pixel(source_x, source_y)
			atlas.set_pixel(output_left + offset_x + x, offset_y + y, pixel)