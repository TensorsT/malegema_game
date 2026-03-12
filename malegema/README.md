# malegema (Python rewrite)

This folder contains a Python rewrite of the core game logic from `whatajong-main`.
It is implemented independently and does not use code from `python_version_origin`.

## Features

- 3D board layout based on original responsive map
- Solvable board generation using reverse-pick fill
- Free-tile detection and pair matching
- Scoring, coins, and end-condition checks
- Special tile effects: dragons, phoenix run, mutation, gems, winds, joker shuffle
- Reproducible seeds (or random new seed each run if omitted)
- Asset-driven GUI visuals using `malegema/assets` (backgrounds + tile faces)
- CLI interface for playing in terminal

## Install

```bash
pip install -r malegema/requirements.txt
```

## Run

From workspace root:

```bash
python -m malegema.main --deck full --mode gui
```

Use explicit seed when you want reproducibility:

```bash
python -m malegema.main --seed demo --deck full --mode gui
```

Optional deck mode:

```bash
python -m malegema.main --deck classic --mode gui
```

CLI mode:

```bash
python -m malegema.main --mode cli
```

## Test

```bash
python -m unittest discover -s malegema/tests -v
```

## CLI commands

- `state`
- `free [n]`
- `hint`
- `pick <id1> <id2>`
- `restart [seed]`
- `help`
- `quit`
