# Malegema Game — 完整优化设计方案 v1.0

> 编写时间：2026-06-10  
> 作者：GodotGameplayScripter  
> 状态：方案阶段（不修改代码，仅设计）

---

## 一、项目现状总结（通读代码后的诊断）

### 1.1 游戏流程架构

```
主菜单(gameStar.tscn)
  ↓ 新游戏/继续
教程场景(tutorial.tscn) [STAGE_INTRO]
  ↓
游戏主板(board.tscn) [STAGE_GAME]
  → board.gd → GameLoop → SetupTiles/TileRules
  → 消除触发 → 结算 → run_end.tscn [STAGE_SETTLEMENT]
  ↓ 胜利
奖励场景(run_reward.tscn) [STAGE_REWARD]
  ↓
商店场景(run_shop.tscn) [STAGE_SHOP]
  ↓
回到 board.tscn 下一回合 [round++]
```

### 1.2 核心机制

| 机制 | 现状 | 问题 |
|------|------|------|
| **配对消除** | 两张相同牌配对消除（flower 任意配、frog↔lotus 同色） | 正确实现 |
| **分数系统** | 基础分 + 材质加成 + 龙/凤凰连击倍率 | 分数数值感弱，变化不直观 |
| **时间惩罚** | `penalty = time × timerPoints`，从总分扣减 | 设计存在根本问题（见下） |
| **目标分数** | 每关随机生成，有 85% 上界防止超高 | 初始40分 + 指数增长，曲线不合理 |
| **背包/牌组** | 从 deck 随机抽 20 张上牌桌 | 发牌逻辑与规则意图脱节 |
| **材质升级** | 3张同材质 → 1张升级材质（合成规则）| 这正是"三张合成新牌"的规则 |
| **模块系统** | dragons/phoenixes/gems/mutations/winds/jokers | 丰富但没有充分利用 |
| **存档** | JSON 存盘，只存当前牌局 board+game_state | 存档机制有漏洞 |
| **商店** | 购买牌/升级材质，冻结/重抽 | 功能完整但 UI 呈现差 |
| **奖励** | 通关后免费领牌 | `run_reward.gd` 仅用 Label 显示 cardId 文字，未渲染真实牌 |

---

## 二、核心问题诊断

### 🔴 P0：游戏性设计问题（最影响趣味性）

#### 问题1：时间惩罚设计本末倒置

**现状**：`total_points = points - time × timerPoints`

- `timerPoints` 在 easy 难度下约为 `(level * 0.3 + 1.02^level) / 20 * variation`
- 第1回合约为 0.05~0.08 分/秒，第10回合约为 0.3~0.5 分/秒
- **根本问题**：玩家看不到倒计时！只有一个"预计结算"数字在悄悄减少，完全没有紧迫感
- **玩家实际感受**：慢慢点牌，反正分数够就行，时间惩罚难以感知

**设计意图**：想要鼓励快速消除，但实现方式让玩家感知不到压力。

#### 问题2：目标分数设计不合理

**现状**：`pointObjective = round((40 + level * lin + level^exp) * variation)`

- 第1关：约40分目标
- 第5关：medium难度约 `40 + 5*10 + 5^2.1 = 40+50+29 = 119` 分
- 但 deck 只有27张初始牌（9×bam/crack/dot），上桌20张，全消最多约 40 分（每对2分）

**根本问题**：目标分数增长速度 >> 实际可得分数增长速度！已有 `_remember_round_max_points` 做了 85% 上界补丁，但这是治标不治本的hack。

#### 问题3："三张合成"规则隐藏太深，玩家不理解

**现状**：`_merge_counts` 函数实现了"3骨牌→1基础材质，3基础材质→1高级材质"的合成逻辑。

但这个逻辑**只在商店升级时发生**，并不是游戏中的实时消除规则！

**玩家困惑**：
- "三张一样的牌会合成新牌"——这是商店里用金币买升级的机制
- 实际游戏板上：就是普通的两两配对消除
- 没有任何 UI 解释这个材质升级与消除的关系

#### 问题4：发牌逻辑设计混乱

**现状**：`board.gd` 从 deck 随机抽 20 张放上桌。

问题：
- 每回合 deck 里牌的数量不同（初始27张，可以买更多）
- 随机抽取导致可能拿到一堆同花色牌或相反拿不到可配对的牌
- `SetupTiles` 虽然保证布局可解，但它假设 deck 里每种牌都成对出现
- 实际代码：`for deck_tile in deck: pairs.append([deck_tile, deck_tile])` 直接用每张牌做一对
- 这意味着：桌上的牌是 deck 的子集，每张牌对应桌上一对，共40张……但只抽了20张？**有bug**

