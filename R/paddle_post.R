paddle_post <- function(selected_id, detailed_activities) {
  template <- '---
title: "{{ name }}"
date: {{ date }}
categories: {{ categories }}
image: {{ image_url }}
---

- Distance: {{ distance }} km
- [Strava]({{ strava_url }})

{{description}}

![]({{ default(image_url, "https://dgalywyr863hv.cloudfront.net/pictures/athletes/5412155/9785737/5/large.jpg") }})


'
  activity <- detailed_activities |>
    dplyr::filter(id == selected_id)

  template |>
    jinjar::render(
      name = activity$name,
      date = activity$date,
      categories = unlist(activity$categories),
      distance = round(activity$distance, 1),
      strava_url = activity$strava_url,
      description = activity$description,
      image_url = activity$image_url
    ) |>
    writeLines(activity$filename)
}
