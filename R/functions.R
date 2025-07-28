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



get_categories <- function(activity) {
  activity |>
    purrr::pluck("private_note") |>
    stringr::str_split(",") |>
    purrr::pluck(1) |>
    stringr::str_trim()
}

# Doesn't work currently
get_map <- function(id) {
  activity <- rStrava::get_activity(id = id, strava_token)

  activity |>
    purrr::pluck("map", "summary_polyline") |>
    gpoly_to_sfpoly() |>
    sf::st_as_sf() |>
    sf::st_set_crs(4326) |>
    leaflet::leaflet() |>
    leaflet::addProviderTiles(provider = "Stadia.StamenWatercolor") |>
    leaflet::addPolylines(color = "purple", opacity = 1, dashArray = 5, weight = 2)
}


# update a single activity
update_activity <- function(id_to_update) {
  detailed_paddles <- readRDS("data/paddles.rds")
  detailed_paddles$detailed[detailed_paddles$id == id_to_update] <- list(rStrava::get_activity(id = id_to_update, strava_token))

  saveRDS(detailed_paddles, "data/paddles.rds")
}
