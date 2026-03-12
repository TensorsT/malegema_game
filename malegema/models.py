from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional

Color = Literal["g", "r", "b", "k"]
Material = Literal[
    "bone",
    "topaz",
    "sapphire",
    "garnet",
    "ruby",
    "jade",
    "emerald",
    "quartz",
    "obsidian",
]


@dataclass(frozen=True)
class Card:
    id: str
    suit: str
    rank: str
    colors: tuple[Color, ...]
    points: int


@dataclass
class Tile:
    id: str
    card_id: str
    material: Material
    x: int
    y: int
    z: int
    deleted: bool = False
    selected: bool = False
    points: Optional[int] = None
    coins: Optional[int] = None


@dataclass
class DragonRun:
    color: Color
    combo: int


@dataclass
class PhoenixRun:
    number: Optional[int]
    combo: int


@dataclass
class GameState:
    points: int = 0
    coins: int = 0
    time: int = 0
    pause: bool = False
    end_condition: Optional[str] = None
    temporary_material: Optional[Literal["topaz", "garnet", "jade", "quartz"]] = None
    dragon_run: Optional[DragonRun] = None
    phoenix_run: Optional[PhoenixRun] = None
