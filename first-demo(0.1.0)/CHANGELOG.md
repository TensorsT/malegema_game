# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `scripts/tile_demo_drawer.gd`: 2.5D 牌效果的逐层自定义绘制演示器，展示 _draw() 分层绘制、多边形侧面、颜色光照模拟等核心技术。
- `scripts/tile_demo.gd`: 演示场景主控制器，提供步骤切换、参数滑块调节（抬起/发光/高光）、线框模式、自动播放、材质/强调色切换等交互功能。
- `scene/TileDemo.tscn`: 独立的 2.5D 效果演示场景，运行后可交互式学习牌的绘制过程。

### Documented
- `scripts/tile_rules.gd`: 为所有方法补充中文注释，说明坐标转换、重叠检测、自由度判断等规则逻辑。
- `scripts/setup_tiles.gd`: 为可解局面生成算法的每一步补充详细注释，包括 dummy 占位、去重检测、模拟消除、逆序回填等核心原理。
- `scripts/tile.gd`: 全面注释 2.5D 立体牌的绘制流程，涵盖分层结构、动态效果（抬起/发光/高光）、Tween 动画、颜色调色板等实现细节。