**真实bug发现**：`var table_count: int = int(min(RunManager.deck.size(), 20))` 抽了20张，然后 `SetupTiles.setup_tiles(rng, deck)` 接受这20张 deck，为每张创建一对，即40个格子。但布局大小是根据 `deck.size() * 2 = 40` 来的，基本正确。不过这导致有时候牌面重复率很高（例如20张里有很多 bam1，桌上就有很多 bam1 对）。

---

### 🟡 P1：代码质量和功能Bug

#### 存档Bug

**问题**：`save_manager.gd` 的 `restore_run_manager` 方法被定义了，但 `start_menu.gd` 的继续游戏流程是：

```gdscript
# start_menu.gd:76
func _on_continue_button_pressed() -> void:
    var save_data := SaveManager.load_game()
    if save_data.is_empty():
        ...
    SaveManager.request_restore()
    RunManager.enter_stage(RunManager.STAGE_GAME)  # ← 直接进入游戏
```

然后 `board.gd:83` 的 `_ready()` 里：
```gdscript
if SaveManager.consume_restore():
    _load_saved_board()
```

**但 `RunManager` 的 `run`/`deck`/`levels` 数据没有被恢复！**

`SaveManager.restore_run_manager(data)` 函数从未被调用过！这意味着继续游戏时，RunManager 是空的，只有牌局布局被恢复，而 round/money/items 全部丢失。

#### 奖励界面严重缺失

`run_reward.gd:59` 仅显示 `cardId` 的文字标签，完全没有渲染奖励牌的视觉展示，与商店界面的完整牌面渲染相比极其粗糙。

#### 商店升级按钮逻辑Bug

`run_shop.gd:190-194`：
```gdscript
if upgrade_paths.is_empty():
    buy_button.pressed.connect(_on_buy_pressed.bind(item))
else:
    buy_button.disabled = true  # ← 有升级路线时购买按钮被禁用
```

意味着有升级路线的牌无法直接购买新的（骨牌版），只能升级。但玩家可能想要多买几张骨牌。这是设计决定还是bug需要确认。

#### `_get_run_seed_text` 调试信息暴露给玩家

`board.gd:611-614`：在分数栏里显示种子ID，这是调试信息不应该在正式游戏中显示。

---

### 🟢 P2：UI/UX 问题

#### 游戏主板信息密度太低/太高

- `score_label` 里放了"已有分数/过关分数/预计结算/种子"全部文字内容，挤在一起
- 没有可视化进度条
- 时间没有倒计时UI，只有计时器在后台跑

#### 结算界面信息太朴素

`run_end.gd` 用纯文字列表展示结果，缺乏视觉冲击：
- 没有胜利/失败动画
- 没有分数滚动动画
- 没有奖励硬币飞入动画

#### 商店界面 item 按钮只显示 cardId 字符串

`_format_item_button_text` 返回 `"bam1    $3    竹"` 这样的文字，没有牌面缩略图。

---

## 三、关于"三张合成"规则的深度设计思考

### 3.1 现有机制的本质

现在的"合成"发生在**商店购买时**：

```
3张bone同类牌 → 1张低级材质（topaz/garnet/jade/quartz）
3张低级材质   → 1张高级材质（sapphire/ruby/emerald/obsidian）
```

材质决定牌的分值倍率：
- bone：+0分
- topaz/quartz/garnet：+1分
- jade：+2分
- sapphire/obsidian/ruby：+24分
- emerald：+48分

这实际上是一个**deck building + material upgrade**系统，类似 Balatro 的筹码升级。

### 3.2 将"合成"带入游戏板：两种设计方向

#### 方向A：保持现状（只在商店合成），重点优化感知

优点：逻辑简单，不破坏现有代码
改进方向：
- 在商店界面加入"合成预览动画"
- 在结算界面展示"你的牌升级了：3骨牌 → 1黄玉"

#### 方向B：在游戏板上加入"三连消除"升级触发（推荐）

设计：当玩家连续消除同一花色的3对牌时（如3对bam牌），触发"升级事件"：
- 一道金光扫过
- 状态栏提示"竹牌升华！+材质奖励"
- 本局得分+bonus，或者下回合商店免费获得对应材质升级一次

