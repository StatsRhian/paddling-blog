# Create tibble

source("R/functions.R")

# Simple meta data
all_paddles <- get_paddles()
sf::st_write(all_paddles, "data/paddles.geojson", append = FALSE)

# Compare against RDS
detailed_paddles <- readRDS("data/paddles.rds")
missing_activities <- all_paddles$id[which(!(all_paddles$id %in% detailed_paddles$id))]
activities_to_import <- missing_activities[1:10]

new_detailed <- 
  all_paddles |>
  dplyr::filter(id %in% activities_to_import) |>
  dplyr::mutate(detailed = purrr::map(id, \ (x) rStrava::get_activity(id = x, strava_token)))

updated_detailed <- rbind(detailed_paddles, new_detailed)

saveRDS(updated_detailed, "data/paddles.rds")

#update_activity(12021786501)

# Create nice format
detailed_activities <-
readRDS("data/paddles.rds") |>
  dplyr::mutate(slug = slugify(name),
                date = stringr::str_sub(start_date, 1, 10),
                categories = purrr::map(detailed, get_categories),
                strava_url = glue::glue("https://www.strava.com/activities/{id}"),
                image_url = purrr::map_chr(detailed, \ (x) purrr::pluck(x, "photos", "primary", "urls", "600", .default = NA_character_)),
                description = purrr::map_chr(detailed, \ (x) purrr::pluck(x, "description")),
                filename = glue::glue("posts/{date}_{slug}.qmd")
  ) |>
  dplyr::filter(!is.na(image_url)) #TODO

# Generate all the post files from detailed activites
purrr::walk(detailed_activities$id, \(x) paddle_post(x, detailed_activities))
