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

# "2019-09-21T09:52:23Z"
sanitise_date <- function(start_date) {
  start_date |>
  lubridate::ymd_hms() |>
    format("%Y-%m-%d")
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

get_categories <- function(activity) {
  activity |>
    purrr::pluck("private_note") |>
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

# update a single activity
update_activity <- function(id_to_update) {
  detailed_paddles <- readRDS("data/detailed_paddles.rds")
  detailed_paddles$detailed[
    detailed_paddles$id == id_to_update
  ] <- list(rStrava::get_activity(id = id_to_update, strava_token))

  saveRDS(detailed_paddles, "data/detailed_paddles.rds")
}

strava_token <- httr::config(
  token = rStrava::strava_oauth(
    "rStrava",
    app_client_id = Sys.getenv("STRAVA_ID"),
    app_secret = Sys.getenv("STRAVA_SECRET"),
    app_scope = "activity:read_all",
    cache = TRUE
  )
)

get_raw <- function() {
  rStrava::get_activity_list(strava_token) |>
    rStrava::compile_activities() |>
    tibble::as_tibble() |>
    dplyr::filter(
      type %in% c("Kayaking", "Canoeing", "StandUpPaddling", "WaterSport")
    ) |>
    saveRDS("data/raw_paddles.rds")
  cli::cli_alert_success("Writing raw paddles to RDS")
}

get_detail <- function(all_paddles, n = 1) {
  all_paddles |>
    dplyr::arrange(desc(start_date)) |>
    dplyr::slice(1:n) |>
    dplyr::mutate(
      detailed = purrr::map(id, \(x) {
        rStrava::get_activity(id = as.character(x), strava_token)
        # rStrava needs id as character (which is silly)
      })
    )
}

sanitise_name <- function(name) {
  name |>
    stringr::str_remove_all('[":]')
}

get_latest <- function() {
  # Compare against RDS
  all_paddles <- readRDS("data/raw_paddles.rds") |>
    dplyr::filter(!is.na(map.summary_polyline) & map.summary_polyline != "") # Remove ones without a map

  detailed_paddles <- readRDS("data/detailed_paddles.rds")

  missing_paddles <- all_paddles$id[which(
    !(all_paddles$id %in% detailed_paddles$id)
  )]

  if (length(missing_paddles > 0)) {
    paddles_to_import <- missing_paddles[1] # Can be bumped if need

    new_detailed <-
      tibble::tibble(id = paddles_to_import) |>
      dplyr::mutate(
        detailed = purrr::map(id, \(x) {
          rStrava::get_activity(id = as.character(x), strava_token)
        }) # rStrava needs character
      )

    updated_detailed <- rbind(detailed_paddles, new_detailed)

    # Ensure unique
    updated_detailed <- dplyr::distinct(updated_detailed, id, .keep_all = TRUE)
    saveRDS(updated_detailed, "data/detailed_paddles.rds")

    cli::cli_alert_success(glue::glue(
      "Updated database. {nrow(updated_detailed)} paddles imported"
    ))
  } else {
    cli::cli_alert_info("No paddles to update")
  }
}

process_paddles <- function() {
  raw_paddles <- readRDS("data/raw_paddles.rds")
  detailed_paddles <- readRDS("data/detailed_paddles.rds")
  paddles <- dplyr::inner_join(raw_paddles, detailed_paddles, by = "id")

  processed_paddles <-
 paddles |>
  dplyr::mutate(
    # Basic
    name = sanitise_name(name),
    slug = slugify(name),
    start_date = sanitise_date(start_date),
    strava_url = glue::glue("https://www.strava.com/activities/{id}"),
    moving_time_minutes = moving_time / 60,

    # Detailed
    categories = purrr::map(detailed, get_categories),
    club = purrr::map_chr(categories, get_club),
    description = purrr::map_chr(detailed, \(x) {
      purrr::pluck(x, "description", .default = "TO DO")
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
    filename = glue::glue("posts/{start_date}_{slug}.md")
  ) |>
   dplyr::select(id, name, start_date, distance, categories,  moving_time_minutes, club, strava_url, kudos_count, description, image_url, filename)
 # Keep only new columns + kudos + distance. Don't need slug.

saveRDS(processed_paddles, "data/processed_paddles.rds")
}
