from __future__ import annotations

from collections import Counter
from dataclasses import replace
import random
import secrets
from typing import Iterable

from .board_map import get_map, map_get, map_height, map_width
from .cards import get_card, get_initial_pair_card_ids, is_suit
from .models import DragonRun, GameState, Material, PhoenixRun, Tile


MATERIAL_POINTS = {
    "topaz": 1,
    "quartz": 1,
    "garnet": 1,
    "jade": 2,
    "sapphire": 24,
    "obsidian": 24,
    "ruby": 24,
    "emerald": 48,
}

MUTATION_RANKS = {
    "mutation1": ("crack", "bam"),
    "mutation2": ("dot", "crack"),
    "mutation3": ("bam", "dot"),
}

MUTATION_MATERIALS = {
    "r": ["bone", "garnet", "ruby"],
    "g": ["bone", "jade", "emerald"],
    "b": ["bone", "topaz", "sapphire"],
}


class MahjongGame:
    def __init__(self, seed: str | None = None, deck_mode: str = "full") -> None:
        # Keep whatajong-like seed-driven generation while making every new game unique by default.
        self.seed = seed or f"run-{secrets.token_hex(8)}"
        self.rng = random.Random(self.seed)
        self.game = GameState()
        self.tiles: dict[str, Tile] = {}
        self._init_tiles(deck_mode)

    def _init_tiles(self, deck_mode: str) -> None:
        pair_card_ids = get_initial_pair_card_ids(deck_mode)
        self.tiles = self._setup_tiles(pair_card_ids)

    def _setup_tiles(self, pair_card_ids: list[str]) -> dict[str, Tile]:
        board = get_map(len(pair_card_ids) * 2)
        base_tiles = self._extract_positions(board)

        working = {tile.id: replace(tile) for tile in base_tiles.values()}
        pick_order: list[Tile] = []

        while True:
            free_tiles = self._free_tiles_from(working)
            if len(free_tiles) <= 1:
                break

            while len(free_tiles) > 1:
                tile1 = free_tiles.pop(self.rng.randrange(len(free_tiles)))
                tile2 = free_tiles.pop(self.rng.randrange(len(free_tiles)))
                working.pop(tile1.id, None)
                working.pop(tile2.id, None)
                pick_order.extend([tile1, tile2])

        if working:
            return self._setup_tiles(pair_card_ids)

        pairs = [(card_id, card_id) for card_id in pair_card_ids]
        self.rng.shuffle(pairs)

        result: dict[str, Tile] = {}
        for i in range(0, len(pick_order), 2):
            tile1 = pick_order[len(pick_order) - 1 - i]
            tile2 = pick_order[len(pick_order) - 2 - i]
            card1, card2 = pairs[i // 2]

            id1 = map_get(board, tile1.x, tile1.y, tile1.z)
            id2 = map_get(board, tile2.x, tile2.y, tile2.z)
            if id1 is None or id2 is None:
                continue

            result[id1] = Tile(id=id1, card_id=card1, material="bone", x=tile1.x, y=tile1.y, z=tile1.z)
            result[id2] = Tile(id=id2, card_id=card2, material="bone", x=tile2.x, y=tile2.y, z=tile2.z)

        return result

    def _extract_positions(self, board: list[list[list[int | None]]]) -> dict[str, Tile]:
        positions: dict[str, Tile] = {}
        for z, level in enumerate(board):
            for y, row in enumerate(level):
                for x, val in enumerate(row):
                    if val is None:
                        continue
                    prev = map_get(board, x - 1, y, z)
                    above = map_get(board, x, y - 1, z)
                    sid = str(val)
                    if sid == prev or sid == above:
                        continue
                    positions[sid] = Tile(id=sid, card_id="bam1", material="bone", x=x, y=y, z=z)
        return positions

    def alive_tiles(self) -> list[Tile]:
        return [tile for tile in self.tiles.values() if not tile.deleted]

    def _tile_at(self, x: int, y: int, z: int) -> Tile | None:
        for tile in self.alive_tiles():
            if tile.x == x and tile.y == y and tile.z == z:
                return tile
        return None

    def _find_near(self, tile: Tile, dx: int = 0, dy: int = 0, dz: int = 0) -> Tile | None:
        return self._tile_at(tile.x + dx, tile.y + dy, tile.z + dz)

    def overlaps(self, tile: Tile, z_shift: int) -> Tile | None:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                found = self._find_near(tile, dx, dy, z_shift)
                if found:
                    return found
        return None

    def fully_overlaps(self, tile: Tile, z_shift: int) -> bool:
        checks = {
            "left": self._find_near(tile, -1, 0, z_shift),
            "right": self._find_near(tile, 1, 0, z_shift),
            "top": self._find_near(tile, 0, -1, z_shift),
            "bottom": self._find_near(tile, 0, 1, z_shift),
            "tl": self._find_near(tile, -1, -1, z_shift),
            "tr": self._find_near(tile, 1, -1, z_shift),
            "bl": self._find_near(tile, -1, 1, z_shift),
            "br": self._find_near(tile, 1, 1, z_shift),
            "center": self._find_near(tile, 0, 0, z_shift),
        }
        return bool(
            checks["center"]
            or (checks["left"] and checks["right"])
            or (checks["top"] and checks["bottom"])
            or (checks["tl"] and checks["br"])
            or (checks["tr"] and checks["bl"])
            or (checks["tl"] and checks["tr"] and checks["bl"])
            or (checks["tl"] and checks["tr"] and checks["br"])
            or (checks["tl"] and checks["bl"] and checks["br"])
            or (checks["tr"] and checks["bl"] and checks["br"])
            or (checks["tl"] and checks["tr"] and checks["bl"] and checks["br"])
        )

    def is_covered(self, tile: Tile) -> bool:
        return self.overlaps(tile, 1) is not None

    def _material(self, tile: Tile) -> Material:
        temporary = self.game.temporary_material
        if temporary:
            mapping = {
                "topaz": ("b", "sapphire"),
                "garnet": ("r", "ruby"),
                "jade": ("g", "emerald"),
                "quartz": ("k", "obsidian"),
            }
            color, evolved = mapping[temporary]
            card = get_card(tile.card_id)
            candidate: Material = temporary
            if tile.material != "bone":
                candidate = evolved
            if color in card.colors:
                return self._shadow_material(tile.card_id, candidate)
        return self._shadow_material(tile.card_id, tile.material)

    def _shadow_material(self, card_id: str, material: Material) -> Material:
        suit_card = self._is_suit_card(card_id)
        if not suit_card:
            return material
        if material == "bone":
            return material
        active_shadows = self._active_shadows()
        if suit_card.suit in active_shadows:
            return "obsidian" if self._is_shiny(material) else "quartz"
        return material

    @staticmethod
    def _is_shiny(material: Material) -> bool:
        return material in {"obsidian", "sapphire", "emerald", "ruby"}

    def is_free(self, tile: Tile) -> bool:
        if tile.deleted:
            return False
        if self.is_covered(tile):
            return False

        material = self._material(tile)
        if material in {"topaz", "sapphire"}:
            return True

        left = any(self._find_near(tile, -2, y) for y in (-1, 0, 1))
        right = any(self._find_near(tile, 2, y) for y in (-1, 0, 1))
        return not left or not right

    def _free_tiles_from(self, tiles_by_id: dict[str, Tile]) -> list[Tile]:
        old = self.tiles
        self.tiles = tiles_by_id
        try:
            return [tile for tile in tiles_by_id.values() if self.is_free(tile)]
        finally:
            self.tiles = old

    def free_tiles(self) -> list[Tile]:
        return [tile for tile in self.alive_tiles() if self.is_free(tile)]

    def cards_match(self, card1: str, card2: str) -> bool:
        a = get_card(card1)
        b = get_card(card2)
        if a.suit == "flower" and b.suit == "flower":
            return True
        if a.suit == "frog" and b.suit == "lotus" and a.rank == b.rank:
            return True
        if b.suit == "frog" and a.suit == "lotus" and a.rank == b.rank:
            return True
        return card1 == card2

    def available_pairs(self) -> list[tuple[Tile, Tile]]:
        free = self.free_tiles()
        pairs: list[tuple[Tile, Tile]] = []
        for i in range(len(free)):
            for j in range(i + 1, len(free)):
                if self.cards_match(free[i].card_id, free[j].card_id):
                    pairs.append((free[i], free[j]))
        return pairs

    def game_over_condition(self) -> str | None:
        if not self.alive_tiles():
            return "empty-board"
        if not self.available_pairs():
            return "no-pairs"
        return None

    def _active_shadows(self) -> set[str]:
        cards = []
        for tile in self.alive_tiles():
            card = is_suit(tile.card_id, "shadow")
            if card and self.is_free(tile):
                cards.append(card)
        result: set[str] = set()
        for suit, color in (("bam", "g"), ("crack", "r"), ("dot", "b")):
            if any(c.rank == color for c in cards):
                result.add(suit)
        return result

    def _is_suit_card(self, card_id: str):
        for suit in ("bam", "crack", "dot"):
            card = is_suit(card_id, suit)
            if card:
                return card
        return None

    def _get_colors(self, card_id: str) -> tuple[str, ...]:
        card = get_card(card_id)
        colors = card.colors
        suit_card = self._is_suit_card(card_id)
        if suit_card and suit_card.suit in self._active_shadows():
            return ("k",)
        return colors

    def card_matches_color(self, color: str, card_id: str) -> bool:
        return color in self._get_colors(card_id)

    def _elements_bonus(self, card_id: str) -> tuple[int, int]:
        colors = self._get_colors(card_id)
        elements = [
            tile for tile in self.alive_tiles() if tile.card_id in {f"element{c}" for c in colors}
        ]
        visible = sum(1 for tile in elements if not self.is_covered(tile))
        free = sum(1 for tile in elements if self.is_free(tile))
        return visible, free

    def _points_for_tile(self, tile: Tile) -> int:
        card = get_card(tile.card_id)
        raw = card.points + MATERIAL_POINTS.get(self._material(tile), 0)
        dragon = self.game.dragon_run.combo if self.game.dragon_run else 0
        phoenix = (self.game.phoenix_run.combo * 2) if self.game.phoenix_run else 0
        visible_elements, free_elements = self._elements_bonus(tile.card_id)
        multiplier = max(1, dragon + phoenix + free_elements)
        return (raw + visible_elements) * multiplier

    def _coins_for_tile(self, tile: Tile) -> int:
        material = self._material(tile)
        material_coins = 1 if material == "garnet" else 3 if material == "ruby" else 0
        rabbit_coins = 1 if is_suit(tile.card_id, "rabbit") else 0
        return material_coins + rabbit_coins

    def _taijitu_multiplier(self, a: Tile, b: Tile) -> int:
        if a.z != b.z:
            return 1
        if not (is_suit(a.card_id, "taijitu") and is_suit(b.card_id, "taijitu")):
            return 1
        dx = abs(a.x - b.x)
        dy = abs(a.y - b.y)
        adjacent = (dx == 2 and dy < 1) or (dx < 1 and dy == 2)
        return 3 if adjacent else 1

    def _resolve_dragons(self, played_card_id: str) -> None:
        dragon_card = is_suit(played_card_id, "dragon")
        if self.game.dragon_run is None:
            if dragon_card:
                self.game.dragon_run = DragonRun(color=dragon_card.rank, combo=1)
            return

        run = self.game.dragon_run
        if not self.card_matches_color(run.color, played_card_id):
            self.game.dragon_run = DragonRun(color=dragon_card.rank, combo=1) if dragon_card else None
            return

        if run.combo == 10:
            self.game.dragon_run = None
        else:
            run.combo += 1

    def _resolve_phoenix_run(self, played_card_id: str) -> None:
        def parse_number(card_id: str) -> int | None:
            rank = get_card(card_id).rank
            return int(rank) if rank.isdigit() else None

        def next_number(number: int) -> int:
            return 1 if number == 9 else number + 1

        phoenix_card = is_suit(played_card_id, "phoenix")

        if self.game.phoenix_run is None:
            self.game.phoenix_run = PhoenixRun(number=None, combo=1) if (phoenix_card and not self.game.dragon_run) else None
            return

        run = self.game.phoenix_run
        rank = parse_number(played_card_id)
        if rank is None or (run.number is not None and rank != next_number(run.number)):
            self.game.phoenix_run = PhoenixRun(number=None, combo=1) if (phoenix_card and not self.game.dragon_run) else None
            return

        if run.combo == 10:
            self.game.phoenix_run = None
            return

        run.combo += 1
        run.number = rank

    def _resolve_gems(self, played_card_id: str) -> None:
        gem = is_suit(played_card_id, "gem")
        if not gem:
            self.game.temporary_material = None
            return
        self.game.temporary_material = {
            "r": "garnet",
            "g": "jade",
            "b": "topaz",
            "k": "quartz",
        }[gem.colors[0]]

    def _resolve_black_material_pause(self, tile: Tile) -> None:
        material = self._material(tile)
        self.game.pause = material in {"obsidian", "quartz"}

    def _resolve_mutations(self, played_card_id: str) -> None:
        mutation = is_suit(played_card_id, "mutation")
        if not mutation:
            return

        a_suit, b_suit = MUTATION_RANKS[mutation.id]

        def swap(tile: Tile, from_suit: str, to_suit: str) -> None:
            new_card_id = tile.card_id.replace(from_suit, to_suit)
            old_color = self._is_suit_card(tile.card_id).colors[0]
            new_color = self._is_suit_card(new_card_id).colors[0]
            scale_old = MUTATION_MATERIALS[old_color]
            scale_new = MUTATION_MATERIALS[new_color]
            idx = scale_old.index(tile.material) if tile.material in scale_old else 0
            tile.card_id = new_card_id
            tile.material = scale_new[idx]

        a_tiles = [t for t in self.alive_tiles() if get_card(t.card_id).suit == a_suit]
        b_tiles = [t for t in self.alive_tiles() if get_card(t.card_id).suit == b_suit]

        for tile in a_tiles:
            swap(tile, a_suit, b_suit)
        for tile in b_tiles:
            swap(tile, b_suit, a_suit)

    def _resolve_winds(self, played_card_id: str) -> None:
        wind = is_suit(played_card_id, "wind")
        if not wind:
            return

        axis, bias = {"n": ("y", -2), "s": ("y", 2), "e": ("x", 2), "w": ("x", -2)}[wind.rank]
        direction = 1 if bias > 0 else -1
        highest = max((tile.z for tile in self.alive_tiles()), default=0)

        for z in range(1, highest + 1):
            z_tiles = [t for t in self.alive_tiles() if t.z == z]
            z_tiles.sort(key=lambda t: getattr(t, axis), reverse=(direction > 0))
            for tile in z_tiles:
                moved = self._move_tile_if_possible(tile, axis, bias)
                if moved:
                    self.tiles[tile.id] = moved

    def _move_tile_if_possible(self, tile: Tile, axis: str, bias: int) -> Tile | None:
        value = getattr(tile, axis)
        max_size = map_width() if axis == "x" else map_height()
        direction = 1 if bias > 0 else -1

        if value == 0 and direction == -1:
            return None
        if value == max_size - 1 and direction == 1:
            return None

        for attempt in range(abs(bias), 0, -1):
            displacement = attempt * direction
            new_value = value + displacement
            if not (0 <= new_value < max_size):
                continue
            new_tile = replace(tile)
            setattr(new_tile, axis, new_value)
            if self.overlaps(new_tile, 0):
                continue
            if not self.fully_overlaps(new_tile, -1):
                continue
            return new_tile
        return None

    def _resolve_joker(self, played_card_id: str) -> None:
        if not is_suit(played_card_id, "joker"):
            return

        current_tiles = [replace(tile) for tile in self.alive_tiles()]
        if len(current_tiles) < 2:
            return

        dumb_tiles = {
            tile.id: Tile(id=tile.id, card_id="bam1", material="bone", x=tile.x, y=tile.y, z=tile.z)
            for tile in current_tiles
        }

        pick_order: list[Tile] = []
        while True:
            free = self._free_tiles_from(dumb_tiles)
            if len(free) <= 1:
                break
            while len(free) > 1:
                t1 = free.pop(self.rng.randrange(len(free)))
                t2 = free.pop(self.rng.randrange(len(free)))
                dumb_tiles.pop(t1.id, None)
                dumb_tiles.pop(t2.id, None)
                pick_order.extend([t1, t2])

        if dumb_tiles:
            return self._resolve_joker(played_card_id)

        pairs: list[tuple[Tile, Tile]] = []
        used: set[str] = set()
        for i, t1 in enumerate(current_tiles):
            if t1.id in used:
                continue
            for t2 in current_tiles[i + 1 :]:
                if t2.id in used:
                    continue
                if self.cards_match(t1.card_id, t2.card_id):
                    pairs.append((t1, t2))
                    used.add(t1.id)
                    used.add(t2.id)
                    break

        self.rng.shuffle(pairs)
        rewritten: dict[str, Tile] = {}
        for i in range(0, len(pick_order), 2):
            tile1 = pick_order[len(pick_order) - 1 - i]
            tile2 = pick_order[len(pick_order) - 2 - i]
            pair = pairs[i // 2]
            a, b = pair
            rewritten[tile1.id] = Tile(id=tile1.id, card_id=a.card_id, material=a.material, x=tile1.x, y=tile1.y, z=tile1.z)
            rewritten[tile2.id] = Tile(id=tile2.id, card_id=b.card_id, material=b.material, x=tile2.x, y=tile2.y, z=tile2.z)

        self.tiles = rewritten

    def _resolve_jumping_tiles(self, first: Tile, second: Tile) -> bool:
        frog = is_suit(first.card_id, "frog")
        if frog and self.card_matches_color(frog.rank, second.card_id):
            first.z = second.z + 1
            first.x = second.x
            first.y = second.y
            return True

        sparrow = is_suit(first.card_id, "sparrow")
        if (sparrow and self.card_matches_color(sparrow.rank, second.card_id)) or is_suit(second.card_id, "sparrow"):
            first.x, second.x = second.x, first.x
            first.y, second.y = second.y, first.y
            first.z, second.z = second.z, first.z
            return True

        lotus = is_suit(second.card_id, "lotus")
        if lotus and self.card_matches_color(lotus.rank, first.card_id):
            first.z = second.z + 1
            first.x = second.x
            first.y = second.y
            return True

        return False

    def pick_pair(self, tile_id1: str, tile_id2: str) -> tuple[bool, str]:
        if tile_id1 == tile_id2:
            return False, "请选择两个不同的牌ID"

        tile1 = self.tiles.get(tile_id1)
        tile2 = self.tiles.get(tile_id2)
        if tile1 is None or tile2 is None:
            return False, "牌ID不存在"
        if tile1.deleted or tile2.deleted:
            return False, "该牌已经被移除"
        if not self.is_free(tile1) or not self.is_free(tile2):
            return False, "必须选择两张自由牌"

        if self.cards_match(tile1.card_id, tile2.card_id):
            tile1.deleted = True
            tile2.deleted = True
            tile1.selected = False
            tile2.selected = False

            self._resolve_dragons(tile2.card_id)
            self._resolve_phoenix_run(tile2.card_id)
            self._resolve_mutations(tile2.card_id)
            self._resolve_black_material_pause(tile2)

            mult = self._taijitu_multiplier(tile1, tile2)
            for tile in (tile1, tile2):
                points = self._points_for_tile(tile) * mult
                coins = self._coins_for_tile(tile)
                tile.points = points
                tile.coins = coins
                self.game.points += points
                self.game.coins += coins

            self._resolve_gems(tile2.card_id)
            self._resolve_joker(tile2.card_id)
            self._resolve_winds(tile2.card_id)

            condition = self.game_over_condition()
            if condition:
                self.game.pause = True
                self.game.end_condition = condition
            return True, "消除成功"

        if self._resolve_jumping_tiles(tile1, tile2):
            return True, "未消除，但触发了跳跃效果"

        return False, "两张牌不匹配"

    def board_summary(self) -> dict[str, int | str | None]:
        return {
            "alive": len(self.alive_tiles()),
            "free": len(self.free_tiles()),
            "pairs": len(self.available_pairs()),
            "points": self.game.points,
            "coins": self.game.coins,
            "end_condition": self.game.end_condition,
        }

    def free_tile_rows(self, limit: int = 40) -> list[str]:
        rows = []
        for tile in self.free_tiles()[:limit]:
            rows.append(
                f"id={tile.id:>3} card={tile.card_id:<10} mat={tile.material:<8} pos=({tile.x:>2},{tile.y:>2},{tile.z})"
            )
        return rows

    def hint(self) -> tuple[str, str] | None:
        pairs = self.available_pairs()
        if not pairs:
            return None
        a, b = pairs[0]
        return a.id, b.id


def material_upgrade_preview(materials: Iterable[Material], path: str) -> list[Material]:
    order = {
        "r": ["bone", "garnet", "ruby"],
        "g": ["bone", "jade", "emerald"],
        "b": ["bone", "topaz", "sapphire"],
        "k": ["bone", "quartz", "obsidian"],
    }[path]
    count = Counter(materials)
    count["bone"] += 1

    for i, material in enumerate(order[:-1]):
        nxt = order[i + 1]
        while count[material] >= 3:
            count[material] -= 3
            count[nxt] += 1
            if count[material] == 0:
                del count[material]

    result: list[Material] = []
    for material, num in count.items():
        result.extend([material] * num)
    return result
