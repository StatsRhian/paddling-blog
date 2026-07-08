# Create tibble
source("functions.R")
process_paddles()

# Generate all the post files from detailed activities
source("paddle_post.R")
processed_paddles <- readRDS("data/processed_paddles.rds")
purrr::walk(processed_paddles$id, \(x) paddle_post(x, processed_paddles))


