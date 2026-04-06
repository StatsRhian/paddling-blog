# Create tibble
source("R/functions.R")

get_raw()
get_latest()

# update_activity(12021786501)

process_paddles()
# Generate all the post files from detailed activities
source("R/paddle_post.R")
processed_paddles <- readRDS("data/processed_paddles.rds")
purrr::walk(processed_paddles$id, \(x) paddle_post(x, processed_paddles))