这种设计让"合成"感知更直接，但需要新增 `combo_tracker` 状态。

**推荐方向B的轻量实现**：不改变商店材质系统，只增加视觉反馈层。

---

## 四、完整优化方案 Plan

### Phase 1：修复关键Bug（优先级最高，安全）

---

#### 【P1-1】修复存档继续游戏时 RunManager 数据丢失

**文件**：`scripts/start_menu.gd`

**问题**：`SaveManager.restore_run_manager(data)` 从未被调用。

**修复方案**：
```gdscript
# start_menu.gd - _on_continue_button_pressed
func _on_continue_button_pressed() -> void:
    status_label.text = "继续游戏..."
    var save_data := SaveManager.load_game()
    if save_data.is_empty():
        status_label.text = "没有存档，开始新游戏..."
        RunManager.start_new_run()
        RunManager.enter_stage(RunManager.STAGE_GAME)
        return
    
    # ← 关键：先恢复 RunManager 状态
    SaveManager.restore_run_manager(save_data)
    SaveManager.request_restore()
    RunManager.enter_stage(RunManager.STAGE_GAME)
```

**影响范围**：仅 start_menu.gd，一行改动，安全。

---

#### 【P1-2】修复奖励界面只显示文字cardId

**文件**：`scripts/run_reward.gd`

**问题**：`_build_rewards()` 只加了 Label 文字。

**修复方案**：复用商店界面的 `_detail_tile` 模式，用 `Tile` 场景实例渲染每张奖励牌。

```gdscript
# 在 _build_rewards() 的 for item in _reward_items 循环中：
var tile_node := TILE_SCENE.instantiate() as Tile
var card_id := String(item.get("cardId", ""))
var texture := _get_icon(card_id)
tile_node.setup("reward_" + card_id, card_id, texture, "bone")
tile_node.set_base_scale(Vector2(0.9, 0.9))
tile_node.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不可点击
rewards_container.add_child(tile_node)
```

**影响范围**：仅 run_reward.gd，低风险。

---

#### 【P1-3】移除调试信息（种子显示）

**文件**：`scripts/board.gd`

**问题**：`_update_score_label()` 显示种子ID。

**修复方案**：
```gdscript
# 修改 _update_score_label()，移除种子行
# 或改为仅在调试构建中显示（使用 OS.is_debug_build()）
```

---

### Phase 2：时间系统重设计（核心游戏性改善）

---

#### 【P2-1】将隐性时间惩罚 → 可见倒计时

**现状**：时间在后台计时，结算时扣分，玩家无感知。

**新设计**：增加一个可视化倒计时进度条（不是强制游戏结束，而是"时间奖励窗口"）。

**设计逻辑**：
- 每关有一个"满分时间窗口"（如第1关90秒）
- 在这个时间内清空棋盘，获得时间奖励金币（不是更高分，而是额外金币）
- 超出时间后不结束游戏，但不再有时间奖励

这样改变了惩罚感 → 奖励感，心理体验截然不同。

**实现**：
- `board.gd` 增加 `ProgressBar` 节点作为时间进度条
- 使用金色颜色，放在棋盘上方明显位置
- 时间耗尽时进度条变红并显示"时间奖励已错过"
- **不改变** `RunState.generate_round()` 的 `timerPoints` 计算，只改变 UI 展示逻辑

**具体数值调整建议**：
```
满分时间窗口 = max(60, deck.size() * 4) 秒
时间金币奖励 = ceil(remaining_time / 15.0)  # 每15秒一枚金币，最多4枚
```

---

#### 【P2-2】目标分数动态校准

**现状**：目标分数有 `roundMaxPoints * 0.85` 的上界补丁，但这个补丁本身就说明原始计算不可信。

**新设计**：完全基于实际牌组计算目标分数。

```gdscript
# 新的 generate_round 逻辑（在 run_manager.gd 的 get_round() 里）：
# 目标分 = 当前 deck 所有牌总理论得分 * 难度系数
# 这样目标分永远是"合理可达"的

static func calculate_objective_from_deck(deck: Array, difficulty: String) -> int:
    var base_score := 0
    for tile in deck:
        var dummy_state := {"dragon_run": {}, "phoenix_run": {}, "temporary_material": ""}
        base_score += GameLoop.get_points({"card_id": String(tile.get("cardId","")), 
                                           "material": String(tile.get("material","bone"))}, dummy_state) * 2
    
    var multiplier := 0.65  # easy: 需要65%的理论满分才能过关
    match difficulty:
        "medium": multiplier = 0.72
        "hard": multiplier = 0.80
    
    return int(ceil(float(base_score) * multiplier))
```

