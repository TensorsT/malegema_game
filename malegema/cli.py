from __future__ import annotations

from .engine import MahjongGame


def print_help() -> None:
    print("命令:")
    print("  state                 查看当前局状态")
    print("  free [n]              列出前 n 张自由牌 (默认 30)")
    print("  hint                  显示一个可消除提示")
    print("  pick <id1> <id2>      消除两张牌")
    print("  restart [seed]        重新开局")
    print("  help                  显示帮助")
    print("  quit                  退出")


def run_cli(seed: str | None = None, deck_mode: str = "full") -> None:
    game = MahjongGame(seed=seed, deck_mode=deck_mode)
    print("Malegema Python 版已启动")
    print(f"seed={game.seed} deck={deck_mode}")
    print_help()

    while True:
        cmd = input("\n> ").strip()
        if not cmd:
            continue

        parts = cmd.split()
        op = parts[0].lower()

        if op in {"quit", "exit", "q"}:
            print("游戏结束")
            break

        if op == "help":
            print_help()
            continue

        if op == "state":
            print(game.board_summary())
            if game.game.end_condition:
                print(f"结束条件: {game.game.end_condition}")
            continue

        if op == "free":
            n = 30
            if len(parts) > 1 and parts[1].isdigit():
                n = int(parts[1])
            rows = game.free_tile_rows(limit=n)
            print("\n".join(rows) if rows else "没有自由牌")
            continue

        if op == "hint":
            hint = game.hint()
            print(f"提示: {hint[0]} {hint[1]}" if hint else "没有可用提示")
            continue

        if op == "pick":
            if len(parts) != 3:
                print("用法: pick <id1> <id2>")
                continue
            ok, msg = game.pick_pair(parts[1], parts[2])
            status = "OK" if ok else "ERR"
            print(f"[{status}] {msg}")
            print(game.board_summary())
            continue

        if op == "restart":
            new_seed = parts[1] if len(parts) > 1 else None
            game = MahjongGame(seed=new_seed, deck_mode=deck_mode)
            print(f"已重开: seed={game.seed}")
            continue

        print("未知命令，输入 help 查看可用命令")
