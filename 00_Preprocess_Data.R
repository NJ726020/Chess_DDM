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
  mutate(eval_cp_change = abs(eval_cp - lag(eval_cp))) |>
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
