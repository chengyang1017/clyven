#!/usr/bin/env python3
"""Generate an offline, read-only Production private-media migration plan.

Input: a CSV exported from production using ONLY the six documented fields.
No database/network access, no rclone execution, and no object deletion.
"""
import argparse
import csv
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

FIELDS = ("id", "isPublic", "videoStorageId", "coverStorageId",
          "videoStorageKey", "coverStorageKey")
SAFE_KEY = re.compile(r"^[^\x00-\x1f\x7f]+$")
PUBLIC = "glyphora-media"
PRIVATE = "glyphora-media-private"


def parse_bool(value):
    if value.strip().lower() in ("true", "t", "1"):
        return True
    if value.strip().lower() in ("false", "f", "0"):
        return False
    raise ValueError("isPublic must be true/false")


def validate_key(value):
    key = value.strip()
    if (not key or not SAFE_KEY.fullmatch(key)
            or key.startswith("/") or "\\" in key
            or any(part in ("", ".", "..") for part in key.split("/"))):
        raise ValueError("invalid or unsafe storage key")
    return key


def plan(rows):
    actions, reviews, seen = [], [], {}
    stats = Counter()
    for line, row in enumerate(rows, start=2):
        stats["rows"] += 1
        video_id = (row.get("id") or "").strip()
        try:
            if not video_id.isdecimal():
                raise ValueError("id must be a positive integer")
            visibility = parse_bool(row["isPublic"])
            if not row["videoStorageKey"].strip():
                raise ValueError("missing videoStorageKey")
        except (KeyError, ValueError, AttributeError) as exc:
            reviews.append({"line": line, "videoId": video_id, "reason": str(exc)})
            continue
        for kind, idfield, keyfield in (
            ("video", "videoStorageId", "videoStorageKey"),
            ("cover", "coverStorageId", "coverStorageKey"),
        ):
            raw = (row.get(keyfield) or "").strip()
            if not raw and kind == "cover":
                continue
            try:
                key = validate_key(raw)
            except ValueError as exc:
                reviews.append({"line": line, "videoId": video_id,
                                "kind": kind, "reason": str(exc)})
                continue
            location = (row.get(idfield) or "").strip().lower()
            if location not in ("public", "private", ""):
                reviews.append({"line": line, "videoId": video_id, "kind": kind,
                                "key": key, "reason": f"unknown storage ID: {location}"})
                continue
            if location == "":
                reviews.append({"line": line, "videoId": video_id, "kind": kind,
                                "key": key, "reason": "legacy NULL storage ID: resolve physical source"})
                continue
            if visibility and location == "private":
                reviews.append({"line": line, "videoId": video_id, "kind": kind,
                                "key": key, "reason": "public visibility but private storage: review"})
                continue
            if visibility or location == "private":
                stats["already_public_or_private"] += 1
                continue
            # Only non-public records physically located in the public R2 bucket.
            existing = seen.get(key)
            if existing is not None:
                if existing != (video_id, kind):
                    reviews.append({"line": line, "videoId": video_id, "kind": kind,
                                    "key": key, "reason": "shared source key: review before copying"})
                continue
            seen[key] = (video_id, kind)
            actions.append({"videoId": video_id, "kind": kind, "key": key,
                            "fromBucket": PUBLIC, "toBucket": PRIVATE,
                            "operation": "COPY_ONLY"})
            stats["copy_candidates"] += 1
    return {"schema": 1, "mode": "offline_plan_only",
            "warning": ("No R2 writes or reads were performed. Confirm fresh production "
                        "data, source objects, target permissions, concurrent updates and "
                        "legacy storage locations before any copy. Never enable public "
                        "bucket access or delete objects based on this file."),
            "copyCandidates": actions, "manualReview": reviews,
            "counts": dict(stats) | {"manual_review": len(reviews)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.csv_file.resolve() == args.output.resolve():
        parser.error("input and output paths must differ")
    if args.output.exists():
        parser.error("refusing to overwrite an existing plan")
    try:
        with args.csv_file.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames or any(f not in reader.fieldnames for f in FIELDS):
                raise ValueError("CSV must contain: " + ", ".join(FIELDS))
            result = plan(reader)
        # Exported data may contain private keys; restrict local file permissions.
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
    except (OSError, ValueError, csv.Error) as exc:
        parser.exit(2, f"Error: {exc}\n")
    print(f"Plan: {args.output}")
    print(f"Copy candidates: {len(result['copyCandidates'])}; "
          f"manual reviews: {len(result['manualReview'])}")
    if result["manualReview"]:
        print("Unresolved records remain. No automatic migration is authorized.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
