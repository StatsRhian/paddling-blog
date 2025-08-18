# Create tibble

source("R/functions.R")

get_raw()
get_paddles()
get_latest()

# update_activity(12021786501)

detailed_activities <-
  readRDS("data/paddles.rds") |>
  dplyr::mutate(
    name = sanitise_name(name),
    slug = slugify(name),
    start_date = purrr::map_chr(detailed, \(x) {
      purrr::pluck(x, "start_date") |>
        lubridate::ymd_hms() |>
        format("%Y-%m-%d")
    }),
    categories = purrr::map(detailed, get_categories),
    strava_url = glue::glue("https://www.strava.com/activities/{id}"),
    image_url = purrr::map_chr(detailed, \(x) {
      purrr::pluck(
        x,
        "photos",
        "primary",
        "urls",
        "600",
        .default = "https://placehold.co/600x400/EEE/31343C"
      )
    }),
    description = purrr::map_chr(detailed, \(x) {
      purrr::pluck(x, "description", .default = "TO DO")
    }),
    filename = glue::glue("posts/{start_date}_{slug}.qmd")
  )

# Generate all the post files from detailed activities
source("R/paddle_post.R")
purrr::walk(detailed_activities$id, \(x) paddle_post(x, detailed_activities))


# FIX MALFORMED DATES (still an issue)

fix <- readRDS("data/paddles.rds") |>
  dplyr::mutate(
    start_date = purrr::map_chr(detailed, \(x) {
      purrr::pluck(x, "start_date") |>
        lubridate::ymd_hms() |>
        format("%Y-%m-%d")
    })
  )

#saveRDS(fix, "data/paddles.rds")
