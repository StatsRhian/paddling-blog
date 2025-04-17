strava_token <-  httr::config(token = rStrava::strava_oauth("rStrava",
                                                          app_client_id = Sys.getenv("STRAVA_ID"),
                                                          app_secret = Sys.getenv("STRAVA_SECRET"),
                                                          app_scope="activity:read_all", cache = TRUE)
)

gpoly_to_sfpoly <- function(gpoly){
  coords = googlePolylines::decode(gpoly)
  sfg = lapply(coords, function(x) sf::st_linestring(x = as.matrix(x[, c(2, 1)])))
  sfc = sf::st_sfc(sfg, crs = 4326)
  return(sfc)
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

get_detail <- function(all_paddles, n = 1) {
  all_paddles |> 
    dplyr::arrange(desc(start_date)) |>
    dplyr::slice(1:n) |>
    dplyr::mutate(detailed = purrr::map(id, \ (x) rStrava::get_activity(id = x, strava_token)))
}

update_data <- function(all_paddles, n = 5) {
  new_paddles <- 
  all_paddles |>
    get_detail(n = n)

  paddles <- readr::read_rds('data/paddles.rds')
  paddles <- dplyr::bind_rows(new_paddles, paddles)
  paddles <- dplyr::distinct(paddles, id, .keep_all = TRUE)
  readr::write_rds(paddles, 'paddles.rds')
}

### Run update --------------------------------------

# Grab simple metadata for all paddles
all_paddles <- get_paddles()

# Save geojson for mapping
sf::st_write(all_paddles, "data/paddles.geojson", append = FALSE)

# Grab most recent activities and update
update_data(n = 10)