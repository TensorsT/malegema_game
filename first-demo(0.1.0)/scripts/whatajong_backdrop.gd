extends Control
class_name WhatajongBackdrop

const TEXTURES: Array[Texture2D] = [
	preload("res://whatajong-main/src/renderer/assets/textures/1.webp"),
	preload("res://whatajong-main/src/renderer/assets/textures/2.webp"),
	preload("res://whatajong-main/src/renderer/assets/textures/3.webp"),
	preload("res://whatajong-main/src/renderer/assets/textures/4.webp"),
	preload("res://whatajong-main/src/renderer/assets/textures/5.webp"),
]

const MOUNTAINS: Array[Texture2D] = [
	preload("res://whatajong-main/src/renderer/assets/backgrounds/0.webp"),
	preload("res://whatajong-main/src/renderer/assets/backgrounds/1.webp"),
	preload("res://whatajong-main/src/renderer/assets/backgrounds/2.webp"),
	preload("res://whatajong-main/src/renderer/assets/backgrounds/3.webp"),
	preload("res://whatajong-main/src/renderer/assets/backgrounds/4.webp"),
	preload("res://whatajong-main/src/renderer/assets/backgrounds/5.webp"),
]

const PALETTES := [
	{
		"base": Color(0.18, 0.12, 0.10, 1.0),
		"texture": Color(0.66, 0.42, 0.34, 0.24),
		"atmosphere": Color(0.28, 0.18, 0.14, 0.28),
		"mountain": Color(0.25, 0.16, 0.12, 0.34),
		"wash": Color(0.05, 0.03, 0.02, 0.15),
	},
	{
		"base": Color(0.10, 0.14, 0.12, 1.0),
		"texture": Color(0.41, 0.57, 0.46, 0.22),
		"atmosphere": Color(0.10, 0.19, 0.17, 0.30),
		"mountain": Color(0.11, 0.16, 0.12, 0.34),
		"wash": Color(0.01, 0.02, 0.02, 0.14),
	},
	{
		"base": Color(0.08, 0.10, 0.15, 1.0),
		"texture": Color(0.39, 0.49, 0.66, 0.20),
		"atmosphere": Color(0.10, 0.15, 0.23, 0.30),
		"mountain": Color(0.10, 0.12, 0.18, 0.36),
		"wash": Color(0.01, 0.01, 0.03, 0.16),
	},
	{
		"base": Color(0.13, 0.12, 0.10, 1.0),
		"texture": Color(0.62, 0.58, 0.48, 0.18),
		"atmosphere": Color(0.20, 0.19, 0.16, 0.28),
		"mountain": Color(0.18, 0.17, 0.14, 0.30),
		"wash": Color(0.02, 0.02, 0.02, 0.14),
	},
]

@export var randomize_on_ready := true
@export_range(-1, 4, 1) var texture_variant := -1
@export_range(-1, 5, 1) var mountain_variant := -1
@export_enum("Auto", "Warm", "Jade", "Indigo", "Neutral") var tone_variant := 0

@onready var base_layer: ColorRect = $BaseLayer
@onready var texture_layer: TextureRect = $TextureLayer
@onready var atmosphere: ColorRect = $Atmosphere
@onready var mountains_layer: TextureRect = $MountainsLayer
@onready var foreground_wash: ColorRect = $ForegroundWash


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_layers()
	_apply_visuals()


func _configure_layers() -> void:
	texture_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_layer.stretch_mode = TextureRect.STRETCH_TILE
	texture_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mountains_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mountains_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mountains_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED


func _apply_visuals() -> void:
	var rng := RandomNumberGenerator.new()
	if randomize_on_ready:
		rng.randomize()
	else:
		rng.seed = int(hash(get_path()))

	var palette_index := tone_variant - 1 if tone_variant > 0 else rng.randi_range(0, PALETTES.size() - 1)
	var texture_index := texture_variant if texture_variant >= 0 else rng.randi_range(0, TEXTURES.size() - 1)
	var mountain_index := mountain_variant if mountain_variant >= 0 else rng.randi_range(0, MOUNTAINS.size() - 1)
	var palette: Dictionary = PALETTES[palette_index]

	base_layer.color = palette["base"]
	texture_layer.texture = TEXTURES[texture_index]
	texture_layer.modulate = palette["texture"]
	atmosphere.color = palette["atmosphere"]
	mountains_layer.texture = MOUNTAINS[mountain_index]
	mountains_layer.modulate = palette["mountain"]
	foreground_wash.color = palette["wash"]
