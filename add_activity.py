#!/usr/bin/env python3
"""Minimal TUI to add a new paddle activity."""

from datetime import datetime
from pathlib import Path
import re
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def slugify(text: str) -> str:
    """Convert text to URL-friendly slug."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text.strip('-')


def generate_id(date: str, title: str) -> str:
    """Generate activity ID from date and title."""
    return f"{date}_{slugify(title)}"


def get_user_input(prompt: str, allow_empty: bool = False, allow_multiline: bool = False, default: str = None) -> str:
    """Get input from user with validation."""
    while True:
        if allow_multiline:
            print(f"\n{prompt}: (Enter text, press Enter twice to finish)")
        else:
            if default:
                print(f"\n{prompt} [{default}]:")
            else:
                print(f"\n{prompt}:")

        lines = []
        empty_count = 0

        while True:
            try:
                line = input().replace('\r', '')
            except EOFError:
                break

            if not allow_multiline:
                # Single-line mode: submit immediately
                value = line.strip()
                value = ''.join(c for c in value if ord(c) >= 32 or c == '\n')
                if value:
                    return value
                if default:
                    return default
                if allow_empty:
                    return value
                print("  ⚠️  This field is required.")
                break

            # Multi-line mode: wait for two empty lines
            if line == "":
                empty_count += 1
                if empty_count >= 2:
                    break
                lines.append(line)
            else:
                empty_count = 0
                lines.append(line)

        if allow_multiline:
            value = "\n".join(lines).strip()
            # Remove any leading byte order marks or non-ASCII control characters
            value = ''.join(c for c in value if ord(c) >= 32 or c == '\n')

            if value or allow_empty:
                return value
            print("  ⚠️  This field is required.")


def validate_date(date_str: str) -> bool:
    """Validate date format YYYY-MM-DD."""
    # Extract date pattern in case there are extra characters
    match = re.search(r'\d{4}-\d{2}-\d{2}', date_str)
    if not match:
        return False
    try:
        datetime.strptime(match.group(), "%Y-%m-%d")
        return True
    except ValueError:
        return False


def main():
    data_dir = Path(__file__).parent / "data"
    activities_dir = data_dir / "paddle_activities"

    print("\n" + "=" * 50)
    print("  🛶 Add New Paddle Activity")
    print("=" * 50)

    # Get date (default to today)
    today = datetime.now().strftime("%Y-%m-%d")
    while True:
        date_input = get_user_input("Date (YYYY-MM-DD)", default=today)
        if validate_date(date_input):
            # Extract the actual date in case there are extra characters
            match = re.search(r'\d{4}-\d{2}-\d{2}', date_input)
            date = match.group()
            break
        print("  ⚠️  Invalid date format. Use YYYY-MM-DD")

    # Get title
    title = get_user_input("Title", allow_empty=False)

    # Get description
    description = get_user_input("Description", allow_empty=True, allow_multiline=True)

    # Get club (with shorthand expansion)
    club_abbrev_map = {
        "tpc": "tynemouth",
        "tcc": "tynemouth",
        "lcc": "lakeland",
        "ldcc": "lancaster",
        "ucc": "ulverston",
        "cc": "cumbria",
        "wpc": "wansbeck"
    }
    while True:
        club_input = get_user_input("Club (tpc/lcc/ldcc/ucc/cc/wpc/tynemouth/cumbria/lakeland/lancaster/ulverston/wansbeck/peer/solo)", allow_empty=True)
        if not club_input:
            club = "peer"
            break
        club_lower = club_input.lower()
        club = club_abbrev_map.get(club_lower, club_lower)
        if club in ["tynemouth", "cumbria", "lakeland", "lancaster", "ulverston", "wansbeck", "peer", "solo"]:
            break
        print("  ⚠️  Invalid club. Must be one of: tpc, lcc, ldcc, ucc, cc, wpc, tynemouth, cumbria, lakeland, lancaster, ulverston, wansbeck, peer, solo")

    # Get venue
    venue = get_user_input("Venue (default: leave blank)", allow_empty=True)
    if not venue:
        venue = ""

    # Get tags
    tags_input = get_user_input("Tags (comma-separated, optional)", allow_empty=True)
    tags = [t.strip() for t in tags_input.split(",")] if tags_input else []
    tags = [t for t in tags if t]  # Remove empty strings

    # Generate ID
    activity_id = generate_id(date, title)

    # Create folder
    activity_folder = activities_dir / activity_id
    try:
        activity_folder.mkdir(parents=True, exist_ok=True)
        print(f"\n✅ Created folder: {activity_id}")
    except Exception as e:
        print(f"\n❌ Error creating folder: {e}")
        sys.exit(1)

    # Write meta.yaml (quote all fields for consistency and safety)
    try:
        # Sanitise title: remove quotes and colons (matching R's sanitise_name function)
        title_sanitised = title.replace('"', '').replace(':', '')

        yaml_lines = [
            f'id: "{activity_id}"',
            f'date: "{date}"',
            f'title: "{title_sanitised}"',
        ]
        if club:
            yaml_lines.append(f'club: "{club}"')
        if venue:
            yaml_lines.append(f'venue: "{venue}"')
        if tags:
            yaml_lines.append("tags:")
            for tag in tags:
                yaml_lines.append(f'  - "{tag}"')
        if description:
            yaml_lines.append("description: |")
            for desc_line in description.split("\n"):
                yaml_lines.append(f"  {desc_line}")

        yaml_path = activity_folder / "meta.yaml"
        with open(yaml_path, "w", encoding="utf-8") as f:
            f.write("\n".join(yaml_lines))
        print("✅ Created meta.yaml")
    except Exception as e:
        print(f"\n❌ Error writing meta.yaml: {e}")
        sys.exit(1)

    print("\n" + "=" * 50)
    print(f"  Activity ID: {activity_id}")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    main()
