from __future__ import annotations

from dataclasses import asdict
from typing import Iterable

from .models import Card


def _cards(prefix: str, suit: str, ranks: Iterable[str], color: str, points: int) -> list[Card]:
    return [Card(id=f"{prefix}{r}", suit=suit, rank=r, colors=(color,), points=points) for r in ranks]


BAMS = _cards("bam", "bam", [str(i) for i in range(1, 10)], "g", 1)
CRACKS = _cards("crack", "crack", [str(i) for i in range(1, 10)], "r", 1)
DOTS = _cards("dot", "dot", [str(i) for i in range(1, 10)], "b", 1)
WINDS = [
    Card(id="windn", suit="wind", rank="n", colors=("k",), points=3),
    Card(id="windw", suit="wind", rank="w", colors=("k",), points=3),
    Card(id="winds", suit="wind", rank="s", colors=("k",), points=3),
    Card(id="winde", suit="wind", rank="e", colors=("k",), points=3),
]
DRAGONS = [
    Card(id="dragonr", suit="dragon", rank="r", colors=("r",), points=2),
    Card(id="dragong", suit="dragon", rank="g", colors=("g",), points=2),
    Card(id="dragonb", suit="dragon", rank="b", colors=("b",), points=2),
    Card(id="dragonk", suit="dragon", rank="k", colors=("k",), points=2),
]
RABBITS = [
    Card(id="rabbitr", suit="rabbit", rank="r", colors=("r",), points=2),
    Card(id="rabbitg", suit="rabbit", rank="g", colors=("g",), points=2),
    Card(id="rabbitb", suit="rabbit", rank="b", colors=("b",), points=2),
]
FROGS = [
    Card(id="frogr", suit="frog", rank="r", colors=("r",), points=2),
    Card(id="frogb", suit="frog", rank="b", colors=("b",), points=2),
    Card(id="frogg", suit="frog", rank="g", colors=("g",), points=2),
]
LOTUSES = [
    Card(id="lotusr", suit="lotus", rank="r", colors=("r",), points=2),
    Card(id="lotusb", suit="lotus", rank="b", colors=("b",), points=2),
    Card(id="lotusg", suit="lotus", rank="g", colors=("g",), points=2),
]
SHADOWS = [
    Card(id="shadowr", suit="shadow", rank="r", colors=("r", "k"), points=10),
    Card(id="shadowb", suit="shadow", rank="b", colors=("b", "k"), points=10),
    Card(id="shadowg", suit="shadow", rank="g", colors=("g", "k"), points=10),
]
SPARROWS = [
    Card(id="sparrowr", suit="sparrow", rank="r", colors=("r",), points=2),
    Card(id="sparrowb", suit="sparrow", rank="b", colors=("b",), points=2),
    Card(id="sparrowg", suit="sparrow", rank="g", colors=("g",), points=2),
]
PHOENIXES = [Card(id="phoenix", suit="phoenix", rank="", colors=("k",), points=2)]
TAIJITU = [
    Card(id="taijitur", suit="taijitu", rank="r", colors=("r",), points=8),
    Card(id="taijitug", suit="taijitu", rank="g", colors=("g",), points=8),
    Card(id="taijitub", suit="taijitu", rank="b", colors=("b",), points=8),
]
MUTATIONS = [
    Card(id="mutation1", suit="mutation", rank="", colors=("r", "g"), points=4),
    Card(id="mutation2", suit="mutation", rank="", colors=("b", "r"), points=4),
    Card(id="mutation3", suit="mutation", rank="", colors=("g", "b"), points=4),
]
FLOWERS = [
    Card(id="flower1", suit="flower", rank="", colors=("r", "g", "b"), points=4),
    Card(id="flower2", suit="flower", rank="", colors=("r", "g", "b"), points=4),
    Card(id="flower3", suit="flower", rank="", colors=("r", "g", "b"), points=4),
]
ELEMENTS = [
    Card(id="elementr", suit="element", rank="r", colors=("r",), points=5),
    Card(id="elementg", suit="element", rank="g", colors=("g",), points=5),
    Card(id="elementb", suit="element", rank="b", colors=("b",), points=5),
    Card(id="elementk", suit="element", rank="k", colors=("k",), points=5),
]
GEMS = [
    Card(id="gemr", suit="gem", rank="r", colors=("r",), points=6),
    Card(id="gemg", suit="gem", rank="g", colors=("g",), points=6),
    Card(id="gemb", suit="gem", rank="b", colors=("b",), points=6),
    Card(id="gemk", suit="gem", rank="k", colors=("k",), points=6),
]
JOKERS = [Card(id="joker", suit="joker", rank="", colors=("g", "r", "b", "k"), points=8)]

ALL_CARDS = [
    *BAMS,
    *CRACKS,
    *DOTS,
    *WINDS,
    *DRAGONS,
    *FLOWERS,
    *JOKERS,
    *FROGS,
    *LOTUSES,
    *SPARROWS,
    *RABBITS,
    *PHOENIXES,
    *ELEMENTS,
    *MUTATIONS,
    *TAIJITU,
    *GEMS,
    *SHADOWS,
]

CARDS_BY_ID = {card.id: card for card in ALL_CARDS}


def get_card(card_id: str) -> Card:
    return CARDS_BY_ID[card_id]


def is_suit(card_id: str, suit: str) -> Card | None:
    card = get_card(card_id)
    return card if card.suit == suit else None


def get_initial_pair_card_ids(mode: str = "full") -> list[str]:
    if mode == "classic":
        return [c.id for c in [*BAMS, *CRACKS, *DOTS]]
    if mode == "full":
        return [c.id for c in ALL_CARDS]
    raise ValueError(f"Unknown mode: {mode}")


def card_catalog() -> list[dict[str, object]]:
    return [asdict(card) for card in ALL_CARDS]