**影响**：这让每关目标分"跟着玩家的牌组成长"，越强的牌组要求越高的分数，保持适当挑战。

---

### Phase 3：游戏性增强（关卡挑战性和趣味性）

---

#### 【P3-1】连击系统可视化与扩展

**现状**：龙连击倍率（dragon_combo）在内部计算但**玩家看不到当前连击数**！

**新设计**：在游戏板右上角增加一个连击显示区：

```
🐉 龙连击：×3
🔥 凤凰段：[1][2][●]...
💨 风向：→
```

实现方式：
- 在 `board.gd` 的 `_update_score_label()` 旁边增加 `_update_combo_display()` 
- 读取 `game_state["dragon_run"]` 和 `game_state["phoenix_run"]`
- 用 Tween 做连击数字跳动动画（从大缩回正常大小）

---

#### 【P3-2】连续消除"连击音效"阶梯

**现状**：只有一个匹配音效 `gemstone.mp3`，每次消除都一样。

**新设计**：根据连击次数升调：

```gdscript
# board.gd 的 _play_match_sound()
func _play_match_sound() -> void:
    var combo := int((game_state.get("dragon_run", {}) as Dictionary).get("combo", 0))
    var base_pitch := 1.0 + combo * 0.05  # 每级连击音调+5%
    match_player.pitch_scale = base_pitch * randf_range(0.97, 1.03)
    match_player.play()
```

---

#### 【P3-3】关卡特殊事件（保守实现）

每5回合触发一个"特殊事件"，增加变化感。事件类型（只需在 `RunManager.generate_round()` 的返回值里加一个 `event` 字段）：

| 事件 | 效果 | 实现难度 |
|------|------|---------|
| **黄金消除** | 本回合所有消除得分×1.5 | 低：在 `game_state` 加一个 `golden_round: bool` |
| **风暴关** | 每20秒自动触发一次随机风向 | 中：在 `_process()` 加计时器 |
| **迷雾关** | 部分牌面被遮住，消除后揭示 | 高：暂不实现 |
| **极速关** | 时间奖励窗口减半但金币奖励翻倍 | 低：调整参数 |

**Phase 3 只实现"黄金消除"事件**，其余作为后续版本内容。

---

#### 【P3-4】发牌逻辑修复与优化

**现状问题**：从 deck 随机抽20张，可能抽到偏多重复牌型（如10张bam1），导致棋盘布局无聊。

**新发牌规则**：
```gdscript
# 修改 board.gd 的 _setup_new_round()
# 新逻辑：每种 cardId 最多出现 3 次（对应3对 = 6张棋盘位置）
# 优先保证所有牌型都有代表，然后补充配额

func _pick_balanced_deck(source: Array[Dictionary], target_count: int) -> Array[Dictionary]:
    # 1. 先对每种cardId各取1张
    # 2. 随机补足剩余配额（每种最多3张）
    # 3. 洗牌
```

**影响**：棋盘上牌型更多样，消除体验更丰富。

---

### Phase 4：UI/UX 全面升级

---

#### 【P4-1】游戏主板 HUD 重设计

**现状**：TitleLabel + ScoreLabel + StatusLabel 三行文字，信息混杂。

**新设计布局**（不需要改场景结构，用代码控制显示）：

```
┌────────────────────────────────────────┐
│ 第3回合          🐉×3  🔥●●○○○     🪙12 │  ← 顶部状态栏
├────────────────────────────────────────┤
│                                        │
│           [ 棋  盘  区  域 ]           │
│                                        │
├────────────────────────────────────────┤
│ 得分：47 / 65  [████████░░░░] 72%     │  ← 进度条
│ ⏱ [══════════════════════░░░] 还有32s  │  ← 时间条（金色）
├────────────────────────────────────────┤
│ [重来]  [背包]  [保存退出]             │  ← 操作栏
└────────────────────────────────────────┘
```

**具体代码改动**：
- 增加 `ProgressBar` 节点用于分数进度（绿色）
- 增加 `ProgressBar` 节点用于时间（金色→红色）
- 连击信息移到顶部右侧
- 金币移到顶部右侧

---

#### 【P4-2】分数进度条动画

在每次消除后，用 Tween 让进度条平滑填充：

