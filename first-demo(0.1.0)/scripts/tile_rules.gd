extends RefCounted
class_name TileRules

# TileRules: 麻将牌（Tile）的规则判断工具类
# 提供牌面位置计算、重叠检测、自由度判断等静态方法


## 将位置字典转换为 "x,y,z" 格式的字符串坐标，用于唯一标识
static func coord(position: Dictionary) -> String:
	return "%d,%d,%d" % [int(position["x"]), int(position["y"]), int(position["z"])]


## 从三维地图数组中安全地获取指定坐标的值
# 坐标越界或值为 null 时返回 null
static func map_get(map: Array, x: int, y: int, z: int):
	if x < 0 or y < 0 or z < 0:
		return null
	if z >= map.size():
		return null

	var level: Array = map[z]
	if y >= level.size():
		return null

	var row: Array = level[y]
	if x >= row.size():
		return null

	var value = row[x]
	if value == null:
		return null

	return str(value)


## 获取地图的宽度（X轴大小）
static func map_get_width(map: Array) -> int:
	if map.is_empty():
		return 0
	if (map[0] as Array).is_empty():
		return 0
	return (map[0] as Array)[0].size()


## 获取地图的高度（Y轴大小）
static func map_get_height(map: Array) -> int:
	if map.is_empty():
		return 0
	return (map[0] as Array).size()


## 获取地图的层数（Z轴大小）
static func map_get_levels(map: Array) -> int:
	return map.size()


## 检查指定位置在 z_offset 层是否存在相邻的牌（3x3范围）
# 用于判断当前位置是否被上层的牌覆盖
static func overlaps(tile_db: Dictionary, position: Dictionary, z_offset: int):
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var tile = _find_tile(tile_db, position, dx, dy, z_offset)
			if tile != null:
				return tile
	return null


## 检查指定位置在 z_offset 层是否被完全覆盖
# 完全覆盖的条件：中心有牌，或成对的边/角有牌阻挡
static func fully_overlaps(tile_db: Dictionary, position: Dictionary, z_offset: int) -> bool:
	var left = _find_tile(tile_db, position, -1, 0, z_offset)
	var right = _find_tile(tile_db, position, 1, 0, z_offset)
	var top = _find_tile(tile_db, position, 0, -1, z_offset)
	var bottom = _find_tile(tile_db, position, 0, 1, z_offset)
	var top_left = _find_tile(tile_db, position, -1, -1, z_offset)
	var top_right = _find_tile(tile_db, position, 1, -1, z_offset)
	var bottom_left = _find_tile(tile_db, position, -1, 1, z_offset)
	var bottom_right = _find_tile(tile_db, position, 1, 1, z_offset)
	var center = _find_tile(tile_db, position, 0, 0, z_offset)

	return bool(
		center
		or (left and right)
		or (top and bottom)
		or (top_left and bottom_right)
		or (top_right and bottom_left)
		or (top_left and top_right and bottom_left)
		or (top_left and top_right and bottom_right)
		or (top_left and bottom_left and bottom_right)
		or (top_right and bottom_left and bottom_right)
		or (top_left and top_right and bottom_left and bottom_right)
	)


## 判断一张牌是否可以被选中（消除）
# 条件：未被删除、上层无覆盖、且左右至少有一侧未被阻挡（或材质为特殊牌）
static func is_free(tile_db: Dictionary, tile: Dictionary) -> bool:
	if bool(tile.get("deleted", false)):
		return false
	if overlaps(tile_db, tile, 1):
		return false

	var material := String(tile.get("material", "bone"))
	if material == "topaz" or material == "sapphire":
		return true

	var freedoms = _get_freedoms(tile_db, tile)
	return bool(freedoms["left"] or freedoms["right"])


## 获取 tile_db 中所有可被选中（消除）的牌
static func get_free_tiles(tile_db: Dictionary) -> Array[Dictionary]:
	var free_tiles: Array[Dictionary] = []
	for tile in tile_db.values():
		var tile_dict := tile as Dictionary
		if bool(tile_dict.get("deleted", false)):
			continue
		if is_free(tile_db, tile_dict):
			free_tiles.append(tile_dict)

	return free_tiles


## 检查指定位置四周的自由度（是否被其他牌阻挡）
# 返回字典：left/right/top/bottom 为 true 表示该方向可通行（无阻挡）
static func _get_freedoms(tile_db: Dictionary, position: Dictionary) -> Dictionary:
	var has_left = _find_tile(tile_db, position, -2, -1, 0) or _find_tile(tile_db, position, -2, 0, 0) or _find_tile(tile_db, position, -2, 1, 0)
	var has_right = _find_tile(tile_db, position, 2, -1, 0) or _find_tile(tile_db, position, 2, 0, 0) or _find_tile(tile_db, position, 2, 1, 0)
	var has_top = _find_tile(tile_db, position, -1, -2, 0) or _find_tile(tile_db, position, 0, -2, 0) or _find_tile(tile_db, position, 1, -2, 0)
	var has_bottom = _find_tile(tile_db, position, -1, 2, 0) or _find_tile(tile_db, position, 0, 2, 0) or _find_tile(tile_db, position, 1, 2, 0)

	return {
		"left": not bool(has_left),
		"right": not bool(has_right),
		"top": not bool(has_top),
		"bottom": not bool(has_bottom),
	}


## 在 tile_db 中查找相对指定位置偏移 (dx, dy, dz) 的牌
# 返回找到的牌字典，未找到则返回 null
static func _find_tile(tile_db: Dictionary, position: Dictionary, dx: int, dy: int, dz: int):
	var tx := int(position["x"]) + dx
	var ty := int(position["y"]) + dy
	var tz := int(position["z"]) + dz

	for tile_id in tile_db.keys():
		var tile: Dictionary = tile_db[tile_id]
		if bool(tile.get("deleted", false)):
			continue
		if int(tile["x"]) == tx and int(tile["y"]) == ty and int(tile["z"]) == tz:
			return tile

	return null
