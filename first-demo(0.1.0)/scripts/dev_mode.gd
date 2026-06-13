## 开发者模式全局开关（Autoload 单例）。
## 由主菜单「设置 → 开发者模式」CheckBox 切换；
## board.gd 每帧检查此标志决定是否显示跳过按钮。
extends Node

var enabled: bool = false
