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
        .x %in% c("wpc") ~ "club: wansbeck",
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
      club = club %||% NA_character_,
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
      filename = glue::glue("posts/{id}.md"),
      moving_time_minutes = duration_s / 60,
      distance = distance_m / 1000
    ) |>
    dplyr::select(
      id, name, start_date, distance,
      moving_time_minutes, description,
      categories, club, venue, tags, image, filename, geometry
    )

  saveRDS(processed_paddles, "data/processed_paddles.rds")
  cli::cli_alert_success("Processed paddles created")
}
