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

get_paddles <- function() {
  rStrava::get_activity_list(strava_token) |>
  rStrava::compile_activities() |>
  tibble::as_tibble() |>
  dplyr::filter(type %in% c("Kayaking", "Canoeing", "StandUpPaddling", "WaterSport")) |>
  dplyr::filter(!is.na(map.summary_polyline) & map.summary_polyline != "") |>
  dplyr::mutate(geom = gpoly_to_sfpoly(map.summary_polyline)) |>
  dplyr::select(id, name, start_date, distance, geom) |>
  sf::st_as_sf() |>
  sf::st_set_crs(4326)
}

gpoly_to_sfpoly <- function(gpoly){
  coords = googlePolylines::decode(gpoly)
  sfg = lapply(coords, function(x) sf::st_linestring(x = as.matrix(x[, c(2, 1)])))
  sfc = sf::st_sfc(sfg, crs = 4326)
  return(sfc)
}

strava_token <-  httr::config(token = rStrava::strava_oauth("rStrava",
                                                          app_client_id = Sys.getenv("stravaID"),
                                                          app_secret = Sys.getenv("stravaSecret"),
                                                          app_scope="activity:read_all", cache = TRUE)
)

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
  detailed_paddles$detailed[detailed_paddles$id ==  id_to_update] <- list(rStrava::get_activity(id = id_to_update, strava_token))

  saveRDS(detailed_paddles, "data/paddles.rds")
}