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

get_categories <- function(activity) {
  activity |>
    purrr::pluck("private_note") |>
    stringr::str_split(",") |>
    purrr::pluck(1) |>
    stringr::str_trim() |>
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

# Doesn't work currently
# get_map <- function(id) {
#   activity <- rStrava::get_activity(id = id, strava_token)
#
#   activity |>
#     purrr::pluck("map", "summary_polyline") |>
#     gpoly_to_sfpoly() |>
#     sf::st_as_sf() |>
#     sf::st_set_crs(4326) |>
#     leaflet::leaflet() |>
#     leaflet::addTiles() |>
#     leaflet::addPolylines(
#       color = "purple",
#       opacity = 1,
#       dashArray = 5,
#       weight = 2
#     )
# }


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

# get_paddles <- function() {
#   readRDS("data/raw_activities.rds") |>
#     dplyr::filter(!is.na(map.summary_polyline) & map.summary_polyline != "") |>
#     dplyr::mutate(geom = gpoly_to_sfpoly(map.summary_polyline)) |>
#     dplyr::mutate(id = as.numeric(id)) |>
#     dplyr::select(id, name, start_date, distance, geom) |>
#     sf::st_as_sf() |>
#     sf::st_set_crs(4326) |>
#     sf::st_write("data/paddles.geojson", driver = "GeoJSON", delete_dsn = TRUE)
# }

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


# Fix MALFORMED DATES (still an issue)
# Can I fix this when they come in at RAW?
# Is the issue coming in during RAW or DETAILED?

fix_dates <- function(detailed_paddles) {
  detailed_paddles |>
    dplyr::mutate(
      start_date = purrr::map_chr(detailed, \(x) {
        purrr::pluck(x, "start_date") |>
          lubridate::ymd_hms() |>
          format("%Y-%m-%d")
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
    dplyr::filter(!is.na(map.summary_polyline) & map.summary_polyline != "") |> # Remove ones without a map
    dplyr::select(id, name, start_date, distance) # For legacy reasons
  detailed_paddles <- readRDS("data/detailed_paddles.rds")

  missing_activities <- all_paddles$id[which(
    !(all_paddles$id %in% detailed_paddles$id)
  )]

  if (length(missing_activities > 0)) {
    activities_to_import <- missing_activities[1]

    new_detailed <-
      all_paddles |>
      dplyr::filter(id %in% activities_to_import) |>
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
