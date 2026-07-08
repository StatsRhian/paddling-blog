# README

:warning: In progress of migration


## Workflow
1. Run `add_activity.py`
1. Put `.fit` file and photos in the generated folder
1. Push to GitHub, where a GitHub Action:
   - Regenerates `paddle_traces.geojson` via `uv run generate_paddle_traces.py`
   - Regenerates post files via `Rscript update.R`
   - Commits the updated traces and posts data back to the repo
   - Netlify auto-deploys from the commit
