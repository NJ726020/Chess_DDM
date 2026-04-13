### Download and verify games
### Niklas Jung
### 04/2026


check_game <- function(game_id) {
  id <- as.character(game_id)
  browseURL(paste0("https://lichess.org/", id))
  
}


