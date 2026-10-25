paddle_post <- function(selected_id, detailed_paddles) {
  template <- '---
title: "{{ name }}"
date: {{ date }}
categories: {{ categories }}
image: {{ image }}
lightbox:
  loop: true
---

- Distance: {{ distance }} km

{{description}}

{% if length(photos) > 0 %}
::: {layout-ncol=3}
{% for p in photos %}
![]({{ p }}){.lightbox group="paddle"}

{% endfor %}
:::
{% endif %}

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
      image = paddle$image,
      photos = I(unlist(paddle$photos))
    )
  filename <- paste(paddle$filename, collapse = "")
  writeLines(rendered, filename)
}
