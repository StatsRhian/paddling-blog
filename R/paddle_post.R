paddle_post <- function(selected_id, detailed_paddles) {
  template <- '---
title: "{{ name }}"
date: {{ date }}
categories: {{ categories }}
image: {{ image_url }}
---

- Distance: {{ distance }} km
- [Strava]({{ strava_url }})

{{description}}

![]({{ image_url }})

'
  paddle <- detailed_paddles |>
    dplyr::filter(id == selected_id)

  template |>
    jinjar::render(
      name = paddle$name,
      date = paddle$start_date,
      categories = unlist(paddle$categories),
      distance = round(paddle$distance, 1),
      strava_url = paddle$strava_url,
      description = paddle$description,
      image_url = paddle$image_url
    ) |>
    writeLines(paddle$filename)
}
