# ChessDDM

> *"As genetics needs its model organisms, its Drosophila and Neurospora, so psychology needs standard task environments around which knowledge and understanding can cumulate. Chess has proved to be an excellent model environment for this purpose."*
> — Herbert Simon (1973)

## Overview

This project uses large-scale chess game data from the [Lichess Open Database](https://database.lichess.org/) to study human decision-making through a cognitive science lens. Chess is an ideal model environment: it offers millions of naturalistic decisions with ground-truth quality evaluation (via Stockfish), precise reaction times (move clocks), and a wide range of skill levels — all in a single, well-defined task.

Sigman et al. (2010) showed, across 2.8 million rapid chess games, that response times follow heavy-tailed distributions, vary systematically with game phase, and that under time pressure a few seconds of clock advantage can outweigh a material advantage entirely — a 8-second disadvantage erases the benefit of an extra knight when fewer than 30 seconds remain. De Lafuente (2011) extended this by showing that expertise reshapes the *structure* of these distributions: stronger players allocate time more flexibly, investing in complex middlegame positions while speeding through openings and endgames, and exhibit wider RT distributions consistent with adaptive decision thresholds.

The present project builds on this foundation using the Lichess database, with the immediate goal of fitting **Drift-Diffusion Models (DDMs)** to individual move decisions — treating move time as response time and centipawn loss as an accuracy proxy — to decompose chess decisions into drift rate, boundary separation, and non-decision time. More broadly, the project asks what chess can tell us about the computational architecture of human decisions under time pressure, uncertainty, and varying cognitive load.

---

## What Is Implemented

### 1. Data Extraction (`Data_Extraction.ipynb`)
Streams and parses compressed PGN files directly from the Lichess database. For each move, the following are extracted:

| Feature | Description |
|---|---|
| `move_time` | Time spent on the move (seconds), corrected for time-control increment |
| `eval_cp` | Stockfish centipawn evaluation after the move (White's POV, capped ±1000; mate scores → ±1000) |
| `clock_left` | Remaining clock time of the player to move |
| `white_wins` | Game outcome (1 = White wins, 0 = Black wins, NA = draw) |
| `time_control` | Time-control string (e.g. `"180+2"`) |
| `white_elo` / `black_elo` | Player ratings |

The current pilot dataset contains ~60,000 moves from ~915 rated games (October 2024, Lichess standard rated).

### 2. Preprocessing (`00_Preprocess_Data.R`)
- **Increment correction**: Lichess `%clk` tags record clock time *after* the increment is credited, so raw `prev_clock − current_clock` underestimates thinking time by one increment. This is corrected.
- **Player-POV evaluation**: `eval_cp` is re-expressed from the moving player's perspective so that positive always means "better for me."
- **Centipawn loss & blunder detection**: CP loss per move computed; blunders flagged using Lichess's definition (≥ 200 cp loss, not trivially winning before and after).
- **Reaction time proxy**: `time_since_last_own_move` — total elapsed time since a player's previous move (their think time + opponent's think time).
- **Mate score imputation**: Positions with forced mate carry no numeric eval; filled forward within each game.

### 3. Time-Pressure Analysis (`02_Analysis.R`)
Replicates the core analysis of Sigman et al. (2010) asking: *at what point does clock advantage outweigh material advantage?*

A logistic regression is fit per time-pressure bin:

```
P(White wins) ~ eval_cp + clock_adv_white
```

The ratio of coefficients gives an exchange rate: **how many centipawns is one second of clock advantage worth?** This is computed for each remaining-time bin (`<10s`, `10–20s`, `20–30s`, `30–60s`, `>60s`) and split between games **with** and **without** time increment, reporting the centipawn value of an 8-second clock advantage — the specific comparison from Sigman et al. (8 s ≈ 1 knight in 3-minute games under severe time pressure).

---

## Planned Work

### Blunder Analysis
Blunders are already flagged in the preprocessing pipeline. The next step is a deeper characterisation: Are blunders more frequent under time pressure? Do higher-rated players blunder differently (e.g. faster but less severely)? Is blunder rate modulated by the difficulty of the position (e.g. sharp vs. quiet positions)?

### Drift-Diffusion Model Fitting
The central aim of the project. Each move is a decision with a measurable response time (`move_time`) and outcome quality (`cp_loss`). A DDM decomposes this into:
- **Drift rate** — how strongly the position "pulls" toward the correct move (linked to position clarity/eval)
- **Boundary separation** — how much evidence a player accumulates before committing (linked to time pressure and skill level)
- **Non-decision time** — perceptual and motor components independent of deliberation

De Lafuente (2011) showed that stronger players exhibit wider RT distributions and more adaptive time allocation — consistent with higher boundary separation in complex positions and lower separation in routine ones. DDMs will be fit to individual players and compared across skill levels, time controls, and game phases to test whether expertise is better characterised as a change in drift rate, boundary flexibility, or both.

### Chess as a Model Environment for Cognitive Science
Following Simon's framing, this project aims to use chess as a lens on broader questions in decision-making and cognitive science:
- How do humans trade off speed and accuracy under time pressure?
- How does expertise change the structure of decision-making (not just its quality)?
- Can DDM parameters derived from chess predict behaviour in other decision tasks?

---

## Repository Structure

```
ChessDDM/
├── Data_Extraction.ipynb      # Stream & parse Lichess PGN data → parquet
├── 00_Preprocess_Data.R       # Feature engineering & cleaning
├── 01_Verify_Games_LichessURL.R  # Helper: open a game by ID in browser
├── 02_Analysis.R              # Time-pressure logistic regression analysis
└── pilot_chess.parquet        # Pilot dataset (~60k moves, ~915 games)
```

---

## Dependencies

**Python** (data extraction): `python-chess`, `zstandard`, `pandas`, `pyarrow`

**R** (analysis): `arrow`, `tidyverse`, `dplyr`, `broom`

---

## Author: 
Niklas Jung

Claude Code was used with code preparation. 

## References

- Sigman M, Etchemendy P, Slezak DF and Cecchi GA (2010) Response Time Distributions in Rapid Chess: A Large-Scale Decision Making Experiment. *Front. Neurosci.* 4:60. doi: [10.3389/fnins.2010.00060](https://doi.org/10.3389/fnins.2010.00060)

- de Lafuente V (2011) Flexible Decisions and Chess Expertise. *Front. Neurosci.* 5:4. doi: [10.3389/fnins.2011.00004](https://doi.org/10.3389/fnins.2011.00004)

- Simon H & Chase W. (1973) Skill in Chess: Experiments with chess-playing tasks and computer simulation of skilled performance throw light on some human perceptual and memory processes. *American Scientist*
