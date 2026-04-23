# malegema_game

`malegema_game` 是一个以麻将消除为核心、融合轻度 Roguelike 成长的项目仓库。

项目的设计思路来自 `malegema.md`，版本演进记录在 `CHANGELOG.md`，而 `first-demo(0.1.0)` 则保留了早期可运行原型和实现参考。

## 项目定位

这个项目不是单纯复刻传统麻将连连看，而是把“可消除的牌局”做成一个有成长、有特殊牌、有状态联动的策略消除系统。

当前仓库里并行保留了三条线：

- `malegema/`：Python 版核心逻辑重写，当前最完整、最适合直接运行和验证规则
- `first-demo/`：Godot 版本 demo，保留了图形化原型和场景实现
- `first-demo(0.1.0)/`：更早的历史版本快照，用来对照实现演进

## 核心玩法

- 基于 3D 坐标的牌面布局，支持遮挡判定与自由牌判定
- 牌局生成保证可解，使用反向抽取 + 回填的方式构造牌面
- 基础配对规则保持原作语义：
  - 同牌配对
  - 花牌互配
  - frog / lotus 同色配对
- 结算不只是“消除”，还会触发分数、金币和状态联动
- 特殊牌体系已经接入：
  - dragons
  - phoenix
  - gems
  - mutations
  - winds
  - jokers
  - taijitu
  - shadows

## 已实现内容

### Python 版 `malegema/`

- 3D 牌面地图与自由牌判定
- 可解牌局生成
- 匹配、消除、得分、金币、结束条件
- 特殊牌效果：
  - dragon 连击
  - phoenix 连击
  - gem 临时材质切换
  - mutation 牌组替换
  - wind 牌面位移
  - joker 重新洗牌
  - taijitu 额外倍率
  - shadow 影牌联动
- CLI 模式和 GUI 模式
- 支持 seed，便于复现牌局
- `classic` / `full` 两种牌组模式

### Godot 版 `first-demo/`

- 保留了可运行的图形化原型
- 已实现基础棋盘、可点选、消除反馈与部分特殊牌逻辑
- 适合作为场景、UI、交互和动画层的参考实现

## 快速开始

### 1. Python 版

安装依赖：

```bash
pip install -r malegema/requirements.txt
```

启动 GUI：

```bash
python -m malegema.main --mode gui
```

启动 CLI：

```bash
python -m malegema.main --mode cli
```

指定 seed 复现同一局：

```bash
python -m malegema.main --seed demo --mode gui
```

使用经典牌组：

```bash
python -m malegema.main --deck classic --mode gui
```

### 2. Godot demo

使用 Godot 4 打开 `first-demo/project.godot` 即可运行。

`first-demo(0.1.0)` 则是历史版本快照，适合对照老实现和文档。

## 仓库结构

- `malegema.md`：最初的设计说明，描述了项目目标、核心机制和阶段规划
- `CHANGELOG.md`：版本演进记录，能快速看到每个阶段做了什么
- `malegema/`：Python 重写版核心逻辑
- `first-demo/`：当前 Godot demo
- `first-demo(0.1.0)/`：旧版 demo 快照
- `whatajong-main/`：原始参考项目

## 版本脉络

- `0.1.0`：最小可玩原型，先把基础消除和棋盘跑通
- `0.1.1`：强化视觉表现、牌面层次和交互反馈
- `0.1.2`：把背景层与 UI 风格统一到可复用组件，并继续整理特殊牌相关逻辑
- 当前 Python 版：把核心规则、生成、结算与特殊牌效果集中到可复用的纯逻辑实现中

## 说明

- 如果你只想看“现在真正能跑的核心逻辑”，优先看 `malegema/`
- 如果你想看“场景、UI、动画和交互怎么落地”，优先看 `first-demo/`
- 如果你想追实现演进，按 `malegema.md` -> `first-demo(0.1.0)` -> `CHANGELOG.md` 的顺序看最顺
