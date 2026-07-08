# README

:warning: In progress of migration


## Workflow
1. Run `add_activity.py`
1. Put `.fit` and photos in the generated folder
1. Run `uv run generate_paddle_traces.py` to update `paddle_traces.geojson`
1. Push to GitHub (where an action runs R and builds to Netlify)
