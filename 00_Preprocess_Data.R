### CHESS DDM
### Author: Niklas Jung
### 04/2026
### Intent: Access Lichess Open Database and model DDMs to decision making processes in Chess

library(arrow)
library(tidyverse)
library(dplyr)
library(tidyverse)
library(broom)

# Read directly from mounted Drive path
df <- read_parquet("pilot_chess.parquet")

# ── Correct move_time for increment ──────────────────────────────────────────
# Lichess %clk tags record the clock *after* the increment is applied, so the
# Python calculation (prev_clock - current_clock) equals (time_spent - increment).
# We add the increment back to recover the true thinking time.
# time_control is formatted as "base+increment" (e.g. "60+5", "600+0").
df <- df %>%
  mutate(
    increment = as.numeric(str_extract(time_control, "(?<=\\+)\\d+")),
    move_time = if_else(!is.na(move_time), move_time + increment, NA_real_)
  )

df <- df %>%
  group_by(game_id) %>% 
  mutate(eval_cp_change = abs(eval_cp - lag(eval_cp))) %>% 
  ungroup()

df <- df |>
  group_by(game_id) |>
  arrange(move_num, .by_group = TRUE) |>
  mutate(
    # Eval from the MOVING player's perspective
    # White wants eval_cp to be high (positive), black wants it to be low (negative)
    eval_from_player_pov = if_else(is_white, eval_cp, -eval_cp),
    eval_prev_pov        = lag(eval_from_player_pov),
    
    # Centipawn loss from moving player's perspective
    cp_loss = pmax(0, eval_prev_pov - eval_from_player_pov),
    
    # Lichess blunder definition:
    # 1. CP loss >= 200
    # 2. NOT (already winning before AND still winning after)
    #    "winning" = eval from your POV > 150cp
    blunder = case_when(
      cp_loss < 200                                          ~ FALSE,  # not a big enough loss
      eval_prev_pov > 150 & eval_from_player_pov > 150      ~ FALSE,  # winning before AND after
      is.na(cp_loss) | is.na(eval_prev_pov)                 ~ NA,     # first move, no info
      TRUE                                                   ~ TRUE    # genuine blunder
    )
  ) |>
  ungroup()

df <- df |>
  group_by(game_id) |>
  arrange(move_num, .by_group = TRUE) |>
  mutate(
    # Time since this player's last move = their move_time + opponent's move_time
    time_since_last_own_move = move_time + lag(move_time)
  ) |>
  ungroup()

blunders_df <- df %>%
  filter(eval_cp_change >= 200)

cat(sprintf("Found %d blunders.\n", nrow(blunders_df)))
head(blunders_df)

# ── Impute eval_cp for forced-mate positions ──────────────────────────────────
# Python stored mate scores as NA. Fill the last known eval forward (and the
# first known eval backward for early NAs) within each game — a forced-mate
# evaluation persists until the game ends, so this is semantically correct.
df <- df |>
  group_by(game_id) |>
  arrange(move_num, .by_group = TRUE) |>
  fill(eval_cp, .direction = "downup") |>
  ungroup()


