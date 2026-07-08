#!/usr/bin/env python3
"""Generate GeoJSON traces and distance data for all paddle activities."""

import csv
import json
import sys
from pathlib import Path
from trace_extraction import extract_track


DATA_DIR = Path(__file__).parent / "data"
PADDLE_ACTIVITIES_DIR = DATA_DIR / "paddle_activities"
TRACES_GEOJSON = DATA_DIR / "paddle_traces.geojson"
ACTIVITIES_CSV = DATA_DIR / "paddle_activities.csv"


def load_existing_ids(file_path):
    """Load set of already-processed activity IDs from a file."""
    if not file_path.exists():
        return set()

    if file_path.name.endswith(".csv"):
        ids = set()
        with open(file_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                ids.add(row["id"])
        return ids

    # GeoJSON
    ids = set()
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        for feature in data.get("features", []):
            activity_id = feature.get("properties", {}).get("activity_id")
            if activity_id:
                ids.add(activity_id)
    return ids


def load_geojson_features():
    """Load existing features from GeoJSON file."""
    if not TRACES_GEOJSON.exists():
        return {}

    with open(TRACES_GEOJSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    features = {}
    for feature in data.get("features", []):
        activity_id = feature.get("properties", {}).get("activity_id")
        if activity_id:
            features[activity_id] = feature
    return features


def find_fit_file(activity_folder):
    """Find .fit or .fit.gz file in activity folder."""
    folder = PADDLE_ACTIVITIES_DIR / activity_folder
    if not folder.exists():
        return None

    # Priority: .fit.gz > .fit
    for ext in [".fit.gz", ".fit"]:
        for file in folder.glob(f"*{ext}"):
            return file

    return None


def main():
    force_all = "--force" in sys.argv
    force_ids = set()
    if "--force-ids" in sys.argv:
        idx = sys.argv.index("--force-ids")
        if idx + 1 < len(sys.argv):
            force_ids = set(sys.argv[idx + 1].split(","))

    DATA_DIR.mkdir(exist_ok=True)

    if not ACTIVITIES_CSV.exists():
        print(f"Error: {ACTIVITIES_CSV} not found")
        return

    # Load existing processed IDs
    existing_ids = load_existing_ids(TRACES_GEOJSON) if not force_all else set()

    # Load existing GeoJSON features
    geojson_features = load_geojson_features() if not force_all else {}

    # Read activities CSV
    activities = []
    with open(ACTIVITIES_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        activities = list(reader)

    processed = 0
    skipped = 0
    missing_files = 0

    for activity in activities:
        activity_id = activity["ID"]

        # Check if already processed
        if activity_id in existing_ids and activity_id not in force_ids:
            skipped += 1
            continue

        # Find FIT file (folder name is identical to ID)
        fit_file = find_fit_file(activity_id)
        if not fit_file:
            missing_files += 1
            continue

        # Extract trace, distance, and time
        try:
            result = extract_track(str(fit_file))
            coords = result["coords"]
            distance_m = result["distance_m"]
            duration_s = result["duration_s"]
        except Exception as e:
            print(f"Error extracting {activity_id} from {fit_file}: {e}")
            continue

        # Add to GeoJSON
        feature = {
            "type": "Feature",
            "geometry": {
                "type": "LineString",
                "coordinates": coords,
            },
            "properties": {
                "activity_id": activity_id,
                "distance_m": distance_m,
                "duration_s": duration_s,
                "source_file": fit_file.name,
            },
        }
        geojson_features[activity_id] = feature

        processed += 1

    # Write GeoJSON
    geojson_data = {
        "type": "FeatureCollection",
        "features": list(geojson_features.values()),
    }
    with open(TRACES_GEOJSON, "w", encoding="utf-8") as f:
        json.dump(geojson_data, f, indent=2)

    # Print summary
    total = len(activities)
    print(f"\nTrace generation complete!")
    print(f"  Total activities: {total}")
    print(f"  Processed: {processed}")
    print(f"  Skipped (already done): {skipped}")
    print(f"  Missing track files: {missing_files}")
    print(f"  GeoJSON: {TRACES_GEOJSON}")


if __name__ == "__main__":
    main()
