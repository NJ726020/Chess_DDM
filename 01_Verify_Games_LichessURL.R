### Download and verify games
### Niklas Jung
### 04/2026


#this takes you to the lichess board for a individual game (with game_id as input)
check_game <- function(game_id) {
  id <- as.character(game_id)
  browseURL(paste0("https://lichess.org/", id))
  
}


