#!/usr/bin/env python3
"""Minimal TUI to add a new paddle activity."""

import csv
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


def get_user_input(prompt: str, allow_empty: bool = False, allow_multiline: bool = False) -> str:
    """Get input from user with validation."""
    while True:
        if allow_multiline:
            print(f"\n{prompt}: (Enter text, press Enter twice to finish)")
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
                if value or allow_empty:
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
    csv_path = data_dir / "paddle_activities.csv"
    activities_dir = data_dir / "paddle_activities"

    if not csv_path.exists():
        print("❌ Error: paddle_activities.csv not found")
        sys.exit(1)

    print("\n" + "=" * 50)
    print("  🛶 Add New Paddle Activity")
    print("=" * 50)

    # Get date
    while True:
        date_input = get_user_input("Date (YYYY-MM-DD)")
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

    # Get notes
    notes = get_user_input("Private Notes", allow_empty=True)

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

    # Append to CSV
    try:
        with open(csv_path, "a", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([activity_id, date, title, description, notes])
        print("✅ Added to paddle_activities.csv")
    except Exception as e:
        print(f"\n❌ Error writing to CSV: {e}")
        sys.exit(1)

    print("\n" + "=" * 50)
    print(f"  Activity ID: {activity_id}")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    main()
