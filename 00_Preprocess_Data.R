### CHESS DDM
### Author: Niklas Jung
### 04/2026
### Intent: Access Lichess Open Database and model DDMs to decision making processes in Chess

library(arrow)
library(tidyverse)
library(dplyr)

# Read directly from mounted Drive path
df <- read_parquet("pilot_chess.parquet")



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
