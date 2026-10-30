sanitise_name <- function(name) {
  name |>
    stringr::str_remove_all('[":]')
}

prefix_club <- function(club){
  club |>
   purrr::map_chr(
      ~ dplyr::case_when(
        .x %in% c("lcc", "lakeland") ~ "club: lakeland",
        .x %in% c("ldcc", "lancaster") ~ "club: lancaster",
        .x %in% c("ucc", "ulverston") ~ "club: ulverston",
        .x %in% c("tpc", "tcc", "tynemouth") ~ "club: tynemouth",
        .x %in% c("cc", "cumbria") ~ "club: cumbria",
        .x %in% c("wpc", "wansbeck") ~ "club: wansbeck",
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


get_photos <- function(id) {
  folder <- file.path("data", "paddle_activities", id)
  photo_filepaths <- list.files(folder, pattern = "\\.(jpe?g|png)$", ignore.case = TRUE, full.names = TRUE)
  return(glue::glue("../{photo_filepaths}"))
}


read_activity_meta <- function() {
  paths <- list.files("data/paddle_activities",
                      pattern = "meta\\.yaml$",
                      recursive = TRUE,
                      full.names = TRUE)

  purrr::map_dfr(paths, ~ {
    yaml_data <- yaml::read_yaml(.x)

    # Normalize tags to character vector
    tags_value <- if (is.null(yaml_data$tags)) {
      character(0)
    } else {
      unlist(yaml_data$tags, use.names = FALSE)
    }

    tibble::tibble(
      id = yaml_data$id,
      date = yaml_data$date,
      title = yaml_data$title,
      club = yaml_data$club %||% NA_character_,
      venue = yaml_data$venue %||% NA_character_,
      description = yaml_data$description %||% "",
      tags = list(tags_value)
    )
  })
}

process_paddles <- function() {
  activities <- read_activity_meta()
  traces <- sf::read_sf("data/paddle_traces.geojson")
  combined <- dplyr::left_join(activities, traces, by = c("id" = "activity_id"))

  processed_paddles <-
    combined |>
    dplyr::mutate(
      name = sanitise_name(title),
      start_date = lubridate::ymd(date),
      club = prefix_club(club) %||% NA_character_,
      venue = venue %||% NA_character_,
      tags = purrr::map(.x = tags, .f = ~ .x %||% list()),
      # Combine club, venue, and tags into categories for site filtering
      categories = purrr::pmap(
        list(club = club, venue = venue, tags = tags),
        function(club, venue, tags) {
          result <- character()
          if (!is.na(club) && club != "") result <- c(result, club)
          if (!is.na(venue) && venue != "") result <- c(result, venue)
          if (length(tags) > 0) result <- c(result, as.character(unlist(tags)))
          result
        }
      ),
      image = purrr::map_chr(.x = id, .f = get_image),
      photos = purrr::map(.x = id, .f = get_photos),
      filename = glue::glue("posts/{id}.md"),
      moving_time_minutes = duration_s / 60,
      distance = distance_m / 1000
    ) |>
    dplyr::select(
      id, name, start_date, distance,
      moving_time_minutes, description,
      categories, club, venue, tags, image, photos, filename, geometry
    )

  saveRDS(processed_paddles, "data/processed_paddles.rds")
  cli::cli_alert_success("Processed paddles created")
}
