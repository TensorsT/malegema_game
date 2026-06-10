# MEMORY.md — 项目长期记忆

## 项目基本信息
- **项目名**：Malegema Game（麻将消除 Roguelite）
- **引擎**：Godot 4，主要 GDScript + C#（first_demo.csproj）
- **工作区**：`d:\malegema_game\first-demo(0.1.0)\`
- **游戏类型**：麻将消除 + Roguelite deck building，类似 Balatro 风格

## 游戏流程
```
主菜单(gameStar.tscn) → 游戏板(board.tscn) → 结算(run_end.tscn) → 奖励(run_reward.tscn) → 商店(run_shop.tscn) → 循环
```
- `RunManager`（autoload）管理全局游戏状态 run/deck/levels
- `SaveManager` 负责存档（JSON，仅存当前棋盘+game_state）

## 关键已知Bug（已修复）
1. ~~**存档继续游戏**~~ ✅ 已修复：`board.gd` `_load_saved_board()` 加入 `SaveManager.restore_run_manager(save_data)` 调用
2. ~~**奖励界面**~~ ✅ 已修复：`run_reward.gd` 改为 Panel + TextureRect 渲染真实牌面图
3. ~~**调试种子信息**~~ ✅ 已修复：`board.gd` 移除种子显示，删除 `_get_run_seed_text()`，同时修正 `round` 变量遮蔽 bug

## 核心机制
- **消除**：两张相同牌（frog↔lotus 同色可配；flower 任意配）
- **材质**：bone→低级材质→高级材质（3张合成升级，仅在商店，非游戏板）
- **得分**：基础分 + 材质加成 + 龙/凤凰连击倍率
- **模块**：dragons/phoenixes/gems/mutations/winds/jokers

## 设计问题与建议方向
- 时间惩罚改为可见倒计时奖励窗口（非扣分）
- 目标分数改为基于实际牌组动态计算
- HUD 增加进度条、连击显示
- 结算界面增加入场动画和数字滚动

## 开发约定
- UI 通过 `WhatajongUI.gd` 统一管理样式（按钮/面板/字体）
- 游戏逻辑全部静态函数（GameLoop/RunState/SetupTiles 等 RefCounted）
- 字体：BraveGates.otf（项目自带）
- 牌面图片：`res://tiles/{cardId}.webp`
- 音效：click.mp3/gemstone.mp3 在 `res://sounds/`