```gdscript
func _animate_score_progress(new_points: int, objective: int) -> void:
    var target := float(new_points) / float(objective)
    var score_tween := create_tween()
    score_tween.tween_property(score_bar, "value", target * 100.0, 0.35)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    
    # 超过100%时变金色闪烁
    if new_points >= objective:
        score_tween.tween_callback(_play_objective_reached_effect)
```

---

#### 【P4-3】结算界面动画升级

**现状**：纯文字结果，无任何动画。

**新设计**：

1. **进入动画**：Panel 从屏幕下方滑入（0.4秒，EASE_OUT_BACK）
2. **数字滚动**：得分从0滚动到结果数字（0.8秒）
3. **胜利效果**：
   - 撒金币粒子（复用 MatchParticles 系统）
   - 标题 "通关！" 字体放大后弹回
   - 播放专属胜利音效（可复用/变调现有音频）
4. **失败效果**：
   - 屏幕轻微红色闪烁
   - 标题 "未通过" 左右摇晃动画
   - 播放偏低沉的音效

实现要点（`run_end.gd`）：
```gdscript
func _ready() -> void:
    _apply_ui()
    end_panel.modulate.a = 0.0  # 初始透明
    end_panel.position.y += 80  # 初始偏下
    _update_summary()
    _play_enter_animation()  # 新增

func _play_enter_animation() -> void:
    var enter_tween := create_tween()
    enter_tween.set_parallel(true)
    enter_tween.tween_property(end_panel, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
    enter_tween.tween_property(end_panel, "position:y", 0.0, 0.4)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    enter_tween.chain()
    enter_tween.tween_callback(_play_result_effect)
```

---

#### 【P4-4】商店界面 item 行增加牌面缩略图

**现状**：`_format_item_button_text` 只返回文字（"bam1  $3  竹"）

**新设计**：将商品列表的按钮替换为含图标的自定义行：

```
┌────────────────────────────────────────┐
│  [牌图] 竹 1       点数1  已有:3张   │  [购买$3]
│         绿色路线  骨×3               │  [升级▲]
└────────────────────────────────────────┘
```

具体实现：在 `_build_item_row()` 里，`select_button` 替换为一个带 `TextureRect`（牌的缩略图）+ 文字的 `HBoxContainer`，参考 deck 视图里的 `_build_deck_row()`。

---

#### 【P4-5】背包弹窗 UI 优化

**现状**：`inventory_popup.gd` 的具体实现需要查看，假设类似商店的文字列表。

**改进**：背包弹窗改为网格布局（GridContainer），每张牌显示为小缩略图，悬停显示详情。

---

### Phase 5：游戏设计深度增强（中期规划）

---

#### 【P5-1】"三连消除升华"视觉事件

**触发条件**：当玩家在一局中消除同一花色的≥3对牌时。

**视觉效果**：
- 触发瞬间：全屏轻微金色闪光（CPUParticles2D 爆发）
- 通知弹出：小型浮动文字 "+升华奖励 ×1" 从棋盘位置飘起消失
- 得分标签放大弹动

**游戏效果**：本局该花色的下一对消除额外+3分。

**实现**：在 `GameLoop.select_tile()` 的 matched 分支里，新增 "suit combo tracker"：

```gdscript
# game_state 里增加:
# "suit_combos": {"bam": 0, "crack": 0, "dot": 0, ...}
```

---

#### 【P5-2】关卡Boss机制（第10/20/24关）

为特定关卡加入"Boss"概念：
- 目标分数更高（×1.5）
- 棋盘布局固定使用特殊造型（心形、圆形等）
- 通关后掉落稀有奖励牌

**实现**：只需在 `RunState.get_levels()` 的对应关卡里增加 `"boss": true` 标记，`board.gd` 检测并调整显示。

---

#### 【P5-3】连击中断惩罚消除（Hazard Tiles）

某些特殊关卡里，棋盘上混入"炸弹牌"：
- 外观：带红色边框的特殊牌
- 规则：必须在X步内消除，否则爆炸扣分
- 触发：第15回合以后才引入

---

### Phase 6：存档系统强化

---

#### 【P6-1】自动存档

**现状**：只有手动点"保存退出"才存档。

**新设计**：在以下时机自动静默存档：
1. 进入商店时（`run_shop.gd._ready()`）
2. 进入结算时（`run_end.gd._ready()`）
3. 应用获得焦点变化时（`_notification` 检测 `NOTIFICATION_WM_WINDOW_FOCUS_OUT`）

