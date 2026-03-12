# Whatajong Python 版

麻将消除 Roguelite 游戏的 Python 实现，使用 Pygame。

## 安装

```bash
# 安装依赖
pip install -r requirements.txt

# 运行游戏
python main.py
```

## 操作说明

- **鼠标左键**: 选择/取消选择牌
- **空格键**: 显示提示
- **R 键**: 重新开始游戏
- **ESC 键**: 退出游戏

## 游戏规则

1. 点击可用的牌（左右至少有一侧自由的牌）
2. 匹配两张相同的牌进行消除
3. 花牌可以互相匹配
4. 消除所有牌即可通关

## 文件结构

```
python/
├── main.py          # 主游戏文件（Pygame 渲染和交互）
├── game.py          # 核心游戏逻辑（牌型定义、匹配规则、分数计算）
├── maps.py          # 地图和布局系统
├── requirements.txt # Python 依赖
└── README.md        # 本文件
```

## 与原版的区别

原版（TypeScript + SolidJS + Electron）功能更为完整，包括：
- 完整的 Roguelite 元素（商店、奖励、升级）
- 多种特殊牌型效果（龙、凤凰、青蛙、莲花等）
- 音效和动画
- 多语言支持

Python 版本目前实现了核心玩法：
- ✅ 麻将牌匹配消除
- ✅ 多层牌局布局
- ✅ 分数和金币系统
- ✅ 游戏结束判定
- ✅ 基础动画效果

## 开发

如需开发更多功能，可以参考原版代码：
- 原版位置：`/src/renderer/`
- 核心逻辑：`/src/renderer/lib/game.ts`
