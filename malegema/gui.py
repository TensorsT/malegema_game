from __future__ import annotations

from pathlib import Path
import tkinter as tk
from tkinter import ttk

from .engine import MahjongGame
from .models import Tile

try:
    from PIL import Image, ImageTk
except ImportError:  # pragma: no cover
    Image = None
    ImageTk = None


class MahjongApp(tk.Tk):
    def __init__(self, seed: str | None = None, deck_mode: str = "full") -> None:
        super().__init__()
        self.title("Malegema - Python GUI")
        self.geometry("1280x860")
        self.minsize(980, 720)

        self.seed = seed
        self.deck_mode = deck_mode
        self.game = MahjongGame(seed=seed, deck_mode=deck_mode)
        self.seed = self.game.seed

        self.tile_w = 56
        self.tile_h = 72
        self.step_x = 28
        self.step_y = 24
        self.z_offset = 8
        self.base_x = 110
        self.base_y = 80

        self.selected_ids: list[str] = []
        self.tile_item_to_id: dict[int, str] = {}
        self._drawn_images: list[object] = []
        self._image_cache: dict[tuple[str, int, int], object] = {}
        self._bg_cache: dict[tuple[str, int, int], object] = {}

        self.assets_dir = Path(__file__).resolve().parent / "assets"
        self.background_dir = self.assets_dir / "backgrounds"
        self.tiles_dir = self.assets_dir / "tiles"
        self.texture_dir = self.assets_dir / "textures"
        self.background_files = sorted(self.background_dir.glob("*.webp"))
        self.texture_files = sorted(self.texture_dir.glob("*.webp"))
        self._bg_index = 0

        self._build_ui()
        self._redraw_board()
        self._update_status()

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=10)
        root.pack(fill=tk.BOTH, expand=True)

        left = ttk.Frame(root)
        left.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        right = ttk.Frame(root, width=280)
        right.pack(side=tk.RIGHT, fill=tk.Y)

        self.canvas = tk.Canvas(left, bg="#ffffff", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)
        self.canvas.bind("<Button-1>", self._on_canvas_click)

        title = ttk.Label(right, text="Malegema", font=("Segoe UI", 18, "bold"))
        title.pack(anchor="w", pady=(0, 10))

        self.seed_var = tk.StringVar(value=self.seed)
        self.deck_var = tk.StringVar(value=self.deck_mode)
        self.message_var = tk.StringVar(value="Ready")
        self.stats_var = tk.StringVar(value="")

        ttk.Label(right, text="Seed").pack(anchor="w")
        self.seed_entry = ttk.Entry(right, textvariable=self.seed_var)
        self.seed_entry.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(right, text="Deck").pack(anchor="w")
        deck_combo = ttk.Combobox(
            right,
            textvariable=self.deck_var,
            values=["full", "classic"],
            state="readonly",
        )
        deck_combo.pack(fill=tk.X, pady=(0, 12))

        ttk.Button(right, text="Restart", command=self._restart).pack(fill=tk.X, pady=4)
        ttk.Button(right, text="Hint", command=self._hint).pack(fill=tk.X, pady=4)
        ttk.Button(right, text="Clear Selection", command=self._clear_selection).pack(fill=tk.X, pady=4)

        ttk.Separator(right).pack(fill=tk.X, pady=12)

        ttk.Label(right, text="Stats", font=("Segoe UI", 11, "bold")).pack(anchor="w")
        ttk.Label(right, textvariable=self.stats_var, justify=tk.LEFT).pack(anchor="w", pady=(6, 0))

        ttk.Separator(right).pack(fill=tk.X, pady=12)

        ttk.Label(right, text="Message", font=("Segoe UI", 11, "bold")).pack(anchor="w")
        ttk.Label(
            right,
            textvariable=self.message_var,
            justify=tk.LEFT,
            wraplength=250,
            foreground="#4a4a4a",
        ).pack(anchor="w", pady=(6, 0))

        ttk.Label(
            right,
            text="Click free tiles to match them.\nA selected tile is outlined in yellow.",
            foreground="#555",
            wraplength=250,
            justify=tk.LEFT,
        ).pack(anchor="w", pady=(20, 0))

    def _load_photo(self, path: Path, width: int, height: int) -> object | None:
        if Image is None or ImageTk is None:
            return None
        key = (str(path), width, height)
        cached = self._image_cache.get(key)
        if cached is not None:
            return cached
        try:
            img = Image.open(path).convert("RGBA")
            img = img.resize((width, height), Image.Resampling.LANCZOS)
            photo = ImageTk.PhotoImage(img)
            self._image_cache[key] = photo
            return photo
        except Exception:
            return None

    def _load_background(self, width: int, height: int) -> object | None:
        if Image is None or ImageTk is None:
            return None
        if not self.background_files:
            return None
        bg_path = self.background_files[self._bg_index % len(self.background_files)]
        key = (str(bg_path), width, height)
        cached = self._bg_cache.get(key)
        if cached is not None:
            return cached
        try:
            img = Image.open(bg_path).convert("RGBA")
            img = img.resize((width, height), Image.Resampling.LANCZOS)
            photo = ImageTk.PhotoImage(img)
            self._bg_cache[key] = photo
            return photo
        except Exception:
            return None

    def _tile_asset_candidates(self, card_id: str) -> list[Path]:
        candidates = [self.tiles_dir / f"{card_id}.webp"]
        if card_id.startswith("element"):
            candidates.extend(
                [
                    self.tiles_dir / f"{card_id}1.webp",
                    self.tiles_dir / f"{card_id}2.webp",
                ]
            )
        if card_id.startswith("taijitu"):
            candidates.extend(
                [
                    self.tiles_dir / f"{card_id}1.webp",
                    self.tiles_dir / f"{card_id}2.webp",
                ]
            )
        if card_id == "dragonr":
            candidates.append(self.tiles_dir / "dargonr.webp")
        return candidates

    def _tile_photo(self, card_id: str) -> object | None:
        for path in self._tile_asset_candidates(card_id):
            if path.exists():
                return self._load_photo(path, self.tile_w - 8, self.tile_h - 16)
        return None

    def _restart(self) -> None:
        seed_text = self.seed_var.get().strip()
        seed = seed_text or None
        deck_mode = self.deck_var.get().strip() or "full"
        self.seed = seed_text
        self.deck_mode = deck_mode
        self.game = MahjongGame(seed=seed, deck_mode=deck_mode)
        self.seed = self.game.seed
        self.seed_var.set(self.seed)
        self.selected_ids.clear()
        self.message_var.set(f"Restarted game with seed={self.seed}, deck={deck_mode}")
        self._redraw_board()
        self._update_status()

    def _hint(self) -> None:
        pair = self.game.hint()
        if pair is None:
            self.message_var.set("No available pairs")
            return
        a, b = pair
        self.selected_ids = [a, b]
        self.message_var.set(f"Hint: {a} and {b}")
        self._redraw_board()

    def _clear_selection(self) -> None:
        self.selected_ids.clear()
        self.message_var.set("Selection cleared")
        self._redraw_board()

    def _on_canvas_click(self, event: tk.Event[tk.Misc]) -> None:
        tile_id = self._pick_tile_id_at(event.x, event.y)
        if tile_id is None:
            self.message_var.set("No tile at clicked position")
            return

        tile = self.game.tiles.get(tile_id)
        if tile is None or tile.deleted:
            self.message_var.set("Invalid tile")
            return

        if not self.game.is_free(tile):
            self.message_var.set(f"Tile {tile_id} is not free")
            return

        if tile_id in self.selected_ids:
            self.selected_ids = [sid for sid in self.selected_ids if sid != tile_id]
            self.message_var.set(f"Unselected tile {tile_id}")
            self._redraw_board()
            return

        if len(self.selected_ids) == 0:
            self.selected_ids = [tile_id]
            self.message_var.set(f"Selected tile {tile_id}")
            self._redraw_board()
            return

        first = self.selected_ids[0]
        ok, msg = self.game.pick_pair(first, tile_id)
        self.selected_ids.clear()
        self.message_var.set(msg)
        self._redraw_board()
        self._update_status()

        if ok and self.game.game.end_condition:
            self.message_var.set(f"{msg}. Game ended: {self.game.game.end_condition}")

    def _pick_tile_id_at(self, x: int, y: int) -> str | None:
        current = self.canvas.find_overlapping(x, y, x, y)
        for item in reversed(current):
            tile_id = self.tile_item_to_id.get(item)
            if tile_id is not None:
                return tile_id
        return None

    def _tile_screen_rect(self, tile: Tile) -> tuple[int, int, int, int]:
        sx = self.base_x + tile.x * self.step_x + tile.z * self.z_offset
        sy = self.base_y + tile.y * self.step_y - tile.z * self.z_offset
        return (sx, sy, sx + self.tile_w, sy + self.tile_h)

    def _tile_colors(self, tile: Tile, is_selected: bool, is_free: bool) -> tuple[str, str]:
        suit = tile.card_id.rstrip("0123456789")
        palette = {
            "bam": ("#7fcf89", "#1f4d2b"),
            "crack": ("#eea1a1", "#6a2727"),
            "dot": ("#9bbaf2", "#234164"),
            "wind": ("#d8cef6", "#4a4b77"),
            "dragon": ("#f2c691", "#7a4d1f"),
            "flower": ("#f3b4db", "#732d58"),
            "joker": ("#e8d989", "#655a22"),
            "rabbit": ("#f2ccb1", "#6f4626"),
            "frog": ("#a6e8dc", "#1f5a4d"),
            "lotus": ("#dcb7f7", "#5c2f76"),
            "sparrow": ("#f5e6ac", "#6f5c23"),
            "phoenix": ("#f3b083", "#703915"),
            "taijitu": ("#ececec", "#323232"),
            "mutation": ("#bdf0ac", "#2d6430"),
            "element": ("#a5dcf5", "#20526b"),
            "gem": ("#a5e3bf", "#1d5f38"),
            "shadow": ("#c1c1c1", "#3a3a3a"),
        }
        fill, text = palette.get(suit, ("#d8d8d8", "#2f2f2f"))
        if not is_free:
            fill = "#c4cbd4"
        if is_selected:
            fill = "#f8d86e"
            text = "#4f3a00"
        return fill, text

    def _redraw_board(self) -> None:
        self.canvas.delete("all")
        self.tile_item_to_id.clear()
        self._drawn_images.clear()

        canvas_w = max(self.canvas.winfo_width(), 640)
        canvas_h = max(self.canvas.winfo_height(), 480)
        self.canvas.create_rectangle(0, 0, canvas_w, canvas_h, fill="#ffffff", outline="")

        alive = sorted(self.game.alive_tiles(), key=lambda t: (t.z, t.y, t.x))
        for tile in alive:
            is_selected = tile.id in self.selected_ids
            is_free = self.game.is_free(tile)
            fill, text_color = self._tile_colors(tile, is_selected, is_free)
            x1, y1, x2, y2 = self._tile_screen_rect(tile)

            shadow = self.canvas.create_rectangle(
                x1 + 4,
                y1 + 5,
                x2 + 4,
                y2 + 5,
                fill="#c8ced6",
                outline="",
                stipple="gray50",
            )
            self.tile_item_to_id[shadow] = tile.id

            card = self.canvas.create_rectangle(
                x1,
                y1,
                x2,
                y2,
                fill="#ffffff",
                outline="#cfd6df",
                width=1,
            )
            self.tile_item_to_id[card] = tile.id

            glow = self.canvas.create_rectangle(
                x1 + 1,
                y1 + 1,
                x2 - 1,
                y1 + 12,
                fill="#f6f9fc",
                outline="",
            )
            self.tile_item_to_id[glow] = tile.id

            tile_photo = self._tile_photo(tile.card_id)
            if tile_photo is not None:
                img_id = self.canvas.create_image((x1 + x2) // 2, y1 + 30, image=tile_photo, anchor=tk.CENTER)
                self._drawn_images.append(tile_photo)
                self.tile_item_to_id[img_id] = tile.id
                frame = self.canvas.create_rectangle(
                    x1,
                    y1,
                    x2,
                    y2,
                    outline="#f0b400" if is_selected else "#aeb8c4",
                    width=3 if is_selected else 1,
                )
                self.tile_item_to_id[frame] = tile.id
                badge = self.canvas.create_text(
                    x1 + 4,
                    y1 + 10,
                    text=tile.id,
                    anchor=tk.W,
                    fill="#4c5664",
                    font=("Segoe UI", 7, "bold"),
                )
                self.tile_item_to_id[badge] = tile.id
            else:
                stripe = self.canvas.create_rectangle(
                    x1 + 3,
                    y1 + 3,
                    x2 - 3,
                    y1 + 14,
                    fill=fill,
                    outline="",
                )
                self.tile_item_to_id[stripe] = tile.id
                rect = self.canvas.create_rectangle(
                    x1 + 3,
                    y1 + 16,
                    x2 - 3,
                    y2 - 3,
                    fill="#ffffff",
                    outline="#d6dde5",
                    width=2 if is_selected else 1,
                )
                self.tile_item_to_id[rect] = tile.id

                label = f"{tile.card_id}\n{tile.id}"
                txt = self.canvas.create_text(
                    (x1 + x2) // 2,
                    (y1 + y2) // 2 + 4,
                    text=label,
                    fill=text_color,
                    font=("Segoe UI", 8, "bold"),
                    justify=tk.CENTER,
                )
                self.tile_item_to_id[txt] = tile.id

            if is_free:
                marker = self.canvas.create_oval(
                    x2 - 12,
                    y1 + 4,
                    x2 - 4,
                    y1 + 12,
                    fill="#22c55e",
                    outline="",
                )
                self.tile_item_to_id[marker] = tile.id

    def _update_status(self) -> None:
        summary = self.game.board_summary()
        lines = [
            f"Alive: {summary['alive']}",
            f"Free: {summary['free']}",
            f"Pairs: {summary['pairs']}",
            f"Points: {summary['points']}",
            f"Coins: {summary['coins']}",
            f"End: {summary['end_condition']}",
        ]
        self.stats_var.set("\n".join(lines))


def run_gui(seed: str | None = None, deck_mode: str = "full") -> None:
    app = MahjongApp(seed=seed, deck_mode=deck_mode)
    app.mainloop()