```gdscript
# run_manager.gd 新增方法
func auto_save(board_tile_db: Dictionary = {}, board_game_state: Dictionary = {}) -> void:
    SaveManager.save_game(board_tile_db, board_game_state)
```

---

#### 【P6-2】多存档槽位（可选，低优先级）

为未来多存档做架构准备，路径改为 `user://save_slot_{n}.json`。

---

## 五、实施优先级路线图

```
🔴 立即修复（P0 Bug）
├── P1-1：存档继续游戏 RunManager 数据丢失
├── P1-3：移除调试种子信息
└── P1-2：奖励界面渲染真实牌面

🟡 本次迭代（核心游戏感）
├── P2-1：时间条可视化（改为奖励窗口）
├── P3-1：连击数字显示
├── P4-1：HUD 重新布局（增加进度条）
├── P4-3：结算界面进入动画
└── P4-2：分数进度条动画

🟢 下次迭代（趣味性深化）
├── P2-2：目标分数基于牌组动态计算
├── P3-4：平衡发牌逻辑
├── P4-4：商店商品行加牌图
├── P3-2：阶梯音效
└── P3-3：黄金消除事件

🔵 中期版本（深度设计）
├── P5-1：三连消除升华事件
├── P5-2：Boss关卡机制
├── P6-1：自动存档
└── P4-5：背包网格布局
```

---

## 六、需要讨论的设计决策

### 问题1：商店"有升级路线时禁用购买按钮"是设计意图还是Bug？

如果是设计意图（只能升级不能买新骨牌）：
- 应该在 UI 上做更清晰的说明，避免玩家困惑

如果是Bug（应该允许两种操作）：
- `buy_button.disabled = true` 改为 `buy_button.text = "加新牌 $X"`
- 升级按钮保持为升级路线

### 问题2：发牌数量是否应该动态变化？

现状：固定20张（10对）
建议：根据 deck 总量和回合数动态调整
- 回合 1-5：min(deck.size(), 16)张（8对）
- 回合 6-15：min(deck.size(), 20)张（10对）
- 回合 16+：min(deck.size(), 24)张（12对）

逐渐增加棋盘复杂度，增强挑战梯度。

### 问题3：时间机制要"惩罚"还是"奖励"？

当前设计是纯惩罚（扣分）。建议改为：
- **基础**：完全清空棋盘 = 通关（只要分数达标）
- **时间奖励**：在规定时间内完成 = 额外金币
- **时间压力**：可选的"极速模式"难度选项

---

## 七、代码质量改进建议（不改逻辑，只改可维护性）

### 7.1 类型安全增强

`board.gd` 中大量使用无类型 Dictionary 访问：
```gdscript
# 现状（危险）
var tile: Dictionary = tile_db[tile_id]

# 建议：虽然不能改为Resource，但可以加静态工具函数
# TileData.get_x(tile) -> int
# TileData.get_card_id(tile) -> String
```

### 7.2 game_state 信号化

`game_state` 是一个全局 Dictionary，任何地方都可以修改。
建议在 `board.gd` 里增加：
```gdscript
signal score_changed(new_score: int, delta: int)
signal combo_changed(combo_type: String, combo_count: int)
```

这样 HUD 组件通过信号更新，解耦 UI 和游戏逻辑。

### 7.3 重复代码抽取

`run_shop.gd` 和 `board.gd` 都有独立的图标加载逻辑（`_get_icon`/`_get_item_icon`），这应该统一到 `CardData` 或 `WhatajongUI` 里。

---

## 八、关于材质合成规则的最终设计建议

### 完整的"三张合成"规则说明文字（用于游戏内教程）

```
【材质升级系统】

每张牌都有材质：骨(bone) > 黄玉/石榴石/玉/石英 > 蓝宝石/红宝石/翡翠/黑曜石

在商店里，如果你拥有同一张牌的3个骨牌版本，
可以花费金币"升级"将它们合成为1张高材质牌：

  [骨][骨][骨] × 同一牌型 → [黄玉] 同牌型（点数+1）

继续积累到3张黄玉版本：
  [黄][黄][黄] → [蓝宝石]（点数+24！）

高级材质的分值远超初级，是突破分数天花板的关键策略！

注意：消除时"同色龙连击"可以叠加材质得分倍率，
龙×3 + 蓝宝石 = (24+2)×3 = 78分！每次消除！
```

---

*方案文档结束。后续实施请按优先级分批提交，每次改动范围控制在1-2个文件。*
