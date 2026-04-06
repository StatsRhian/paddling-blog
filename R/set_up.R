# Create tibble
source("R/functions.R")

get_raw()
get_latest()

# update_activity(12021786501)

processed_paddles <-
  readRDS("data/detailed_paddles.rds") |>
  #fix_dates() |>
  dplyr::mutate(
    name = sanitise_name(name),
    slug = slugify(name),
    start_date = purrr::map_chr(detailed, \(x) {
      purrr::pluck(x, "start_date") |>
        lubridate::ymd_hms() |>
        format("%Y-%m-%d")
    }),
    categories = purrr::map(detailed, get_categories),
    club = purrr::map_chr(categories, get_club),
    strava_url = glue::glue("https://www.strava.com/activities/{id}"),
    kudos = purrr::map_dbl(detailed, \(x) {
      purrr::pluck(x, "kudos_count", .default = 0)
    }), # This should come from raw instead (more up to date)
    moving_time_minutes = purrr::map_dbl(detailed, \(x) {
      purrr::pluck(x, "moving_time", .default = 0) / 60
    }),
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
    filename = glue::glue("posts/{start_date}_{slug}.md")
  )

saveRDS(processed_paddles, "data/processed_paddles.rds")

# Generate all the post files from detailed activities
source("R/paddle_post.R")
purrr::walk(processed_paddles$id, \(x) paddle_post(x, processed_paddles))


