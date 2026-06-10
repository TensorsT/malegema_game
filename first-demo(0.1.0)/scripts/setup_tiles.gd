extends RefCounted
class_name SetupTiles


# SetupTiles: 可解局面生成器
# 核心思想：先模拟消除过程证明布局可解，再把真实牌型按逆序回填。
# 复现 whatajong setupTiles.ts：
# 1) 用 dummy 牌在布局中反复抽取可消对。
# 2) 若无法清空则重试。
# 3) 将真实牌对按逆序回填，得到可解局面。


## 生成一个保证可解的牌局
# rng: 随机数生成器
# deck: 牌型定义数组，每种牌型需要成对出现
# 返回: tile_db 字典，key 为坐标字符串，value 为牌数据字典
static func setup_tiles(rng: RandomNumberGenerator, deck: Array[Dictionary]) -> Dictionary:
	var tile_db: Dictionary = {}

	# 从 ResponsiveMapData 获取关卡布局地图
	# deck.size() * 2 = 总牌数（每种牌型需要两张）
	var map: Array = ResponsiveMapData.get_limited_map(deck.size() * 2)

	# 遍历地图的每个格子，用 dummy 占位牌填满有效槽位
	for z in range(TileRules.map_get_levels(map)):
		for y in range(TileRules.map_get_height(map)):
			for x in range(TileRules.map_get_width(map)):
				var tile_id = TileRules.map_get(map, x, y, z)

				# 去重检测：检查左边和上边是否已有相同 ID 的 tile
				# 地图中同一个 ID 字符串可能覆盖多个相邻格子（表示一张大 tile）
				# 只检查左/上是因为遍历顺序是从左到右、从上到下，右/下还未处理
				var prev_id = TileRules.map_get(map, x - 1, y, z)
				var above_id = TileRules.map_get(map, x, y - 1, z)
				var same_as_prev = prev_id != null and prev_id == tile_id
				var same_as_above = above_id != null and above_id == tile_id

				# 只有当前格子有效、且不与左/上重复时，才创建 tile
				if tile_id != null and not same_as_prev and not same_as_above:
					tile_db[tile_id] = {
						"id": tile_id,
						"card_id": "bam1",      # dummy 占位牌型，不区分具体牌面
						"material": "bone",
						"x": x,
						"y": y,
						"z": z,
						"deleted": false,
						"selected": false,
					}

	# pick_order: 记录模拟消除的顺序
	# 后续逆序回填时，先被消掉的牌会被后放置
	var pick_order: Array[Dictionary] = []

	# 模拟消除过程：不断从当前可选牌中随机抽对消掉
	# 不检查牌型是否匹配（全是 dummy "bam1"），只验证位置结构是否可解
	while true:
		var free_tiles := TileRules.get_free_tiles(tile_db)
		if free_tiles.size() <= 1:
			break

		while free_tiles.size() > 1:
			# 随机选第一张 free tile
			var idx1 := int(floor(rng.randf() * free_tiles.size()))
			var tile1: Dictionary = free_tiles[idx1]
			free_tiles.remove_at(idx1)

			# 随机选第二张 free tile
			var idx2 := int(floor(rng.randf() * free_tiles.size()))
			var tile2: Dictionary = free_tiles[idx2]
			free_tiles.remove_at(idx2)

			# 从 tile_db 中移除，模拟消除
			tile_db.erase(tile1["id"])
			tile_db.erase(tile2["id"])

			# 记录消除顺序
			pick_order.append(tile1)
			pick_order.append(tile2)

	# 死局检测：如果模拟结束后还有剩余牌，说明此布局不可解
	# 递归重试，直到找到可完全清空的布局（拒绝采样策略）
	if tile_db.size() > 0:
		return setup_tiles(rng, deck)

	# 准备真实牌型对：每种牌型需要两张相同的牌
	var pairs: Array = []
	for deck_tile in deck:
		pairs.append([deck_tile, deck_tile])

	# 打乱牌型对的顺序，让每局牌型分布不同
	var shuffled_pairs: Array = _shuffle_array(pairs, rng)

	# 逆序回填：把真实牌型按 pick_order 的逆序放入位置
	# 核心原理：模拟时先被消掉的牌，在真实游戏中后被消掉
	# 因此把它们放在后面（逆序取），保证游戏开始时存在可解路径
	var result: Dictionary = {}
	for i in range(0, pick_order.size(), 2):
		# 从 pick_order 末尾逆序取（先消的牌后放）
		var tile1: Dictionary = pick_order[pick_order.size() - 1 - i]
		var tile2: Dictionary = pick_order[pick_order.size() - 2 - i]

		# 取一个打乱后的真实牌对
		var pair: Array = shuffled_pairs[int(i / 2.0)]
		var deck_tile1: Dictionary = pair[0]
		var deck_tile2: Dictionary = pair[1]

		# 从地图中获取该位置的原始 ID（字符串坐标）
		var id1 = TileRules.map_get(map, int(tile1["x"]), int(tile1["y"]), int(tile1["z"]))
		var id2 = TileRules.map_get(map, int(tile2["x"]), int(tile2["y"]), int(tile2["z"]))

		# 构造最终结果：位置信息来自 dummy 模拟，牌型信息来自 deck
		result[id1] = {
			"id": id1,
			"card_id": String(deck_tile1["cardId"]),
			"material": String(deck_tile1.get("material", "bone")),
			"x": int(tile1["x"]),
			"y": int(tile1["y"]),
			"z": int(tile1["z"]),
			"deleted": false,
			"selected": false,
		}
		result[id2] = {
			"id": id2,
			"card_id": String(deck_tile2["cardId"]),
			"material": String(deck_tile2.get("material", "bone")),
			"x": int(tile2["x"]),
			"y": int(tile2["y"]),
			"z": int(tile2["z"]),
			"deleted": false,
			"selected": false,
		}

	return result


## Fisher-Yates 洗牌算法
# 将输入数组随机打乱，返回新数组（不修改原数组）
static func _shuffle_array(input: Array, rng: RandomNumberGenerator) -> Array:
	var arr: Array = input.duplicate(true)
	for i in range(arr.size() - 1, 0, -1):
		var j := int(floor(rng.randf() * float(i + 1)))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
