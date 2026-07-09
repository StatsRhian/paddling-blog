paddle_post <- function(selected_id, detailed_paddles) {
  template <- '---
title: "{{ name }}"
date: {{ date }}
categories: {{ categories }}
image: {{ image }}
---

- Distance: {{ distance }} km

{{description}}

![]({{ image }})

'
  paddle <- detailed_paddles |>
    dplyr::filter(id == selected_id)

  rendered <- template |>
    jinjar::render(
      name = paddle$name,
      date = paddle$start_date,
      categories = unlist(paddle$categories),
      distance = round(paddle$distance, 1),
      description = paddle$description,
      image = paddle$image
    )
  filename <- paste(paddle$filename, collapse = "")
  writeLines(rendered, filename)
}
