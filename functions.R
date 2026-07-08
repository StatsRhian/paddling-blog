#' Native R slugify (with the help of {stringi})
#'
#'
#' @param x string to slugify
#' @export
slugify <- function(x) {
  x <- stringr::str_replace_all(x, "[^\\P{P}-]", "")
  x <- stringr::str_trim(x)
  x <- stringr::str_replace_all(x, "[[:space:]]+", "-")
  x <- stringr::str_to_lower(x)
  x
}


get_club <- function(x) {
  dplyr::case_when(
    any(grepl("^club:", x)) ~ x[grepl("^club:", x)][1],
    "peer" %in% x ~ "peer",
    "solo" %in% x ~ "solo",
    "course" %in% x ~ "course",
    "race" %in% x ~ "race",
    TRUE ~ NA_character_
  )
}

sanitise_name <- function(name) {
  name |>
    stringr::str_remove_all('[":]')
}

get_categories <- function(activity) {
  activity |>
    stringr::str_split(",") |>
    purrr::pluck(1) |>
    stringr::str_trim() |>
    stringr::str_squish() |>
    stringr::str_replace_all(" ", "-") |>
    stringr::str_to_lower() |>
    purrr::map_chr(
      ~ dplyr::case_when(
        .x %in% c("lcc") ~ "club: lakeland",
        .x %in% c("ldcc") ~ "club: lancaster",
        .x %in% c("ucc") ~ "club: ulverston",
        .x %in% c("tpc") ~ "club: tynemouth",
        .x %in% c("tcc") ~ "club: tynemouth",
        .x %in% c("cc") ~ "club: cumbria",
        TRUE ~ .x
      )
    )
}

get_image <- function(id) {
  folder <- file.path("data", "paddle_activities", id)
  images <- list.files(folder, pattern = "\\.(jpe?g|png)$", ignore.case = TRUE, full.names = FALSE)
  if (length(images) == 0) {
    return("https://placehold.co/600x400/EEE/31343C")
  }
  glue::glue("../data/paddle_activities/{id}/{images[1]}")
}

process_paddles <- function() {
  activities <- readr::read_csv("data/paddle_activities.csv")
  traces <- sf::read_sf("data/paddle_traces.geojson")
  combined <- dplyr::left_join(activities, traces, by = c("ID" = "activity_id"))

  processed_paddles <-
    combined |>
    dplyr::mutate(
      id = ID,
      name = sanitise_name(Title), 
      start_date = lubridate::ymd(Date),
      description = Description,
      moving_time_minutes = duration_s / 60,
      distance = distance_m / 1000,
      categories = purrr::map(.x = `Private Notes`, .f = get_categories),
      club = purrr::map(.x = categories, .f = get_club),
      image = purrr::map_chr(.x = id, .f = get_image),
      filename = glue::glue("posts/{id}.md")
    ) |>
    dplyr::select(
      id, name, start_date, distance,
      moving_time_minutes, description,
      categories, club, image, filename, geometry
    )

  saveRDS(processed_paddles, "data/processed_paddles.rds")
  cli::cli_alert_success("Processed paddles created")
}
