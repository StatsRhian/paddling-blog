"""Extract GPS traces, distance, and time from FIT files."""

import fitdecode
import gzip
from pathlib import Path


def _semicircles_to_degrees(semicircles):
    """Convert FIT's semicircles to degrees."""
    return semicircles / (2 ** 31 - 1) * 180


def extract_track(fit_path):
    """
    Extract GPS trace, distance, and elapsed time from a FIT file.

    Args:
        fit_path: Path to .fit or .fit.gz file.

    Returns:
        dict with keys:
            - coords: list of [lon, lat] pairs (GeoJSON order)
            - distance_m: total distance in meters
            - duration_s: total elapsed time in seconds
    """
    path = Path(fit_path)

    if path.suffix == ".gz":
        file_handle = gzip.open(fit_path, "rb")
    else:
        file_handle = open(fit_path, "rb")

    try:
        with fitdecode.FitReader(file_handle) as fit:
            distance_m = 0
            duration_s = 0
            coords = []

            for frame in fit:
                if not isinstance(frame, fitdecode.FitDataMessage):
                    continue

                if frame.name == "session":
                    distance_m = frame.get_value("total_distance") or 0
                    duration_s = frame.get_value("total_elapsed_time") or 0

                elif frame.name == "record":
                    try:
                        lat_semi = frame.get_value("position_lat")
                        lng_semi = frame.get_value("position_long")

                        if lat_semi is not None and lng_semi is not None:
                            lat = _semicircles_to_degrees(lat_semi)
                            lng = _semicircles_to_degrees(lng_semi)
                            coords.append([lng, lat])
                    except KeyError:
                        pass

        return {
            "coords": coords,
            "distance_m": distance_m,
            "duration_s": duration_s,
        }
    finally:
        file_handle.close()
