### Analysis
### Niklas Jung
### 29/05/2026

## When does time advantage become more important than material advantage?
## Reports how many centipawns a +5 s clock advantage is worth in each
## remaining-time bin, split by games with vs. without increment.

# ── Step 1: build White-minus-Black clock advantage per ply ──────────────────
# Each half-move only has one player's clock; assign each to its own column,
# fill the gaps within the game, then subtract. Avoids pivot_wider which can
# silently produce list-columns on duplicate rows.
df <- df |>
  group_by(game_id) |>
  arrange(move_num, .by_group = TRUE) |>
  mutate(
    white_clock    = if_else( is_white, clock_left, NA_real_),
    black_clock    = if_else(!is_white, clock_left, NA_real_)
  ) |>
  fill(white_clock, black_clock, .direction = "downup") |>
  mutate(clock_adv_white = white_clock - black_clock) |>   # positive = White has more time
  ungroup()

# ── Step 2: build modelling data ─────────────────────────────────────────────
# Bin by remaining clock of the player to move; split by increment type.
df_model <- df |>
  filter(
    !is.na(eval_cp),
    !is.na(clock_left),
    !is.na(white_wins),
    !is.na(clock_adv_white)
  ) |>
  mutate(
    time_bin      = cut(clock_left,
                        breaks = c(0, 10, 20, 30, 60, Inf),
                        labels = c("<10s", "10-20s", "20-30s", "30-60s", ">60s"),
                        right  = FALSE),
    # coalesce guards against NA increment (unusual time-control formats)
    has_increment = if_else(coalesce(increment, 0L) > 0,
                            "With increment", "No increment")
  )

# ── Step 3: fit one logistic model per (time_bin × increment group) ──────────
# nest() keeps the group keys alongside each sub-dataset — no setNames needed.
exchange_rates <- df_model |>
  group_by(time_bin, has_increment) |>
  nest() |>
  mutate(
    n         = map_int(data, nrow),
    model     = map(data, ~ glm(white_wins ~ eval_cp + clock_adv_white,
                                data = .x, family = binomial)),
    coefs     = map(model, coef),
    # centipawns per second of clock advantage
    cp_per_s  = map_dbl(coefs, ~ .x["clock_adv_white"] / .x["eval_cp"]),
    # the quantity the paper reports: value of a fixed time window
    cp_per_8s = cp_per_s * 8
  ) |>
  select(time_bin, has_increment, n, cp_per_s, cp_per_8s) |>
  ungroup() |>
  mutate(time_bin = factor(time_bin, levels = levels(df_model$time_bin)))

print(exchange_rates)

# ── Step 4: plot ──────────────────────────────────────────────────────────────
ggplot(exchange_rates,
       aes(x = time_bin, y = cp_per_8s,
           colour = has_increment, group = has_increment)) +
  geom_line(linewidth = 0.9) +
  geom_point(aes(size = n)) +
  geom_hline(yintercept = 300, linetype = "dashed", colour = "grey40",
             linewidth = 0.7) +
  annotate("text", x = 4.8, y = 312, label = "≈ 1 knight (300 cp)",
           colour = "grey40", size = 3.2, hjust = 1) +
  scale_size_continuous(name = "Moves (n)", range = c(2, 6)) +
  scale_colour_manual(
    name   = "Time control",
    values = c("With increment" = "#2166ac", "No increment" = "#d6604d")
  ) +
  labs(
    title    = "Value of a 5-second clock advantage by time pressure",
    subtitle = "Centipawn equivalent of +5 s on the clock · split by time control type",
    x        = "Remaining clock of player to move",
    y        = "Centipawns equivalent to +5 s"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
